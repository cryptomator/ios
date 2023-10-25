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
@testable import Dependencies

class ItemEnumerationTaskTests: CloudTaskExecutorTestCase {
	override func setUpWithError() throws {
		try super.setUpWithError()
		uploadTaskManagerMock.getCorrespondingTaskRecordsIdsClosure = {
			return $0.map { _ in nil }
		}
	}

	// MARK: File

	func testFileEnumeration() throws {
		let expectation = XCTestExpectation()
		let path = CloudPath("/File 1")
		let fileMetadata = ItemMetadata(id: 2, name: "File 1", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: path, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(fileMetadata)

		let enumerationTaskRecord = ItemEnumerationTaskRecord(correspondingItem: fileMetadata.id!, pageToken: nil)
		let enumerationTask = ItemEnumerationTask(taskRecord: enumerationTaskRecord, itemMetadata: fileMetadata)

		let taskExecutor = ItemEnumerationTaskExecutor(domainIdentifier: .test, provider: cloudProviderMock, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock, uploadTaskManager: uploadTaskManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, itemEnumerationTaskManager: itemEnumerationTaskManagerMock, deleteItemHelper: deleteItemHelper)

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
			XCTAssertEqual(NSFileProviderItemIdentifier.rootContainerDatabaseValue, fetchedItemMetadata.parentID)
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
			XCTAssertEqual(1, self.itemEnumerationTaskManagerMock.removedTaskRecords.count)
			XCTAssert(self.itemEnumerationTaskManagerMock.removedTaskRecords.contains(where: { $0 == enumerationTaskRecord }))
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
		let fileMetadata = ItemMetadata(id: id, name: "File 1", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .uploadError, cloudPath: path, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(fileMetadata)

		uploadTaskManagerMock.getTaskRecordForClosure = {
			guard fileMetadata.id == $0 else {
				return nil
			}
			return UploadTaskRecord(correspondingItem: fileMetadata.id!, lastFailedUploadDate: Date(), uploadErrorCode: NSFileProviderError(.insufficientQuota).errorCode, uploadErrorDomain: NSFileProviderError.errorDomain)
		}

		let enumerationTaskRecord = ItemEnumerationTaskRecord(correspondingItem: fileMetadata.id!, pageToken: nil)
		let enumerationTask = ItemEnumerationTask(taskRecord: enumerationTaskRecord, itemMetadata: fileMetadata)

		let taskExecutor = ItemEnumerationTaskExecutor(domainIdentifier: .test, provider: cloudProviderMock, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock, uploadTaskManager: uploadTaskManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, itemEnumerationTaskManager: itemEnumerationTaskManagerMock, deleteItemHelper: deleteItemHelper)

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
			XCTAssertEqual(1, self.itemEnumerationTaskManagerMock.removedTaskRecords.count)
			XCTAssert(self.itemEnumerationTaskManagerMock.removedTaskRecords.contains(where: { $0 == enumerationTaskRecord }))
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
		let fileMetadata = ItemMetadata(id: id, name: "File 1", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: path, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(fileMetadata)

		let localURL = URL(fileURLWithPath: "/LocalFile 1")
		let lastModifiedDate = Date(timeIntervalSince1970: 0)
		try cachedFileManagerMock.cacheLocalFileInfo(for: id, localURL: localURL, lastModifiedDate: lastModifiedDate)

		let enumerationTaskRecord = ItemEnumerationTaskRecord(correspondingItem: fileMetadata.id!, pageToken: nil)
		let enumerationTask = ItemEnumerationTask(taskRecord: enumerationTaskRecord, itemMetadata: fileMetadata)

		let taskExecutor = ItemEnumerationTaskExecutor(domainIdentifier: .test, provider: cloudProviderMock, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock, uploadTaskManager: uploadTaskManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, itemEnumerationTaskManager: itemEnumerationTaskManagerMock, deleteItemHelper: deleteItemHelper)

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
			XCTAssertEqual(NSFileProviderItemIdentifier.rootContainerDatabaseValue, fetchedItemMetadata.parentID)
			XCTAssertNotNil(fetchedItemMetadata.lastModifiedDate)
			XCTAssertEqual(ItemStatus.isUploaded, fetchedItemMetadata.statusCode)
			XCTAssertEqual(CloudPath("/File 1"), fetchedItemMetadata.cloudPath)
			XCTAssertFalse(fetchedItemMetadata.isPlaceholderItem)
			XCTAssertFalse(fetchedItemMetadata.isMaybeOutdated)

			let item = itemList.items[0]
			XCTAssertEqual(fetchedItemMetadata, item.metadata)
			XCTAssert(item.newestVersionLocallyCached)
			XCTAssertEqual(localURL, item.localURL)
			XCTAssertEqual(1, self.itemEnumerationTaskManagerMock.removedTaskRecords.count)
			XCTAssert(self.itemEnumerationTaskManagerMock.removedTaskRecords.contains(where: { $0 == enumerationTaskRecord }))
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
		let itemMetadata = ItemMetadata(id: id, name: "Test", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, cloudPath: cloudPath, isPlaceholderItem: true)
		try metadataManagerMock.cacheMetadata(itemMetadata)

		let enumerationTaskRecord = ItemEnumerationTaskRecord(correspondingItem: itemMetadata.id!, pageToken: nil)
		let enumerationTask = ItemEnumerationTask(taskRecord: enumerationTaskRecord, itemMetadata: itemMetadata)

		let errorCloudProviderMock = CloudProviderErrorMock()
		errorCloudProviderMock.fetchItemMetadataResponse = { _ in
			Promise(CloudTaskTestError.correctPassthrough)
		}

		let taskExecutor = ItemEnumerationTaskExecutor(domainIdentifier: .test, provider: errorCloudProviderMock, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock, uploadTaskManager: uploadTaskManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, itemEnumerationTaskManager: itemEnumerationTaskManagerMock, deleteItemHelper: deleteItemHelper)

		taskExecutor.execute(task: enumerationTask).then { _ in
			XCTFail("Promise should not fulfill if the provider fails with an error")
		}.catch { error in
			guard case CloudTaskTestError.correctPassthrough = error else {
				XCTFail("Promise rejected but with the wrong error: \(error)")
				return
			}
			XCTAssert(self.metadataManagerMock.removedMetadataID.isEmpty, "Unexpected removal of ItemMetadata")
			XCTAssertEqual(1, self.itemEnumerationTaskManagerMock.removedTaskRecords.count)
			XCTAssert(self.itemEnumerationTaskManagerMock.removedTaskRecords.contains(where: { $0 == enumerationTaskRecord }))
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	// MARK: Folder

	// swiftlint:disable:next function_body_length
	func testFolderEnumeration() throws {
		let expectation = XCTestExpectation(description: "Folder Enumeration")

		let rootItemMetadata = ItemMetadata(id: NSFileProviderItemIdentifier.rootContainerDatabaseValue, name: "Home", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/"), isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(rootItemMetadata)

		let enumerationTaskRecord = ItemEnumerationTaskRecord(correspondingItem: rootItemMetadata.id!, pageToken: nil)
		let enumerationTask = ItemEnumerationTask(taskRecord: enumerationTaskRecord, itemMetadata: rootItemMetadata)

		let expectedItemMetadataInsideRootFolder = [ItemMetadata(id: 2, name: "Directory 1", type: .folder, size: 0, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/Directory 1/"), isPlaceholderItem: false),
		                                            ItemMetadata(id: 3, name: "File 1", type: .file, size: 14, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/File 1"), isPlaceholderItem: false),
		                                            ItemMetadata(id: 4, name: "File 2", type: .file, size: 14, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/File 2"), isPlaceholderItem: false),
		                                            ItemMetadata(id: 5, name: "File 3", type: .file, size: 14, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/File 3"), isPlaceholderItem: false),
		                                            ItemMetadata(id: 6, name: "File 4", type: .file, size: 14, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/File 4"), isPlaceholderItem: false)]

		let expectedRootFolderFileProviderItems = expectedItemMetadataInsideRootFolder.map { FileProviderItem(metadata: $0, domainIdentifier: .test) }
		let expectedItemMetadataInsideSubFolder = [ItemMetadata(id: 7, name: "Directory 2", type: .folder, size: 0, parentID: 2, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/Directory 1/Directory 2"), isPlaceholderItem: false),
		                                           ItemMetadata(id: 8, name: "File 5", type: .file, size: 14, parentID: 2, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/Directory 1/File 5"), isPlaceholderItem: false)]
		let expectedSubFolderFileProviderItems = expectedItemMetadataInsideSubFolder.map { FileProviderItem(metadata: $0, domainIdentifier: .test) }

		let taskExecutor = ItemEnumerationTaskExecutor(domainIdentifier: .test, provider: cloudProviderMock, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock, uploadTaskManager: uploadTaskManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, itemEnumerationTaskManager: itemEnumerationTaskManagerMock, deleteItemHelper: deleteItemHelper)
		let permissionProviderMock = PermissionProviderMock()
		DependencyValues.mockDependency(\.permissionProvider, with: permissionProviderMock)
		permissionProviderMock.getPermissionsForAtReturnValue = .allowsReading

		taskExecutor.execute(task: enumerationTask).then { fileProviderItemList -> FileProviderItem in
			XCTAssertEqual(5, fileProviderItemList.items.count)
			XCTAssertEqual(expectedRootFolderFileProviderItems, fileProviderItemList.items)
			XCTAssertEqual(6, self.metadataManagerMock.cachedMetadata.count)

			// Check cached metadata equals expected metadata, except the last modified date
			let expectedItemMetadata = [rootItemMetadata] + expectedItemMetadataInsideRootFolder
			XCTAssert(expectedItemMetadata.allSatisfy { expectedMetadata in
				self.metadataManagerMock.cachedMetadata.contains(where: { key, value in
					key == expectedMetadata.id && value.name == expectedMetadata.name && value.type == expectedMetadata.type && value.size == expectedMetadata.size && value.parentID == expectedMetadata.parentID && value.statusCode == expectedMetadata.statusCode && value.cloudPath == expectedMetadata.cloudPath && value.isPlaceholderItem == expectedMetadata.isPlaceholderItem
				})
			})
			XCTAssertEqual(1, self.itemEnumerationTaskManagerMock.removedTaskRecords.count)
			XCTAssert(self.itemEnumerationTaskManagerMock.removedTaskRecords.contains(where: { $0 == enumerationTaskRecord }))
			return fileProviderItemList.items[0]
		}.then { folderFileProviderItem -> Promise<FileProviderItemList> in
			let enumerationTaskRecord = ItemEnumerationTaskRecord(correspondingItem: rootItemMetadata.id!, pageToken: nil)
			let enumerationTask = ItemEnumerationTask(taskRecord: enumerationTaskRecord, itemMetadata: folderFileProviderItem.metadata)
			return taskExecutor.execute(task: enumerationTask)
		}.then { fileProviderItemList in
			XCTAssertEqual(2, self.itemEnumerationTaskManagerMock.removedTaskRecords.count)

			XCTAssertEqual(2, fileProviderItemList.items.count)
			XCTAssertEqual(expectedSubFolderFileProviderItems, fileProviderItemList.items)
			XCTAssertEqual(8, self.metadataManagerMock.cachedMetadata.count)

			// Check cached metadata equals expected metadata, except the last modified date
			XCTAssert(expectedItemMetadataInsideSubFolder.allSatisfy { expectedMetadata in
				self.metadataManagerMock.cachedMetadata.contains(where: { key, value in
					key == expectedMetadata.id && value.name == expectedMetadata.name && value.type == expectedMetadata.type && value.size == expectedMetadata.size && value.parentID == expectedMetadata.parentID && value.statusCode == expectedMetadata.statusCode && value.cloudPath == expectedMetadata.cloudPath && value.isPlaceholderItem == expectedMetadata.isPlaceholderItem
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

		let rootItemMetadata = ItemMetadata(id: NSFileProviderItemIdentifier.rootContainerDatabaseValue, name: "Home", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/"), isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(rootItemMetadata)

		let enumerationTaskRecord = ItemEnumerationTaskRecord(correspondingItem: rootItemMetadata.id!, pageToken: nil)
		let enumerationTask = ItemEnumerationTask(taskRecord: enumerationTaskRecord, itemMetadata: rootItemMetadata)

		let expectedRootFolderFileProviderItems = [FileProviderItem(metadata: ItemMetadata(id: 2, name: "Directory 1", type: .folder, size: 0, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/Directory 1/"), isPlaceholderItem: false), domainIdentifier: .test),
		                                           FileProviderItem(metadata: ItemMetadata(id: 3, name: "File 1", type: .file, size: 14, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/File 1"), isPlaceholderItem: false), domainIdentifier: .test),
		                                           FileProviderItem(metadata: ItemMetadata(id: 4, name: "File 2", type: .file, size: 14, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/File 3"), isPlaceholderItem: false), domainIdentifier: .test),
		                                           FileProviderItem(metadata: ItemMetadata(id: 5, name: "File 3", type: .file, size: 14, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/File 3"), isPlaceholderItem: false), domainIdentifier: .test),
		                                           FileProviderItem(metadata: ItemMetadata(id: 6, name: "File 4", type: .file, size: 14, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/File 4"), isPlaceholderItem: false), domainIdentifier: .test)]
		let expectedChangedRootFolderFileProviderItems = [FileProviderItem(metadata: ItemMetadata(id: 2, name: "Directory 1", type: .folder, size: 0, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/Directory 1/"), isPlaceholderItem: false), domainIdentifier: .test),
		                                                  FileProviderItem(metadata: ItemMetadata(id: 4, name: "File 2", type: .file, size: 14, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/File 3"), isPlaceholderItem: false), domainIdentifier: .test),
		                                                  FileProviderItem(metadata: ItemMetadata(id: 5, name: "File 3", type: .file, size: 14, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/File 3"), isPlaceholderItem: false), domainIdentifier: .test),
		                                                  FileProviderItem(metadata: ItemMetadata(id: 6, name: "File 4", type: .file, size: 14, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/File 4"), isPlaceholderItem: false), domainIdentifier: .test),
		                                                  FileProviderItem(metadata: ItemMetadata(id: 7, name: "NewFileFromCloud", type: .file, size: 24, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/NewFileFromCloud"), isPlaceholderItem: false), domainIdentifier: .test)]

		let permissionProviderMock = PermissionProviderMock()
		DependencyValues.mockDependency(\.permissionProvider, with: permissionProviderMock)
		permissionProviderMock.getPermissionsForAtReturnValue = .allowsReading

		let taskExecutor = ItemEnumerationTaskExecutor(domainIdentifier: .test, provider: cloudProviderMock, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock, uploadTaskManager: uploadTaskManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, itemEnumerationTaskManager: itemEnumerationTaskManagerMock, deleteItemHelper: deleteItemHelper)

		taskExecutor.execute(task: enumerationTask).then { fileProviderItemList -> Promise<FileProviderItemList> in
			XCTAssertEqual(5, fileProviderItemList.items.count)
			XCTAssertEqual(expectedRootFolderFileProviderItems, fileProviderItemList.items)
			XCTAssertEqual(1, self.itemEnumerationTaskManagerMock.removedTaskRecords.count)
			XCTAssert(self.itemEnumerationTaskManagerMock.removedTaskRecords.contains(where: { $0 == enumerationTaskRecord }))
			self.cloudProviderMock.files["/File 1"] = nil
			self.cloudProviderMock.files["/NewFileFromCloud"] = "NewFileFromCloud content".data(using: .utf8)!
			let enumerationTaskRecord = ItemEnumerationTaskRecord(correspondingItem: rootItemMetadata.id!, pageToken: nil)
			let secondEnumerationTask = ItemEnumerationTask(taskRecord: enumerationTaskRecord, itemMetadata: rootItemMetadata)
			return taskExecutor.execute(task: secondEnumerationTask)
		}.then { fileProviderItemList in
			XCTAssertEqual(2, self.itemEnumerationTaskManagerMock.removedTaskRecords.count)
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
		let rootItemMetadata = ItemMetadata(id: NSFileProviderItemIdentifier.rootContainerDatabaseValue, name: "Home", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/"), isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(rootItemMetadata)

		let enumerationTaskRecord = ItemEnumerationTaskRecord(correspondingItem: rootItemMetadata.id!, pageToken: nil)
		let enumerationTask = ItemEnumerationTask(taskRecord: enumerationTaskRecord, itemMetadata: rootItemMetadata)

		let taskExecutor = ItemEnumerationTaskExecutor(domainIdentifier: .test, provider: cloudProviderMock, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock, uploadTaskManager: uploadTaskManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, itemEnumerationTaskManager: itemEnumerationTaskManagerMock, deleteItemHelper: deleteItemHelper)

		let lastFailedUploadDate = Date()
		taskExecutor.execute(task: enumerationTask).then { _ -> Void in
			self.metadataManagerMock.cachedMetadata[id]?.statusCode = .uploadError
			let uploadTask = UploadTaskRecord(correspondingItem: id, lastFailedUploadDate: lastFailedUploadDate, uploadErrorCode: NSFileProviderError(.insufficientQuota).errorCode, uploadErrorDomain: NSFileProviderErrorDomain)
			self.uploadTaskManagerMock.getCorrespondingTaskRecordsIdsClosure = {
				return $0.map {
					if $0 == id {
						return uploadTask
					} else {
						return nil
					}
				}
			}
		}.then { _ -> Promise<FileProviderItemList> in
			let enumerationTaskRecord = ItemEnumerationTaskRecord(correspondingItem: rootItemMetadata.id!, pageToken: nil)
			let secondEnumerationTask = ItemEnumerationTask(taskRecord: enumerationTaskRecord, itemMetadata: rootItemMetadata)
			return taskExecutor.execute(task: secondEnumerationTask)
		}.then { fileProviderItemList in
			XCTAssertEqual(2, self.itemEnumerationTaskManagerMock.removedTaskRecords.count)
			XCTAssertEqual(5, fileProviderItemList.items.count)
			let errorItem = fileProviderItemList.items[1]
			guard let fetchedItemMetadata = try self.metadataManagerMock.getCachedMetadata(for: id) else {
				XCTFail("No Metadata in DB")
				return
			}
			XCTAssertEqual(ItemStatus.uploadError, fetchedItemMetadata.statusCode)
			XCTAssertFalse(self.uploadTaskManagerMock.removeTaskRecordForCalled)
			XCTAssertFalse(self.uploadTaskManagerMock.createNewTaskRecordForCalled)

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

		let rootItemMetadata = ItemMetadata(id: NSFileProviderItemIdentifier.rootContainerDatabaseValue, name: "Home", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/"), isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(rootItemMetadata)

		let enumerationTaskRecord = ItemEnumerationTaskRecord(correspondingItem: rootItemMetadata.id!, pageToken: nil)
		let enumerationTask = ItemEnumerationTask(taskRecord: enumerationTaskRecord, itemMetadata: rootItemMetadata)

		let taskExecutor = ItemEnumerationTaskExecutor(domainIdentifier: .test, provider: paginatedMockedProvider, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock, uploadTaskManager: uploadTaskManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, itemEnumerationTaskManager: itemEnumerationTaskManagerMock, deleteItemHelper: deleteItemHelper)
		let id: Int64 = 2
		let itemMetadata = ItemMetadata(id: 2, name: "TestItem", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/TestItem"), isPlaceholderItem: false)
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

		let rootItemMetadata = ItemMetadata(id: NSFileProviderItemIdentifier.rootContainerDatabaseValue, name: "Home", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/"), isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(rootItemMetadata)

		// Add some items to the ItemMetadataManager to simulate a previous folder enumeration on the root folder
		try metadataManagerMock.cacheMetadata(ItemMetadata(id: 2, name: "OutdatedFile", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/OutdatedFile"), isPlaceholderItem: false, isCandidateForCacheCleanup: false))
		try metadataManagerMock.cacheMetadata(ItemMetadata(id: 3, name: "OutdatedFolder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/OutdatedFolder"), isPlaceholderItem: false, isCandidateForCacheCleanup: false))

		let enumerationTaskRecord = ItemEnumerationTaskRecord(correspondingItem: rootItemMetadata.id!, pageToken: nil)
		let enumerationTask = ItemEnumerationTask(taskRecord: enumerationTaskRecord, itemMetadata: rootItemMetadata)

		let taskExecutor = ItemEnumerationTaskExecutor(domainIdentifier: .test, provider: paginatedMockedProvider, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock, uploadTaskManager: uploadTaskManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, itemEnumerationTaskManager: itemEnumerationTaskManagerMock, deleteItemHelper: deleteItemHelper)

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

			XCTAssertEqual(1, self.itemEnumerationTaskManagerMock.removedTaskRecords.count)
			XCTAssert(self.itemEnumerationTaskManagerMock.removedTaskRecords.contains(where: { $0 == enumerationTaskRecord }))

			let enumerationTaskRecord = ItemEnumerationTaskRecord(correspondingItem: rootItemMetadata.id!, pageToken: nextPageToken)
			let secondEnumerationTask = ItemEnumerationTask(taskRecord: enumerationTaskRecord, itemMetadata: rootItemMetadata)
			return taskExecutor.execute(task: secondEnumerationTask)
		}.then { fileProviderItemList in
			XCTAssertEqual(2, self.itemEnumerationTaskManagerMock.removedTaskRecords.count)
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

		let rootItemMetadata = ItemMetadata(id: NSFileProviderItemIdentifier.rootContainerDatabaseValue, name: "Home", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/"), isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(rootItemMetadata)

		let enumerationTaskRecord = ItemEnumerationTaskRecord(correspondingItem: rootItemMetadata.id!, pageToken: nil)
		let enumerationTask = ItemEnumerationTask(taskRecord: enumerationTaskRecord, itemMetadata: rootItemMetadata)

		let taskExecutor = ItemEnumerationTaskExecutor(domainIdentifier: .test, provider: cloudProviderMock, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock, uploadTaskManager: uploadTaskManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, itemEnumerationTaskManager: itemEnumerationTaskManagerMock, deleteItemHelper: deleteItemHelper)

		let newCloudPath = CloudPath("/RenamedItem")
		taskExecutor.execute(task: enumerationTask).then { fileProviderItemList -> Promise<FileProviderItemList> in
			XCTAssertEqual(5, fileProviderItemList.items.count)
			XCTAssertEqual(1, self.itemEnumerationTaskManagerMock.removedTaskRecords.count)
			XCTAssert(self.itemEnumerationTaskManagerMock.removedTaskRecords.contains(where: { $0 == enumerationTaskRecord }))
			// Simulate a local rename, i.e. update name, status code and create a reparent task, which renames the item with filename File 1 to RenamedItem
			let item = fileProviderItemList.items[1]
			XCTAssertEqual("File 1", item.filename)
			self.reparentTaskManagerMock.reparentTasks[item.metadata.id!] = ReparentTaskRecord(correspondingItem: item.metadata.id!, sourceCloudPath: item.metadata.cloudPath, targetCloudPath: newCloudPath, oldParentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, newParentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue)

			self.metadataManagerMock.cachedMetadata[item.metadata.id!]?.name = "RenamedItem"
			self.metadataManagerMock.cachedMetadata[item.metadata.id!]?.statusCode = .isUploading
			self.metadataManagerMock.cachedMetadata[item.metadata.id!]?.cloudPath = newCloudPath
			// Enumerate the Root folder again, File 1 has not been renamed in the cloud yet
			let enumerationTaskRecord = ItemEnumerationTaskRecord(correspondingItem: rootItemMetadata.id!, pageToken: nil)
			let secondEnumerationTask = ItemEnumerationTask(taskRecord: enumerationTaskRecord, itemMetadata: rootItemMetadata)
			return taskExecutor.execute(task: secondEnumerationTask)
		}.then { fileProviderItemList in
			XCTAssertEqual(2, self.itemEnumerationTaskManagerMock.removedTaskRecords.count)
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

		let rootItemMetadata = ItemMetadata(id: NSFileProviderItemIdentifier.rootContainerDatabaseValue, name: "Home", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/"), isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(rootItemMetadata)

		let enumerationTaskRecord = ItemEnumerationTaskRecord(correspondingItem: rootItemMetadata.id!, pageToken: nil)
		let enumerationTask = ItemEnumerationTask(taskRecord: enumerationTaskRecord, itemMetadata: rootItemMetadata)

		let taskExecutor = ItemEnumerationTaskExecutor(domainIdentifier: .test, provider: cloudProviderMock, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock, uploadTaskManager: uploadTaskManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, itemEnumerationTaskManager: itemEnumerationTaskManagerMock, deleteItemHelper: deleteItemHelper)

		taskExecutor.execute(task: enumerationTask).then { fileProviderItemList -> Promise<FileProviderItemList> in
			XCTAssertEqual(1, self.itemEnumerationTaskManagerMock.removedTaskRecords.count)
			XCTAssert(self.itemEnumerationTaskManagerMock.removedTaskRecords.contains(where: { $0 == enumerationTaskRecord }))
			XCTAssertEqual(5, fileProviderItemList.items.count)
			XCTAssertEqual(1, self.itemEnumerationTaskManagerMock.removedTaskRecords.count)
			XCTAssert(self.itemEnumerationTaskManagerMock.removedTaskRecords.contains(where: { $0 == enumerationTaskRecord }))
			// Simulate a local item deletion, i.e. update the status code and create a deletion task.
			let item = fileProviderItemList.items[1]
			XCTAssertEqual("File 1", item.filename)
			self.deletionTaskManagerMock.deletionTasks[item.metadata.id!] = DeletionTaskRecord(correspondingItem: item.metadata.id!, cloudPath: item.metadata.cloudPath, parentID: item.metadata.parentID, itemType: item.metadata.type)

			self.metadataManagerMock.cachedMetadata[item.metadata.id!]?.statusCode = .isUploading
			// Enumerate the Root folder again, File 1 has not been deleted in the cloud yet
			let enumerationTaskRecord = ItemEnumerationTaskRecord(correspondingItem: rootItemMetadata.id!, pageToken: nil)
			let secondEnumerationTask = ItemEnumerationTask(taskRecord: enumerationTaskRecord, itemMetadata: rootItemMetadata)
			return taskExecutor.execute(task: secondEnumerationTask)
		}.then { fileProviderItemList in
			XCTAssertEqual(2, self.itemEnumerationTaskManagerMock.removedTaskRecords.count)
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
		let itemMetadata = ItemMetadata(id: id, name: "Test", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, cloudPath: cloudPath, isPlaceholderItem: true)
		try metadataManagerMock.cacheMetadata(itemMetadata)

		let enumerationTaskRecord = ItemEnumerationTaskRecord(correspondingItem: itemMetadata.id!, pageToken: nil)
		let enumerationTask = ItemEnumerationTask(taskRecord: enumerationTaskRecord, itemMetadata: itemMetadata)

		let errorCloudProviderMock = CloudProviderErrorMock()
		errorCloudProviderMock.fetchItemListResponse = { _, _ in
			Promise(CloudTaskTestError.correctPassthrough)
		}

		let taskExecutor = ItemEnumerationTaskExecutor(domainIdentifier: .test, provider: errorCloudProviderMock, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock, uploadTaskManager: uploadTaskManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, itemEnumerationTaskManager: itemEnumerationTaskManagerMock, deleteItemHelper: deleteItemHelper)

		taskExecutor.execute(task: enumerationTask).then { _ in
			XCTFail("Promise should not fulfill if the provider fails with an error")
		}.catch { error in
			guard case CloudTaskTestError.correctPassthrough = error else {
				XCTFail("Promise rejected but with the wrong error: \(error)")
				return
			}
			XCTAssert(self.metadataManagerMock.removedMetadataID.isEmpty, "Unexpected removal of ItemMetadata")
			XCTAssertEqual(1, self.itemEnumerationTaskManagerMock.removedTaskRecords.count)
			XCTAssert(self.itemEnumerationTaskManagerMock.removedTaskRecords.contains(where: { $0 == enumerationTaskRecord }))
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
