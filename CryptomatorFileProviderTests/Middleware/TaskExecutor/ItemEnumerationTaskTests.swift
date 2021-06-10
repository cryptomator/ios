//
//  ItemEnumerationTaskTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 26.05.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Promises
import XCTest
@testable import CryptomatorFileProvider
class ItemEnumerationTaskTests: CloudTaskExecutorTestCase {
	// MARK: File

	func testFileEnumeration() throws {
		let expectation = XCTestExpectation()
		let path = CloudPath("/File 1")
		let fileMetadata = ItemMetadata(id: 2, name: "File 1", type: .file, size: nil, parentId: metadataManagerMock.getRootContainerID(), lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: path, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(fileMetadata)

		let enumerationTask = ItemEnumerationTask(pageToken: nil, itemMetadata: fileMetadata)

		let taskExecutor = ItemEnumerationTaskExecutor(provider: cloudProviderMock, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock, uploadTaskManager: uploadTaskManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, deleteItemHelper: deleteItemHelper)

		taskExecutor.execute(task: enumerationTask).then { itemList in
			XCTAssertEqual(1, itemList.items.count)
			XCTAssertNil(itemList.nextPageToken)
			guard let fetchedItemMetadata = try self.metadataManagerMock.getCachedMetadata(for: 2) else {
				XCTFail("No Metadata in DB")
				return
			}
			XCTAssertEqual("File 1", fetchedItemMetadata.name)
			XCTAssertEqual(CloudItemType.file, fetchedItemMetadata.type)
			XCTAssertEqual(14, fetchedItemMetadata.size)
			XCTAssertEqual(self.metadataManagerMock.getRootContainerID(), fetchedItemMetadata.parentId)
			XCTAssertNotNil(fetchedItemMetadata.lastModifiedDate)
			XCTAssertEqual(ItemStatus.isUploaded, fetchedItemMetadata.statusCode)
			XCTAssertEqual(CloudPath("/File 1"), fetchedItemMetadata.cloudPath)
			XCTAssertFalse(fetchedItemMetadata.isPlaceholderItem)
			XCTAssertFalse(fetchedItemMetadata.isMaybeOutdated)

			let item = itemList.items[0]
			XCTAssertEqual(fetchedItemMetadata, item.metadata)
			XCTAssertNil(item.error)
			XCTAssertFalse(item.newestVersionLocallyCached)
			XCTAssertNil(item.localURL)
		}.catch { error in
			XCTFail("Error in promise: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testFileEnumerationPreservesUploadError() throws {
		let expectation = XCTestExpectation()
		let path = CloudPath("/File 1")
		let id: Int64 = 2
		let fileMetadata = ItemMetadata(id: id, name: "File 1", type: .file, size: nil, parentId: metadataManagerMock.getRootContainerID(), lastModifiedDate: nil, statusCode: .uploadError, cloudPath: path, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(fileMetadata)

		uploadTaskManagerMock.uploadTasks[id] = UploadTaskRecord(correspondingItem: fileMetadata.id!, lastFailedUploadDate: Date(), uploadErrorCode: NSFileProviderError(.insufficientQuota).errorCode, uploadErrorDomain: NSFileProviderError.errorDomain)

		let enumerationTask = ItemEnumerationTask(pageToken: nil, itemMetadata: fileMetadata)

		let taskExecutor = ItemEnumerationTaskExecutor(provider: cloudProviderMock, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock, uploadTaskManager: uploadTaskManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, deleteItemHelper: deleteItemHelper)

		taskExecutor.execute(task: enumerationTask).then { itemList in
			XCTAssertEqual(1, itemList.items.count)
			XCTAssertNil(itemList.nextPageToken)
			guard let fetchedItemMetadata = try self.metadataManagerMock.getCachedMetadata(for: id) else {
				XCTFail("No Metadata in DB")
				return
			}
			XCTAssertEqual(ItemStatus.uploadError, fetchedItemMetadata.statusCode)

			guard let uploadTask = try self.uploadTaskManagerMock.getTaskRecord(for: id) else {
				XCTFail("No UploadTask found for id")
				return
			}
			XCTAssertEqual(-1003, uploadTask.uploadErrorCode)
			XCTAssertEqual(NSFileProviderErrorDomain, uploadTask.uploadErrorDomain)
			XCTAssertNotNil(uploadTask.lastFailedUploadDate)

			let item = itemList.items[0]
			XCTAssertEqual(NSFileProviderError(.insufficientQuota)._nsError, item.uploadingError as NSError?)
		}.catch { error in
			XCTFail("Error in promise: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testFileEnumerationPreservesLocalCachedFileInfo() throws {
		let expectation = XCTestExpectation()
		let path = CloudPath("/File 1")
		let id: Int64 = 2
		let fileMetadata = ItemMetadata(id: id, name: "File 1", type: .file, size: nil, parentId: metadataManagerMock.getRootContainerID(), lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: path, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(fileMetadata)

		let localURL = URL(fileURLWithPath: "/LocalFile 1")
		let lastModifiedDate = Date(timeIntervalSince1970: 0)
		try cachedFileManagerMock.cacheLocalFileInfo(for: id, localURL: localURL, lastModifiedDate: lastModifiedDate)

		let enumerationTask = ItemEnumerationTask(pageToken: nil, itemMetadata: fileMetadata)

		let taskExecutor = ItemEnumerationTaskExecutor(provider: cloudProviderMock, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock, uploadTaskManager: uploadTaskManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, deleteItemHelper: deleteItemHelper)

		taskExecutor.execute(task: enumerationTask).then { itemList in
			XCTAssertEqual(1, itemList.items.count)
			XCTAssertNil(itemList.nextPageToken)
			guard let fetchedLocalFileInfo = try self.cachedFileManagerMock.getLocalCachedFileInfo(for: id) else {
				XCTFail("No LocalCachedFileInfo in DB")
				return
			}
			XCTAssertEqual(lastModifiedDate, fetchedLocalFileInfo.lastModifiedDate)
			XCTAssertEqual(localURL, fetchedLocalFileInfo.localURL)

			guard let fetchedItemMetadata = try self.metadataManagerMock.getCachedMetadata(for: id) else {
				XCTFail("No Metadata in DB")
				return
			}
			XCTAssertEqual("File 1", fetchedItemMetadata.name)
			XCTAssertEqual(CloudItemType.file, fetchedItemMetadata.type)
			XCTAssertEqual(14, fetchedItemMetadata.size)
			XCTAssertEqual(ItemMetadataDBManager.rootContainerId, fetchedItemMetadata.parentId)
			XCTAssertNotNil(fetchedItemMetadata.lastModifiedDate)
			XCTAssertEqual(ItemStatus.isUploaded, fetchedItemMetadata.statusCode)
			XCTAssertEqual(CloudPath("/File 1"), fetchedItemMetadata.cloudPath)
			XCTAssertFalse(fetchedItemMetadata.isPlaceholderItem)
			XCTAssertFalse(fetchedItemMetadata.isMaybeOutdated)

			let item = itemList.items[0]
			XCTAssertEqual(fetchedItemMetadata, item.metadata)
			XCTAssert(item.newestVersionLocallyCached)
			XCTAssertEqual(localURL, item.localURL)
		}.catch { error in
			XCTFail("Error in promise: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testFileEnumerationFailWithSameErrorAsProvider() throws {
		let expectation = XCTestExpectation()
		let cloudPath = CloudPath("/Test")
		let id: Int64 = 2
		let itemMetadata = ItemMetadata(id: id, name: "Test", type: .file, size: nil, parentId: metadataManagerMock.getRootContainerID(), lastModifiedDate: nil, statusCode: .isUploading, cloudPath: cloudPath, isPlaceholderItem: true)
		try metadataManagerMock.cacheMetadata(itemMetadata)

		let enumerationTask = ItemEnumerationTask(pageToken: nil, itemMetadata: itemMetadata)

		let errorCloudProviderMock = CloudProviderErrorMock()
		errorCloudProviderMock.fetchItemMetadataResponse = { _ in
			Promise(CloudTaskTestError.correctPassthrough)
		}

		let taskExecutor = ItemEnumerationTaskExecutor(provider: errorCloudProviderMock, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock, uploadTaskManager: uploadTaskManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, deleteItemHelper: deleteItemHelper)

		taskExecutor.execute(task: enumerationTask).then { _ in
			XCTFail("Promise should not fulfill if the provider fails with an error")
		}.catch { error in
			guard case CloudTaskTestError.correctPassthrough = error else {
				XCTFail("Promise rejected but with the wrong error: \(error)")
				return
			}
			XCTAssert(self.metadataManagerMock.removedMetadataID.isEmpty, "Unexpected removal of ItemMetadata")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	// MARK: Folder

	func testFolderEnumeration() throws {
		let expectation = XCTestExpectation(description: "Folder Enumeration")

		let rootItemMetadata = ItemMetadata(id: metadataManagerMock.getRootContainerID(), name: "Home", type: .folder, size: nil, parentId: metadataManagerMock.getRootContainerID(), lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/"), isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(rootItemMetadata)

		let enumerationTask = ItemEnumerationTask(pageToken: nil, itemMetadata: rootItemMetadata)

		let expectedItemMetadataInsideRootFolder = [ItemMetadata(id: 2, name: "Directory 1", type: .folder, size: 0, parentId: ItemMetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/Directory 1/"), isPlaceholderItem: false),
		                                            ItemMetadata(id: 3, name: "File 1", type: .file, size: 14, parentId: ItemMetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/File 1"), isPlaceholderItem: false),
		                                            ItemMetadata(id: 4, name: "File 2", type: .file, size: 14, parentId: ItemMetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/File 2"), isPlaceholderItem: false),
		                                            ItemMetadata(id: 5, name: "File 3", type: .file, size: 14, parentId: ItemMetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/File 3"), isPlaceholderItem: false),
		                                            ItemMetadata(id: 6, name: "File 4", type: .file, size: 14, parentId: ItemMetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/File 4"), isPlaceholderItem: false)]

		let expectedRootFolderFileProviderItems = expectedItemMetadataInsideRootFolder.map { FileProviderItem(metadata: $0) }
		let expectedItemMetadataInsideSubFolder = [ItemMetadata(id: 7, name: "Directory 2", type: .folder, size: 0, parentId: 2, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/Directory 1/Directory 2"), isPlaceholderItem: false),
		                                           ItemMetadata(id: 8, name: "File 5", type: .file, size: 14, parentId: 2, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/Directory 1/File 5"), isPlaceholderItem: false)]
		let expectedSubFolderFileProviderItems = expectedItemMetadataInsideSubFolder.map { FileProviderItem(metadata: $0) }

		let taskExecutor = ItemEnumerationTaskExecutor(provider: cloudProviderMock, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock, uploadTaskManager: uploadTaskManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, deleteItemHelper: deleteItemHelper)

		taskExecutor.execute(task: enumerationTask).then { fileProviderItemList -> FileProviderItem in
			XCTAssertEqual(5, fileProviderItemList.items.count)
			XCTAssertEqual(expectedRootFolderFileProviderItems, fileProviderItemList.items)
			XCTAssertEqual(6, self.metadataManagerMock.cachedMetadata.count)

			// Check cached metadata equals expected metadata, except the last modified date
			let expectedItemMetadata = [rootItemMetadata] + expectedItemMetadataInsideRootFolder
			XCTAssert(expectedItemMetadata.allSatisfy { expectedMetadata in
				self.metadataManagerMock.cachedMetadata.contains(where: { key, value in
					key == expectedMetadata.id && value.name == expectedMetadata.name && value.type == expectedMetadata.type && value.size == expectedMetadata.size && value.parentId == expectedMetadata.parentId && value.statusCode == expectedMetadata.statusCode && value.cloudPath == expectedMetadata.cloudPath && value.isPlaceholderItem == expectedMetadata.isPlaceholderItem
				})
			})
			return fileProviderItemList.items[0]
		}.then { folderFileProviderItem -> Promise<FileProviderItemList> in
			let enumerationTask = ItemEnumerationTask(pageToken: nil, itemMetadata: folderFileProviderItem.metadata)
			return taskExecutor.execute(task: enumerationTask)
		}.then { fileProviderItemList in
			XCTAssertEqual(2, fileProviderItemList.items.count)
			XCTAssertEqual(expectedSubFolderFileProviderItems, fileProviderItemList.items)
			XCTAssertEqual(8, self.metadataManagerMock.cachedMetadata.count)

			// Check cached metadata equals expected metadata, except the last modified date
			XCTAssert(expectedItemMetadataInsideSubFolder.allSatisfy { expectedMetadata in
				self.metadataManagerMock.cachedMetadata.contains(where: { key, value in
					key == expectedMetadata.id && value.name == expectedMetadata.name && value.type == expectedMetadata.type && value.size == expectedMetadata.size && value.parentId == expectedMetadata.parentId && value.statusCode == expectedMetadata.statusCode && value.cloudPath == expectedMetadata.cloudPath && value.isPlaceholderItem == expectedMetadata.isPlaceholderItem
				})
			})
		}.catch { error in
			XCTFail("Error in promise: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testFolderEnumerationSameFolderTwice() throws {
		let expectation = XCTestExpectation(description: "Folder Enumeration")

		let rootItemMetadata = ItemMetadata(id: metadataManagerMock.getRootContainerID(), name: "Home", type: .folder, size: nil, parentId: metadataManagerMock.getRootContainerID(), lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/"), isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(rootItemMetadata)

		let enumerationTask = ItemEnumerationTask(pageToken: nil, itemMetadata: rootItemMetadata)

		let expectedRootFolderFileProviderItems = [FileProviderItem(metadata: ItemMetadata(id: 2, name: "Directory 1", type: .folder, size: 0, parentId: ItemMetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/Directory 1/"), isPlaceholderItem: false)),
		                                           FileProviderItem(metadata: ItemMetadata(id: 3, name: "File 1", type: .file, size: 14, parentId: ItemMetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/File 1"), isPlaceholderItem: false)),
		                                           FileProviderItem(metadata: ItemMetadata(id: 4, name: "File 2", type: .file, size: 14, parentId: ItemMetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/File 3"), isPlaceholderItem: false)),
		                                           FileProviderItem(metadata: ItemMetadata(id: 5, name: "File 3", type: .file, size: 14, parentId: ItemMetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/File 3"), isPlaceholderItem: false)),
		                                           FileProviderItem(metadata: ItemMetadata(id: 6, name: "File 4", type: .file, size: 14, parentId: ItemMetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/File 4"), isPlaceholderItem: false))]
		let expectedChangedRootFolderFileProviderItems = [FileProviderItem(metadata: ItemMetadata(id: 2, name: "Directory 1", type: .folder, size: 0, parentId: ItemMetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/Directory 1/"), isPlaceholderItem: false)),
		                                                  FileProviderItem(metadata: ItemMetadata(id: 4, name: "File 2", type: .file, size: 14, parentId: ItemMetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/File 3"), isPlaceholderItem: false)),
		                                                  FileProviderItem(metadata: ItemMetadata(id: 5, name: "File 3", type: .file, size: 14, parentId: ItemMetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/File 3"), isPlaceholderItem: false)),
		                                                  FileProviderItem(metadata: ItemMetadata(id: 6, name: "File 4", type: .file, size: 14, parentId: ItemMetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/File 4"), isPlaceholderItem: false)),
		                                                  FileProviderItem(metadata: ItemMetadata(id: 7, name: "NewFileFromCloud", type: .file, size: 24, parentId: ItemMetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/NewFileFromCloud"), isPlaceholderItem: false))]

		let taskExecutor = ItemEnumerationTaskExecutor(provider: cloudProviderMock, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock, uploadTaskManager: uploadTaskManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, deleteItemHelper: deleteItemHelper)

		taskExecutor.execute(task: enumerationTask).then { fileProviderItemList -> Promise<FileProviderItemList> in
			XCTAssertEqual(5, fileProviderItemList.items.count)
			XCTAssertEqual(expectedRootFolderFileProviderItems, fileProviderItemList.items)
			self.cloudProviderMock.files["/File 1"] = nil
			self.cloudProviderMock.files["/NewFileFromCloud"] = "NewFileFromCloud content".data(using: .utf8)!
			let secondEnumerationTask = ItemEnumerationTask(pageToken: nil, itemMetadata: rootItemMetadata)
			return taskExecutor.execute(task: secondEnumerationTask)
		}.then { fileProviderItemList in
			XCTAssertEqual(5, fileProviderItemList.items.count)
			XCTAssertEqual(expectedChangedRootFolderFileProviderItems, fileProviderItemList.items)
		}.catch { error in
			XCTFail("Error in promise: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testFolderEnumerationPreservesUploadError() throws {
		let expectation = XCTestExpectation()
		let id: Int64 = 3
		let rootItemMetadata = ItemMetadata(id: metadataManagerMock.getRootContainerID(), name: "Home", type: .folder, size: nil, parentId: metadataManagerMock.getRootContainerID(), lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/"), isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(rootItemMetadata)

		let enumerationTask = ItemEnumerationTask(pageToken: nil, itemMetadata: rootItemMetadata)

		let taskExecutor = ItemEnumerationTaskExecutor(provider: cloudProviderMock, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock, uploadTaskManager: uploadTaskManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, deleteItemHelper: deleteItemHelper)

		let lastFailedUploadDate = Date()
		taskExecutor.execute(task: enumerationTask).then { _ -> Void in
			self.metadataManagerMock.cachedMetadata[id]?.statusCode = .uploadError
			let uploadTask = UploadTaskRecord(correspondingItem: id, lastFailedUploadDate: lastFailedUploadDate, uploadErrorCode: NSFileProviderError(.insufficientQuota).errorCode, uploadErrorDomain: NSFileProviderErrorDomain)
			self.uploadTaskManagerMock.uploadTasks[id] = uploadTask
		}.then { _ -> Promise<FileProviderItemList> in
			let secondEnumerationTask = ItemEnumerationTask(pageToken: nil, itemMetadata: rootItemMetadata)
			return taskExecutor.execute(task: secondEnumerationTask)
		}.then { fileProviderItemList in
			XCTAssertEqual(5, fileProviderItemList.items.count)
			let errorItem = fileProviderItemList.items[1]
			guard let fetchedItemMetadata = try self.metadataManagerMock.getCachedMetadata(for: id) else {
				XCTFail("No Metadata in DB")
				return
			}
			XCTAssertEqual(ItemStatus.uploadError, fetchedItemMetadata.statusCode)
			guard let uploadTask = try self.uploadTaskManagerMock.getTaskRecord(for: id) else {
				XCTFail("No UploadTask found for id")
				return
			}
			XCTAssertEqual(NSFileProviderError(.insufficientQuota).errorCode, uploadTask.uploadErrorCode)
			XCTAssertEqual(NSFileProviderErrorDomain, uploadTask.uploadErrorDomain)
			XCTAssertEqual(lastFailedUploadDate, uploadTask.lastFailedUploadDate)

			XCTAssertNotNil(errorItem.uploadingError)
			XCTAssertEqual(NSFileProviderError(.insufficientQuota)._nsError, errorItem.uploadingError as NSError?)
		}.catch { error in
			XCTFail("Error in promise: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testPartialFolderEnumerationMarksMetadataAsMaybeOutdated() throws {
		let expectation = XCTestExpectation()
		let paginatedMockedProvider = CloudProviderPaginationMock()

		let rootItemMetadata = ItemMetadata(id: metadataManagerMock.getRootContainerID(), name: "Home", type: .folder, size: nil, parentId: metadataManagerMock.getRootContainerID(), lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/"), isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(rootItemMetadata)

		let enumerationTask = ItemEnumerationTask(pageToken: nil, itemMetadata: rootItemMetadata)

		let taskExecutor = ItemEnumerationTaskExecutor(provider: paginatedMockedProvider, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock, uploadTaskManager: uploadTaskManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, deleteItemHelper: deleteItemHelper)
		let id: Int64 = 2
		let itemMetadata = ItemMetadata(id: 2, name: "TestItem", type: .file, size: nil, parentId: ItemMetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/TestItem"), isPlaceholderItem: false)
		metadataManagerMock.cachedMetadata[itemMetadata.id!] = itemMetadata

		taskExecutor.execute(task: enumerationTask).then { fileProviderItemList in
			XCTAssertNotNil(fileProviderItemList.nextPageToken)
			XCTAssertEqual(2, fileProviderItemList.items.count)
			XCTAssertEqual(0, fileProviderItemList.items.filter { $0.metadata.id == itemMetadata.id }.count)
			guard let markedAsMaybeOutdatedCachedMetadata = try self.metadataManagerMock.getCachedMetadata(for: id) else {
				XCTFail("No ItemMetadata for id found")
				return
			}
			XCTAssert(markedAsMaybeOutdatedCachedMetadata.isMaybeOutdated)
		}.catch { error in
			XCTFail("Error in promise: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testFullFolderEnumerationRemovesInvalidatedCachedMetadata() throws {
		let expectation = XCTestExpectation()
		let paginatedMockedProvider = CloudProviderPaginationMock()

		let rootItemMetadata = ItemMetadata(id: metadataManagerMock.getRootContainerID(), name: "Home", type: .folder, size: nil, parentId: metadataManagerMock.getRootContainerID(), lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/"), isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(rootItemMetadata)

		// Add some items to the ItemMetadataManager to simulate a previous folder enumeration on the root folder
		try metadataManagerMock.cacheMetadata(ItemMetadata(id: 2, name: "OutdatedFile", type: .file, size: nil, parentId: metadataManagerMock.getRootContainerID(), lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/OutdatedFile"), isPlaceholderItem: false, isCandidateForCacheCleanup: false))
		try metadataManagerMock.cacheMetadata(ItemMetadata(id: 3, name: "OutdatedFolder", type: .folder, size: nil, parentId: metadataManagerMock.getRootContainerID(), lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/OutdatedFolder"), isPlaceholderItem: false, isCandidateForCacheCleanup: false))

		let enumerationTask = ItemEnumerationTask(pageToken: nil, itemMetadata: rootItemMetadata)

		let taskExecutor = ItemEnumerationTaskExecutor(provider: paginatedMockedProvider, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock, uploadTaskManager: uploadTaskManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, deleteItemHelper: deleteItemHelper)

		taskExecutor.execute(task: enumerationTask).then { fileProviderItemList -> Promise<FileProviderItemList> in
			XCTAssertEqual(2, fileProviderItemList.items.count)
			// Check that a next page exists
			XCTAssertNotNil(fileProviderItemList.nextPageToken)
			guard let tokenData = fileProviderItemList.nextPageToken, let nextPageToken = String(data: tokenData.rawValue, encoding: .utf8) else {
				throw NSError(domain: "ItemEnumerationTaskExecutorTestError", code: -100, userInfo: ["localizedDescription": "No page token"])
			}
			// Check that the (possible) old items have been marked as maybe outdated
			XCTAssert(self.metadataManagerMock.cachedMetadata[2]?.isMaybeOutdated ?? false)
			XCTAssert(self.metadataManagerMock.cachedMetadata[3]?.isMaybeOutdated ?? false)
			let secondEnumerationTask = ItemEnumerationTask(pageToken: nextPageToken, itemMetadata: rootItemMetadata)
			return taskExecutor.execute(task: secondEnumerationTask)
		}.then { fileProviderItemList in
			XCTAssertEqual(4, fileProviderItemList.items.count)

			// Check that the whole folder has been enumerated
			XCTAssertNil(fileProviderItemList.nextPageToken)

			// Check that the old items has been removed
			XCTAssertEqual(2, self.metadataManagerMock.removedMetadataID.count)
			XCTAssert(self.metadataManagerMock.removedMetadataID.contains { $0 == 2 })
			XCTAssert(self.metadataManagerMock.removedMetadataID.contains { $0 == 3 })

		}.catch { error in
			XCTFail("Error in promise: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testFolderEnumerationDidNotOverwriteReparentTask() throws {
		let expectation = XCTestExpectation()

		let rootItemMetadata = ItemMetadata(id: metadataManagerMock.getRootContainerID(), name: "Home", type: .folder, size: nil, parentId: metadataManagerMock.getRootContainerID(), lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/"), isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(rootItemMetadata)

		let enumerationTask = ItemEnumerationTask(pageToken: nil, itemMetadata: rootItemMetadata)

		let taskExecutor = ItemEnumerationTaskExecutor(provider: cloudProviderMock, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock, uploadTaskManager: uploadTaskManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, deleteItemHelper: deleteItemHelper)

		let newCloudPath = CloudPath("/RenamedItem")
		taskExecutor.execute(task: enumerationTask).then { fileProviderItemList -> Promise<FileProviderItemList> in
			XCTAssertEqual(5, fileProviderItemList.items.count)
			// Simulate a local rename, i.e. update name, status code and create a reparent task, which renames the item with filename File 1 to RenamedItem
			let item = fileProviderItemList.items[1]
			XCTAssertEqual("File 1", item.filename)
			self.reparentTaskManagerMock.reparentTasks[item.metadata.id!] = ReparentTaskRecord(correspondingItem: item.metadata.id!, sourceCloudPath: item.metadata.cloudPath, targetCloudPath: newCloudPath, oldParentID: self.metadataManagerMock.getRootContainerID(), newParentID: self.metadataManagerMock.getRootContainerID())

			self.metadataManagerMock.cachedMetadata[item.metadata.id!]?.name = "RenamedItem"
			self.metadataManagerMock.cachedMetadata[item.metadata.id!]?.statusCode = .isUploading
			self.metadataManagerMock.cachedMetadata[item.metadata.id!]?.cloudPath = newCloudPath
			// Enumerate the Root folder again, File 1 has not been renamed in the cloud yet
			let secondEnumerationTask = ItemEnumerationTask(pageToken: nil, itemMetadata: rootItemMetadata)
			return taskExecutor.execute(task: secondEnumerationTask)
		}.then { fileProviderItemList in
			XCTAssertEqual(5, fileProviderItemList.items.count)
			// Check that the item has the new name (RenamedItem) and there is no duplicate item with the old name (File 1)
			let renamedItem = fileProviderItemList.items.first(where: { $0.filename == "RenamedItem" })
			let oldItem = fileProviderItemList.items.first(where: { $0.filename == "File 1" })
			XCTAssertNil(oldItem)
			XCTAssertNotNil(renamedItem)
			XCTAssertEqual(ItemStatus.isUploading, renamedItem?.metadata.statusCode)
			XCTAssertEqual(newCloudPath, renamedItem?.metadata.cloudPath)
		}.catch { error in
			XCTFail("Error in promise: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testFolderEnumerationDidNotOverwriteDeletionTask() throws {
		let expectation = XCTestExpectation()

		let rootItemMetadata = ItemMetadata(id: metadataManagerMock.getRootContainerID(), name: "Home", type: .folder, size: nil, parentId: metadataManagerMock.getRootContainerID(), lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/"), isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(rootItemMetadata)

		let enumerationTask = ItemEnumerationTask(pageToken: nil, itemMetadata: rootItemMetadata)

		let taskExecutor = ItemEnumerationTaskExecutor(provider: cloudProviderMock, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock, uploadTaskManager: uploadTaskManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, deleteItemHelper: deleteItemHelper)

		taskExecutor.execute(task: enumerationTask).then { fileProviderItemList -> Promise<FileProviderItemList> in
			XCTAssertEqual(5, fileProviderItemList.items.count)
			// Simulate a local item deletion, i.e. update the status code and create a deletion task.
			let item = fileProviderItemList.items[1]
			XCTAssertEqual("File 1", item.filename)
			self.deletionTaskManagerMock.deletionTasks[item.metadata.id!] = DeletionTaskRecord(correspondingItem: item.metadata.id!, cloudPath: item.metadata.cloudPath, parentId: item.metadata.parentId, itemType: item.metadata.type)

			self.metadataManagerMock.cachedMetadata[item.metadata.id!]?.statusCode = .isUploading
			// Enumerate the Root folder again, File 1 has not been deleted in the cloud yet
			let secondEnumerationTask = ItemEnumerationTask(pageToken: nil, itemMetadata: rootItemMetadata)
			return taskExecutor.execute(task: secondEnumerationTask)
		}.then { fileProviderItemList in
			// Check that the item is no longer returned in the FileProviderItemList.
			XCTAssertEqual(4, fileProviderItemList.items.count)
			XCTAssertFalse(fileProviderItemList.items.contains(where: { $0.filename == "File 1" }))
		}.catch { error in
			XCTFail("Error in promise: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testFolderEnumerationFailWithSameErrorAsProvider() throws {
		let expectation = XCTestExpectation()
		let cloudPath = CloudPath("/Test")
		let id: Int64 = 2
		let itemMetadata = ItemMetadata(id: id, name: "Test", type: .folder, size: nil, parentId: metadataManagerMock.getRootContainerID(), lastModifiedDate: nil, statusCode: .isUploading, cloudPath: cloudPath, isPlaceholderItem: true)
		try metadataManagerMock.cacheMetadata(itemMetadata)

		let enumerationTask = ItemEnumerationTask(pageToken: nil, itemMetadata: itemMetadata)

		let errorCloudProviderMock = CloudProviderErrorMock()
		errorCloudProviderMock.fetchItemListResponse = { _, _ in
			Promise(CloudTaskTestError.correctPassthrough)
		}

		let taskExecutor = ItemEnumerationTaskExecutor(provider: errorCloudProviderMock, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock, uploadTaskManager: uploadTaskManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, deleteItemHelper: deleteItemHelper)

		taskExecutor.execute(task: enumerationTask).then { _ in
			XCTFail("Promise should not fulfill if the provider fails with an error")
		}.catch { error in
			guard case CloudTaskTestError.correctPassthrough = error else {
				XCTFail("Promise rejected but with the wrong error: \(error)")
				return
			}
			XCTAssert(self.metadataManagerMock.removedMetadataID.isEmpty, "Unexpected removal of ItemMetadata")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}
}

extension FileProviderItem {
	override open func isEqual(_ object: Any?) -> Bool {
		let other = object as? FileProviderItem
		return filename == other?.filename && itemIdentifier == other?.itemIdentifier && parentItemIdentifier == other?.parentItemIdentifier && typeIdentifier == other?.typeIdentifier && capabilities == other?.capabilities && documentSize == other?.documentSize
	}
}
