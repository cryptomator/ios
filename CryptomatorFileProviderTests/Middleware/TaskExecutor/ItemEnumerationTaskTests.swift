//
//  ItemEnumerationTaskTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 26.05.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Dependencies
import XCTest
@testable import CryptomatorFileProvider

class ItemEnumerationTaskTests: CloudTaskExecutorTestCase {
	override func setUp() async throws {
		try await super.setUp()
		uploadTaskManagerMock.getCorrespondingTaskRecordsIdsClosure = {
			return $0.map { _ in nil }
		}
	}

	// MARK: File

	func testFileEnumeration() async throws {
		let path = CloudPath("/File 1")
		let fileMetadata = ItemMetadata(id: 2, name: "File 1", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(fileMetadata)

		let enumerationTaskRecord = try ItemEnumerationTaskRecord(correspondingItem: XCTUnwrap(fileMetadata.id), pageToken: nil)
		let enumerationTask = ItemEnumerationTask(taskRecord: enumerationTaskRecord, itemMetadata: fileMetadata, cloudPath: CloudPath("/").appendingPathComponent(fileMetadata.name))

		let taskExecutor = ItemEnumerationTaskExecutor(domainIdentifier: .test, provider: cloudProviderMock, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock, uploadTaskManager: uploadTaskManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, itemEnumerationTaskManager: itemEnumerationTaskManagerMock, deleteItemHelper: deleteItemHelper)

		let itemList = try await taskExecutor.execute(task: enumerationTask)
		XCTAssertEqual(1, itemList.items.count)
		XCTAssertNil(itemList.nextPageToken)
		guard let fetchedItemMetadata = try metadataManagerMock.getCachedMetadata(for: 2) else {
			XCTFail("No Metadata in DB")
			return
		}
		XCTAssertEqual("File 1", fetchedItemMetadata.name)
		XCTAssertEqual(CloudItemType.file, fetchedItemMetadata.type)
		XCTAssertEqual(14, fetchedItemMetadata.size)
		XCTAssertEqual(NSFileProviderItemIdentifier.rootContainerDatabaseValue, fetchedItemMetadata.parentID)
		XCTAssertNotNil(fetchedItemMetadata.lastModifiedDate)
		XCTAssertEqual(ItemStatus.isUploaded, fetchedItemMetadata.statusCode)
		XCTAssertEqual("File 1", fetchedItemMetadata.name)
		XCTAssertFalse(fetchedItemMetadata.isPlaceholderItem)
		XCTAssertFalse(fetchedItemMetadata.isMaybeOutdated)

		let item = itemList.items[0]
		XCTAssertEqual(fetchedItemMetadata, item.metadata)
		XCTAssertNil(item.error)
		XCTAssertFalse(item.newestVersionLocallyCached)
		XCTAssertNil(item.localURL)
		XCTAssertEqual(1, itemEnumerationTaskManagerMock.removedTaskRecords.count)
		XCTAssert(itemEnumerationTaskManagerMock.removedTaskRecords.contains(where: { $0 == enumerationTaskRecord }))
	}

	func testFileEnumerationPreservesUploadError() async throws {
		let path = CloudPath("/File 1")
		let id: Int64 = 2
		let fileMetadata = ItemMetadata(id: id, name: "File 1", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .uploadError, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(fileMetadata)

		uploadTaskManagerMock.getTaskRecordForClosure = {
			guard fileMetadata.id == $0 else {
				return nil
			}
			return UploadTaskRecord(correspondingItem: fileMetadata.id!, lastFailedUploadDate: Date(), uploadErrorCode: NSFileProviderError(.insufficientQuota).errorCode, uploadErrorDomain: NSFileProviderError.errorDomain, uploadStartedAt: nil)
		}

		let enumerationTaskRecord = try ItemEnumerationTaskRecord(correspondingItem: XCTUnwrap(fileMetadata.id), pageToken: nil)
		let enumerationTask = ItemEnumerationTask(taskRecord: enumerationTaskRecord, itemMetadata: fileMetadata, cloudPath: CloudPath("/").appendingPathComponent(fileMetadata.name))

		let taskExecutor = ItemEnumerationTaskExecutor(domainIdentifier: .test, provider: cloudProviderMock, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock, uploadTaskManager: uploadTaskManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, itemEnumerationTaskManager: itemEnumerationTaskManagerMock, deleteItemHelper: deleteItemHelper)

		let itemList = try await taskExecutor.execute(task: enumerationTask)
		XCTAssertEqual(1, itemList.items.count)
		XCTAssertNil(itemList.nextPageToken)
		guard let fetchedItemMetadata = try metadataManagerMock.getCachedMetadata(for: id) else {
			XCTFail("No Metadata in DB")
			return
		}
		XCTAssertEqual(ItemStatus.uploadError, fetchedItemMetadata.statusCode)

		guard let uploadTask = try uploadTaskManagerMock.getTaskRecord(for: id) else {
			XCTFail("No UploadTask found for id")
			return
		}
		XCTAssertEqual(-1003, uploadTask.uploadErrorCode)
		XCTAssertEqual(NSFileProviderErrorDomain, uploadTask.uploadErrorDomain)
		XCTAssertNotNil(uploadTask.lastFailedUploadDate)

		let item = itemList.items[0]
		XCTAssertEqual(NSFileProviderError(.insufficientQuota)._nsError, item.uploadingError as NSError?)
		XCTAssertEqual(1, itemEnumerationTaskManagerMock.removedTaskRecords.count)
		XCTAssert(itemEnumerationTaskManagerMock.removedTaskRecords.contains(where: { $0 == enumerationTaskRecord }))
	}

	func testFileEnumerationPreservesLocalCachedFileInfo() async throws {
		let path = CloudPath("/File 1")
		let id: Int64 = 2
		let fileMetadata = ItemMetadata(id: id, name: "File 1", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(fileMetadata)

		let localURL = URL(fileURLWithPath: "/LocalFile 1")
		let lastModifiedDate = Date(timeIntervalSince1970: 0)
		try cachedFileManagerMock.cacheLocalFileInfo(for: id, localURL: localURL, lastModifiedDate: lastModifiedDate)

		let enumerationTaskRecord = try ItemEnumerationTaskRecord(correspondingItem: XCTUnwrap(fileMetadata.id), pageToken: nil)
		let enumerationTask = ItemEnumerationTask(taskRecord: enumerationTaskRecord, itemMetadata: fileMetadata, cloudPath: CloudPath("/").appendingPathComponent(fileMetadata.name))

		let taskExecutor = ItemEnumerationTaskExecutor(domainIdentifier: .test, provider: cloudProviderMock, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock, uploadTaskManager: uploadTaskManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, itemEnumerationTaskManager: itemEnumerationTaskManagerMock, deleteItemHelper: deleteItemHelper)

		let itemList = try await taskExecutor.execute(task: enumerationTask)
		XCTAssertEqual(1, itemList.items.count)
		XCTAssertNil(itemList.nextPageToken)
		guard let fetchedLocalFileInfo = try cachedFileManagerMock.getLocalCachedFileInfo(for: id) else {
			XCTFail("No LocalCachedFileInfo in DB")
			return
		}
		XCTAssertEqual(lastModifiedDate, fetchedLocalFileInfo.lastModifiedDate)
		XCTAssertEqual(localURL, fetchedLocalFileInfo.localURL)

		guard let fetchedItemMetadata = try metadataManagerMock.getCachedMetadata(for: id) else {
			XCTFail("No Metadata in DB")
			return
		}
		XCTAssertEqual("File 1", fetchedItemMetadata.name)
		XCTAssertEqual(CloudItemType.file, fetchedItemMetadata.type)
		XCTAssertEqual(14, fetchedItemMetadata.size)
		XCTAssertEqual(NSFileProviderItemIdentifier.rootContainerDatabaseValue, fetchedItemMetadata.parentID)
		XCTAssertNotNil(fetchedItemMetadata.lastModifiedDate)
		XCTAssertEqual(ItemStatus.isUploaded, fetchedItemMetadata.statusCode)
		XCTAssertEqual("File 1", fetchedItemMetadata.name)
		XCTAssertFalse(fetchedItemMetadata.isPlaceholderItem)
		XCTAssertFalse(fetchedItemMetadata.isMaybeOutdated)

		let item = itemList.items[0]
		XCTAssertEqual(fetchedItemMetadata, item.metadata)
		XCTAssert(item.newestVersionLocallyCached)
		XCTAssertEqual(localURL, item.localURL)
		XCTAssertEqual(1, itemEnumerationTaskManagerMock.removedTaskRecords.count)
		XCTAssert(itemEnumerationTaskManagerMock.removedTaskRecords.contains(where: { $0 == enumerationTaskRecord }))
	}

	func testFileEnumerationFailWithSameErrorAsProvider() async throws {
		let cloudPath = CloudPath("/Test")
		let id: Int64 = 2
		let itemMetadata = ItemMetadata(id: id, name: "Test", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(itemMetadata)

		let enumerationTaskRecord = try ItemEnumerationTaskRecord(correspondingItem: XCTUnwrap(itemMetadata.id), pageToken: nil)
		let enumerationTask = ItemEnumerationTask(taskRecord: enumerationTaskRecord, itemMetadata: itemMetadata, cloudPath: CloudPath("/").appendingPathComponent(itemMetadata.name))

		let errorCloudProviderMock = CloudProviderErrorMock()
		errorCloudProviderMock.fetchItemMetadataResponse = { _ in
			throw CloudTaskTestError.correctPassthrough
		}

		let taskExecutor = ItemEnumerationTaskExecutor(domainIdentifier: .test, provider: errorCloudProviderMock, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock, uploadTaskManager: uploadTaskManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, itemEnumerationTaskManager: itemEnumerationTaskManagerMock, deleteItemHelper: deleteItemHelper)

		await XCTAssertThrowsAsyncError(try await taskExecutor.execute(task: enumerationTask)) { error in
			guard case CloudTaskTestError.correctPassthrough = error else {
				XCTFail("Rejected with the wrong error: \(error)")
				return
			}
			XCTAssert(metadataManagerMock.removedMetadataID.isEmpty, "Unexpected removal of ItemMetadata")
			XCTAssertEqual(1, itemEnumerationTaskManagerMock.removedTaskRecords.count)
			XCTAssert(itemEnumerationTaskManagerMock.removedTaskRecords.contains(where: { $0 == enumerationTaskRecord }))
		}
	}

	// MARK: Folder

	func testFolderEnumeration() async throws {
		let rootItemMetadata = ItemMetadata(id: NSFileProviderItemIdentifier.rootContainerDatabaseValue, name: "Home", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(rootItemMetadata)

		let enumerationTaskRecord = try ItemEnumerationTaskRecord(correspondingItem: XCTUnwrap(rootItemMetadata.id), pageToken: nil)
		let enumerationTask = ItemEnumerationTask(taskRecord: enumerationTaskRecord, itemMetadata: rootItemMetadata, cloudPath: CloudPath("/"))

		let expectedItemMetadataInsideRootFolder = [ItemMetadata(id: 2, name: "Directory 1", type: .folder, size: 0, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false),
		                                            ItemMetadata(id: 3, name: "File 1", type: .file, size: 14, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false),
		                                            ItemMetadata(id: 4, name: "File 2", type: .file, size: 14, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false),
		                                            ItemMetadata(id: 5, name: "File 3", type: .file, size: 14, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false),
		                                            ItemMetadata(id: 6, name: "File 4", type: .file, size: 14, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)]

		let expectedItemMetadataInsideSubFolder = [ItemMetadata(id: 7, name: "Directory 2", type: .folder, size: 0, parentID: 2, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false),
		                                           ItemMetadata(id: 8, name: "File 5", type: .file, size: 14, parentID: 2, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)]

		let taskExecutor = ItemEnumerationTaskExecutor(domainIdentifier: .test, provider: cloudProviderMock, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock, uploadTaskManager: uploadTaskManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, itemEnumerationTaskManager: itemEnumerationTaskManagerMock, deleteItemHelper: deleteItemHelper)
		let permissionProviderMock = PermissionProviderMock()
		try await withDependencies({
			$0.permissionProvider = permissionProviderMock
		}, operation: {
			permissionProviderMock.getPermissionsForAtReturnValue = .allowsReading
			let expectedRootFolderFileProviderItems = expectedItemMetadataInsideRootFolder.map { FileProviderItem(metadata: $0, domainIdentifier: .test) }
			let expectedSubFolderFileProviderItems = expectedItemMetadataInsideSubFolder.map { FileProviderItem(metadata: $0, domainIdentifier: .test) }

			let rootFolderItemList = try await taskExecutor.execute(task: enumerationTask)
			XCTAssertEqual(5, rootFolderItemList.items.count)
			XCTAssertEqual(expectedRootFolderFileProviderItems, rootFolderItemList.items)
			XCTAssertEqual(expectedRootFolderFileProviderItems.map(\.metadata.name), rootFolderItemList.items.map(\.metadata.name))
			XCTAssertEqual(6, self.metadataManagerMock.cachedMetadata.count)

			// Check cached metadata equals expected metadata, except the last modified date
			let expectedItemMetadata = [rootItemMetadata] + expectedItemMetadataInsideRootFolder
			XCTAssert(expectedItemMetadata.allSatisfy { expectedMetadata in
				self.metadataManagerMock.cachedMetadata.contains(where: { key, value in
					key == expectedMetadata.id && value.name == expectedMetadata.name && value.type == expectedMetadata.type && value.size == expectedMetadata.size && value.parentID == expectedMetadata.parentID && value.statusCode == expectedMetadata.statusCode && value.parentID == expectedMetadata.parentID && value.isPlaceholderItem == expectedMetadata.isPlaceholderItem
				})
			})
			XCTAssertEqual(1, self.itemEnumerationTaskManagerMock.removedTaskRecords.count)
			XCTAssert(self.itemEnumerationTaskManagerMock.removedTaskRecords.contains(where: { $0 == enumerationTaskRecord }))

			let subfolderMetadata = rootFolderItemList.items[0].metadata
			let subfolderEnumerationTaskRecord = try ItemEnumerationTaskRecord(correspondingItem: XCTUnwrap(subfolderMetadata.id), pageToken: nil)
			let subfolderEnumerationTask = ItemEnumerationTask(taskRecord: subfolderEnumerationTaskRecord, itemMetadata: subfolderMetadata, cloudPath: CloudPath("/").appendingPathComponent(subfolderMetadata.name))
			let subfolderItemList = try await taskExecutor.execute(task: subfolderEnumerationTask)

			XCTAssertEqual(2, self.itemEnumerationTaskManagerMock.removedTaskRecords.count)
			XCTAssert(self.itemEnumerationTaskManagerMock.removedTaskRecords.contains(where: { $0 == subfolderEnumerationTaskRecord }))
			XCTAssertEqual(2, subfolderItemList.items.count)
			XCTAssertEqual(expectedSubFolderFileProviderItems, subfolderItemList.items)
			XCTAssertEqual(expectedSubFolderFileProviderItems.map(\.metadata.name), subfolderItemList.items.map(\.metadata.name))
			XCTAssertEqual(8, self.metadataManagerMock.cachedMetadata.count)

			// Check cached metadata equals expected metadata, except the last modified date
			XCTAssert(expectedItemMetadataInsideSubFolder.allSatisfy { expectedMetadata in
				self.metadataManagerMock.cachedMetadata.contains(where: { key, value in
					key == expectedMetadata.id && value.name == expectedMetadata.name && value.type == expectedMetadata.type && value.size == expectedMetadata.size && value.parentID == expectedMetadata.parentID && value.statusCode == expectedMetadata.statusCode && value.parentID == expectedMetadata.parentID && value.isPlaceholderItem == expectedMetadata.isPlaceholderItem
				})
			})
		})
	}

	func testFolderEnumerationSameFolderTwice() async throws {
		let rootItemMetadata = ItemMetadata(id: NSFileProviderItemIdentifier.rootContainerDatabaseValue, name: "Home", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(rootItemMetadata)

		let enumerationTaskRecord = try ItemEnumerationTaskRecord(correspondingItem: XCTUnwrap(rootItemMetadata.id), pageToken: nil)
		let enumerationTask = ItemEnumerationTask(taskRecord: enumerationTaskRecord, itemMetadata: rootItemMetadata, cloudPath: CloudPath("/"))

		let permissionProviderMock = PermissionProviderMock()
		let taskExecutor = ItemEnumerationTaskExecutor(domainIdentifier: .test, provider: cloudProviderMock, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock, uploadTaskManager: uploadTaskManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, itemEnumerationTaskManager: itemEnumerationTaskManagerMock, deleteItemHelper: deleteItemHelper)

		try await withDependencies({
			$0.permissionProvider = permissionProviderMock
		}, operation: {
			permissionProviderMock.getPermissionsForAtReturnValue = .allowsReading
			let expectedRootFolderFileProviderItems = [FileProviderItem(metadata: ItemMetadata(id: 2, name: "Directory 1", type: .folder, size: 0, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false), domainIdentifier: .test),
			                                           FileProviderItem(metadata: ItemMetadata(id: 3, name: "File 1", type: .file, size: 14, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false), domainIdentifier: .test),
			                                           FileProviderItem(metadata: ItemMetadata(id: 4, name: "File 2", type: .file, size: 14, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false), domainIdentifier: .test),
			                                           FileProviderItem(metadata: ItemMetadata(id: 5, name: "File 3", type: .file, size: 14, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false), domainIdentifier: .test),
			                                           FileProviderItem(metadata: ItemMetadata(id: 6, name: "File 4", type: .file, size: 14, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false), domainIdentifier: .test)]
			let expectedChangedRootFolderFileProviderItems = [FileProviderItem(metadata: ItemMetadata(id: 2, name: "Directory 1", type: .folder, size: 0, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false), domainIdentifier: .test),
			                                                  FileProviderItem(metadata: ItemMetadata(id: 4, name: "File 2", type: .file, size: 14, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false), domainIdentifier: .test),
			                                                  FileProviderItem(metadata: ItemMetadata(id: 5, name: "File 3", type: .file, size: 14, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false), domainIdentifier: .test),
			                                                  FileProviderItem(metadata: ItemMetadata(id: 6, name: "File 4", type: .file, size: 14, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false), domainIdentifier: .test),
			                                                  FileProviderItem(metadata: ItemMetadata(id: 7, name: "NewFileFromCloud", type: .file, size: 24, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false), domainIdentifier: .test)]

			let firstEnumerationItemList = try await taskExecutor.execute(task: enumerationTask)
			XCTAssertEqual(5, firstEnumerationItemList.items.count)
			XCTAssertEqual(expectedRootFolderFileProviderItems, firstEnumerationItemList.items)
			XCTAssertEqual(expectedRootFolderFileProviderItems.map(\.metadata.name), firstEnumerationItemList.items.map(\.metadata.name))
			XCTAssertEqual(1, self.itemEnumerationTaskManagerMock.removedTaskRecords.count)
			XCTAssert(self.itemEnumerationTaskManagerMock.removedTaskRecords.contains(where: { $0 == enumerationTaskRecord }))

			self.cloudProviderMock.files["/File 1"] = nil
			self.cloudProviderMock.files["/NewFileFromCloud"] = Data("NewFileFromCloud content".utf8)
			let secondEnumerationTaskRecord = ItemEnumerationTaskRecord(correspondingItem: rootItemMetadata.id!, pageToken: nil)
			let secondEnumerationTask = ItemEnumerationTask(taskRecord: secondEnumerationTaskRecord, itemMetadata: rootItemMetadata, cloudPath: CloudPath("/"))
			let secondEnumerationItemList = try await taskExecutor.execute(task: secondEnumerationTask)

			XCTAssertEqual(2, self.itemEnumerationTaskManagerMock.removedTaskRecords.count)
			XCTAssert(self.itemEnumerationTaskManagerMock.removedTaskRecords.contains(where: { $0 == secondEnumerationTaskRecord }))
			XCTAssertEqual(5, secondEnumerationItemList.items.count)
			XCTAssertEqual(expectedChangedRootFolderFileProviderItems, secondEnumerationItemList.items)
			XCTAssertEqual(expectedChangedRootFolderFileProviderItems.map(\.metadata.name), secondEnumerationItemList.items.map(\.metadata.name))
		})
	}

	func testFolderEnumerationPreservesUploadError() async throws {
		let id: Int64 = 3
		let rootItemMetadata = ItemMetadata(id: NSFileProviderItemIdentifier.rootContainerDatabaseValue, name: "Home", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(rootItemMetadata)

		let enumerationTaskRecord = try ItemEnumerationTaskRecord(correspondingItem: XCTUnwrap(rootItemMetadata.id), pageToken: nil)
		let enumerationTask = ItemEnumerationTask(taskRecord: enumerationTaskRecord, itemMetadata: rootItemMetadata, cloudPath: CloudPath("/"))

		let taskExecutor = ItemEnumerationTaskExecutor(domainIdentifier: .test, provider: cloudProviderMock, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock, uploadTaskManager: uploadTaskManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, itemEnumerationTaskManager: itemEnumerationTaskManagerMock, deleteItemHelper: deleteItemHelper)

		let lastFailedUploadDate = Date()
		_ = try await taskExecutor.execute(task: enumerationTask)
		metadataManagerMock.cachedMetadata[id]?.statusCode = .uploadError
		let uploadTask = UploadTaskRecord(correspondingItem: id, lastFailedUploadDate: lastFailedUploadDate, uploadErrorCode: NSFileProviderError(.insufficientQuota).errorCode, uploadErrorDomain: NSFileProviderErrorDomain, uploadStartedAt: nil)
		uploadTaskManagerMock.getCorrespondingTaskRecordsIdsClosure = {
			return $0.map {
				if $0 == id {
					return uploadTask
				} else {
					return nil
				}
			}
		}
		let secondEnumerationTaskRecord = try ItemEnumerationTaskRecord(correspondingItem: XCTUnwrap(rootItemMetadata.id), pageToken: nil)
		let secondEnumerationTask = ItemEnumerationTask(taskRecord: secondEnumerationTaskRecord, itemMetadata: rootItemMetadata, cloudPath: CloudPath("/"))
		let fileProviderItemList = try await taskExecutor.execute(task: secondEnumerationTask)
		XCTAssertEqual(2, itemEnumerationTaskManagerMock.removedTaskRecords.count)
		XCTAssertEqual(5, fileProviderItemList.items.count)
		let errorItem = fileProviderItemList.items[1]
		guard let fetchedItemMetadata = try metadataManagerMock.getCachedMetadata(for: id) else {
			XCTFail("No Metadata in DB")
			return
		}
		XCTAssertEqual(ItemStatus.uploadError, fetchedItemMetadata.statusCode)
		XCTAssertFalse(uploadTaskManagerMock.removeTaskRecordForCalled)
		XCTAssertFalse(uploadTaskManagerMock.createNewTaskRecordForCalled)

		XCTAssertNotNil(errorItem.uploadingError)
		XCTAssertEqual(NSFileProviderError(.insufficientQuota)._nsError, errorItem.uploadingError as NSError?)
	}

	func testPartialFolderEnumerationMarksMetadataAsMaybeOutdated() async throws {
		let paginatedMockedProvider = CloudProviderPaginationMock()

		let rootItemMetadata = ItemMetadata(id: NSFileProviderItemIdentifier.rootContainerDatabaseValue, name: "Home", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(rootItemMetadata)

		let enumerationTaskRecord = try ItemEnumerationTaskRecord(correspondingItem: XCTUnwrap(rootItemMetadata.id), pageToken: nil)
		let enumerationTask = ItemEnumerationTask(taskRecord: enumerationTaskRecord, itemMetadata: rootItemMetadata, cloudPath: CloudPath("/"))

		let taskExecutor = ItemEnumerationTaskExecutor(domainIdentifier: .test, provider: paginatedMockedProvider, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock, uploadTaskManager: uploadTaskManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, itemEnumerationTaskManager: itemEnumerationTaskManagerMock, deleteItemHelper: deleteItemHelper)
		let id: Int64 = 2
		let itemMetadata = ItemMetadata(id: 2, name: "TestItem", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try metadataManagerMock.cachedMetadata[XCTUnwrap(itemMetadata.id)] = itemMetadata

		let fileProviderItemList = try await taskExecutor.execute(task: enumerationTask)
		XCTAssertNotNil(fileProviderItemList.nextPageToken)
		XCTAssertEqual(2, fileProviderItemList.items.count)
		XCTAssertEqual(0, fileProviderItemList.items.filter { $0.metadata.id == itemMetadata.id }.count)
		guard let markedAsMaybeOutdatedCachedMetadata = try metadataManagerMock.getCachedMetadata(for: id) else {
			XCTFail("No ItemMetadata for id found")
			return
		}
		XCTAssert(markedAsMaybeOutdatedCachedMetadata.isMaybeOutdated)
	}

	func testFullFolderEnumerationRemovesInvalidatedCachedMetadata() async throws {
		let paginatedMockedProvider = CloudProviderPaginationMock()

		let rootItemMetadata = ItemMetadata(id: NSFileProviderItemIdentifier.rootContainerDatabaseValue, name: "Home", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(rootItemMetadata)

		// Add some items to the ItemMetadataManager to simulate a previous folder enumeration on the root folder
		try metadataManagerMock.cacheMetadata(ItemMetadata(id: 2, name: "OutdatedFile", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false, isCandidateForCacheCleanup: false))
		try metadataManagerMock.cacheMetadata(ItemMetadata(id: 3, name: "OutdatedFolder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false, isCandidateForCacheCleanup: false))

		let enumerationTaskRecord = try ItemEnumerationTaskRecord(correspondingItem: XCTUnwrap(rootItemMetadata.id), pageToken: nil)
		let enumerationTask = ItemEnumerationTask(taskRecord: enumerationTaskRecord, itemMetadata: rootItemMetadata, cloudPath: CloudPath("/"))

		let taskExecutor = ItemEnumerationTaskExecutor(domainIdentifier: .test, provider: paginatedMockedProvider, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock, uploadTaskManager: uploadTaskManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, itemEnumerationTaskManager: itemEnumerationTaskManagerMock, deleteItemHelper: deleteItemHelper)

		let firstItemList = try await taskExecutor.execute(task: enumerationTask)
		XCTAssertEqual(2, firstItemList.items.count)
		// Check that a next page exists
		XCTAssertNotNil(firstItemList.nextPageToken)
		guard let tokenData = firstItemList.nextPageToken, let nextPageToken = String(data: tokenData.rawValue, encoding: .utf8) else {
			throw NSError(domain: "ItemEnumerationTaskExecutorTestError", code: -100, userInfo: ["localizedDescription": "No page token"])
		}
		// Check that the (possible) old items have been marked as maybe outdated
		XCTAssert(metadataManagerMock.cachedMetadata[2]?.isMaybeOutdated ?? false)
		XCTAssert(metadataManagerMock.cachedMetadata[3]?.isMaybeOutdated ?? false)

		XCTAssertEqual(1, itemEnumerationTaskManagerMock.removedTaskRecords.count)
		XCTAssert(itemEnumerationTaskManagerMock.removedTaskRecords.contains(where: { $0 == enumerationTaskRecord }))

		let secondEnumerationTaskRecord = try ItemEnumerationTaskRecord(correspondingItem: XCTUnwrap(rootItemMetadata.id), pageToken: nextPageToken)
		let secondEnumerationTask = ItemEnumerationTask(taskRecord: secondEnumerationTaskRecord, itemMetadata: rootItemMetadata, cloudPath: CloudPath("/"))
		let secondItemList = try await taskExecutor.execute(task: secondEnumerationTask)
		XCTAssertEqual(2, itemEnumerationTaskManagerMock.removedTaskRecords.count)
		XCTAssertEqual(4, secondItemList.items.count)

		// Check that the whole folder has been enumerated
		XCTAssertNil(secondItemList.nextPageToken)

		// Check that the old items has been removed
		XCTAssertEqual(2, metadataManagerMock.removedMetadataID.count)
		XCTAssert(metadataManagerMock.removedMetadataID.contains { $0 == 2 })
		XCTAssert(metadataManagerMock.removedMetadataID.contains { $0 == 3 })
	}

	func testFolderEnumerationDidNotOverwriteReparentTask() async throws {
		let rootItemMetadata = ItemMetadata(id: NSFileProviderItemIdentifier.rootContainerDatabaseValue, name: "Home", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(rootItemMetadata)

		let enumerationTaskRecord = try ItemEnumerationTaskRecord(correspondingItem: XCTUnwrap(rootItemMetadata.id), pageToken: nil)
		let enumerationTask = ItemEnumerationTask(taskRecord: enumerationTaskRecord, itemMetadata: rootItemMetadata, cloudPath: CloudPath("/"))

		let taskExecutor = ItemEnumerationTaskExecutor(domainIdentifier: .test, provider: cloudProviderMock, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock, uploadTaskManager: uploadTaskManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, itemEnumerationTaskManager: itemEnumerationTaskManagerMock, deleteItemHelper: deleteItemHelper)

		let newCloudPath = CloudPath("/RenamedItem")
		let firstItemList = try await taskExecutor.execute(task: enumerationTask)
		XCTAssertEqual(5, firstItemList.items.count)
		XCTAssertEqual(1, itemEnumerationTaskManagerMock.removedTaskRecords.count)
		XCTAssert(itemEnumerationTaskManagerMock.removedTaskRecords.contains(where: { $0 == enumerationTaskRecord }))
		// Simulate a local rename, i.e. update name, status code and create a reparent task, which renames the item with filename File 1 to RenamedItem
		let item = firstItemList.items[1]
		XCTAssertEqual("File 1", item.filename)
		try reparentTaskManagerMock.reparentTasks[XCTUnwrap(item.metadata.id)] = try ReparentTaskRecord(correspondingItem: XCTUnwrap(item.metadata.id), sourceCloudPath: CloudPath("/").appendingPathComponent(item.metadata.name), targetCloudPath: newCloudPath, oldParentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, newParentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue)

		try metadataManagerMock.cachedMetadata[XCTUnwrap(item.metadata.id)]?.name = "RenamedItem"
		try metadataManagerMock.cachedMetadata[XCTUnwrap(item.metadata.id)]?.statusCode = .isUploading

		// Enumerate the Root folder again, File 1 has not been renamed in the cloud yet
		let secondEnumerationTaskRecord = try ItemEnumerationTaskRecord(correspondingItem: XCTUnwrap(rootItemMetadata.id), pageToken: nil)
		let secondEnumerationTask = ItemEnumerationTask(taskRecord: secondEnumerationTaskRecord, itemMetadata: rootItemMetadata, cloudPath: CloudPath("/"))
		let secondItemList = try await taskExecutor.execute(task: secondEnumerationTask)
		XCTAssertEqual(2, itemEnumerationTaskManagerMock.removedTaskRecords.count)
		XCTAssertEqual(5, secondItemList.items.count)
		// Check that the item has the new name (RenamedItem) and there is no duplicate item with the old name (File 1)
		let renamedItem = secondItemList.items.first(where: { $0.filename == "RenamedItem" })
		let oldItem = secondItemList.items.first(where: { $0.filename == "File 1" })
		XCTAssertNil(oldItem)
		XCTAssertNotNil(renamedItem)
		XCTAssertEqual(ItemStatus.isUploading, renamedItem?.metadata.statusCode)
		XCTAssertEqual(newCloudPath.lastPathComponent, renamedItem?.metadata.name)
	}

	func testFolderEnumerationDidNotOverwriteDeletionTask() async throws {
		let rootItemMetadata = ItemMetadata(id: NSFileProviderItemIdentifier.rootContainerDatabaseValue, name: "Home", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(rootItemMetadata)

		let enumerationTaskRecord = try ItemEnumerationTaskRecord(correspondingItem: XCTUnwrap(rootItemMetadata.id), pageToken: nil)
		let enumerationTask = ItemEnumerationTask(taskRecord: enumerationTaskRecord, itemMetadata: rootItemMetadata, cloudPath: CloudPath("/"))

		let taskExecutor = ItemEnumerationTaskExecutor(domainIdentifier: .test, provider: cloudProviderMock, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock, uploadTaskManager: uploadTaskManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, itemEnumerationTaskManager: itemEnumerationTaskManagerMock, deleteItemHelper: deleteItemHelper)

		let firstItemList = try await taskExecutor.execute(task: enumerationTask)
		XCTAssertEqual(1, itemEnumerationTaskManagerMock.removedTaskRecords.count)
		XCTAssert(itemEnumerationTaskManagerMock.removedTaskRecords.contains(where: { $0 == enumerationTaskRecord }))
		XCTAssertEqual(5, firstItemList.items.count)
		XCTAssertEqual(1, itemEnumerationTaskManagerMock.removedTaskRecords.count)
		XCTAssert(itemEnumerationTaskManagerMock.removedTaskRecords.contains(where: { $0 == enumerationTaskRecord }))
		// Simulate a local item deletion, i.e. update the status code and create a deletion task.
		let item = firstItemList.items[1]
		XCTAssertEqual("File 1", item.filename)
		try deletionTaskManagerMock.deletionTasks[XCTUnwrap(item.metadata.id)] = try DeletionTaskRecord(correspondingItem: XCTUnwrap(item.metadata.id), cloudPath: CloudPath("/").appendingPathComponent(item.metadata.name), parentID: item.metadata.parentID, itemType: item.metadata.type)

		try metadataManagerMock.cachedMetadata[XCTUnwrap(item.metadata.id)]?.statusCode = .isUploading
		// Enumerate the Root folder again, File 1 has not been deleted in the cloud yet
		let secondEnumerationTaskRecord = try ItemEnumerationTaskRecord(correspondingItem: XCTUnwrap(rootItemMetadata.id), pageToken: nil)
		let secondEnumerationTask = ItemEnumerationTask(taskRecord: secondEnumerationTaskRecord, itemMetadata: rootItemMetadata, cloudPath: CloudPath("/"))
		let secondItemList = try await taskExecutor.execute(task: secondEnumerationTask)
		XCTAssertEqual(2, itemEnumerationTaskManagerMock.removedTaskRecords.count)
		// Check that the item is no longer returned in the FileProviderItemList.
		XCTAssertEqual(4, secondItemList.items.count)
		XCTAssertFalse(secondItemList.items.contains(where: { $0.filename == "File 1" }))
	}

	// MARK: Offline Fallback

	func testFolderEnumerationOfflineFallbackWithCachedItems() async throws {
		let folderMetadata = ItemMetadata(id: 2, name: "Folder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false, lastEnumeratedAt: Date())
		try metadataManagerMock.cacheMetadata(folderMetadata)

		let child1 = ItemMetadata(id: 3, name: "File 1", type: .file, size: 14, parentID: 2, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		let child2 = ItemMetadata(id: 4, name: "Directory 1", type: .folder, size: 0, parentID: 2, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(child1)
		try metadataManagerMock.cacheMetadata(child2)

		let enumerationTaskRecord = try ItemEnumerationTaskRecord(correspondingItem: XCTUnwrap(folderMetadata.id), pageToken: nil)
		let enumerationTask = ItemEnumerationTask(taskRecord: enumerationTaskRecord, itemMetadata: folderMetadata, cloudPath: CloudPath("/").appendingPathComponent(folderMetadata.name))

		let errorCloudProviderMock = CloudProviderErrorMock()
		errorCloudProviderMock.fetchItemListResponse = { _, _ in
			throw CloudProviderError.noInternetConnection
		}

		let taskExecutor = ItemEnumerationTaskExecutor(domainIdentifier: .test, provider: errorCloudProviderMock, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock, uploadTaskManager: uploadTaskManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, itemEnumerationTaskManager: itemEnumerationTaskManagerMock, deleteItemHelper: deleteItemHelper)

		let itemList = try await taskExecutor.execute(task: enumerationTask)
		XCTAssertEqual(2, itemList.items.count)
		XCTAssertNil(itemList.nextPageToken)
	}

	func testFolderEnumerationOfflineFallbackWithNoCachedItems() async throws {
		let folderMetadata = ItemMetadata(id: 2, name: "EmptyFolder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(folderMetadata)

		let enumerationTaskRecord = try ItemEnumerationTaskRecord(correspondingItem: XCTUnwrap(folderMetadata.id), pageToken: nil)
		let enumerationTask = ItemEnumerationTask(taskRecord: enumerationTaskRecord, itemMetadata: folderMetadata, cloudPath: CloudPath("/").appendingPathComponent(folderMetadata.name))

		let errorCloudProviderMock = CloudProviderErrorMock()
		errorCloudProviderMock.fetchItemListResponse = { _, _ in
			throw CloudProviderError.noInternetConnection
		}

		let taskExecutor = ItemEnumerationTaskExecutor(domainIdentifier: .test, provider: errorCloudProviderMock, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock, uploadTaskManager: uploadTaskManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, itemEnumerationTaskManager: itemEnumerationTaskManagerMock, deleteItemHelper: deleteItemHelper)

		await XCTAssertThrowsAsyncError(try await taskExecutor.execute(task: enumerationTask)) { error in
			guard let cloudProviderError = error as? CloudProviderError, cloudProviderError == .noInternetConnection else {
				XCTFail("Expected noInternetConnection error but got: \(error)")
				return
			}
		}
	}

	func testFolderEnumerationOfflineFallbackWithEmptyEnumeratedFolder() async throws {
		let folderMetadata = ItemMetadata(id: 2, name: "EmptyFolder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false, lastEnumeratedAt: Date())
		try metadataManagerMock.cacheMetadata(folderMetadata)

		let enumerationTaskRecord = try ItemEnumerationTaskRecord(correspondingItem: XCTUnwrap(folderMetadata.id), pageToken: nil)
		let enumerationTask = ItemEnumerationTask(taskRecord: enumerationTaskRecord, itemMetadata: folderMetadata, cloudPath: CloudPath("/").appendingPathComponent(folderMetadata.name))

		let errorCloudProviderMock = CloudProviderErrorMock()
		errorCloudProviderMock.fetchItemListResponse = { _, _ in
			throw CloudProviderError.noInternetConnection
		}

		let taskExecutor = ItemEnumerationTaskExecutor(domainIdentifier: .test, provider: errorCloudProviderMock, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock, uploadTaskManager: uploadTaskManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, itemEnumerationTaskManager: itemEnumerationTaskManagerMock, deleteItemHelper: deleteItemHelper)

		let itemList = try await taskExecutor.execute(task: enumerationTask)
		XCTAssertEqual(0, itemList.items.count)
		XCTAssertNil(itemList.nextPageToken)
	}

	func testFolderEnumerationOfflineFallbackWithPageToken() async throws {
		let folderMetadata = ItemMetadata(id: 2, name: "Folder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(folderMetadata)

		let child1 = ItemMetadata(id: 3, name: "File 1", type: .file, size: 14, parentID: 2, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(child1)

		let enumerationTaskRecord = try ItemEnumerationTaskRecord(correspondingItem: XCTUnwrap(folderMetadata.id), pageToken: "somePageToken")
		let enumerationTask = ItemEnumerationTask(taskRecord: enumerationTaskRecord, itemMetadata: folderMetadata, cloudPath: CloudPath("/").appendingPathComponent(folderMetadata.name))

		let errorCloudProviderMock = CloudProviderErrorMock()
		errorCloudProviderMock.fetchItemListResponse = { _, _ in
			throw CloudProviderError.noInternetConnection
		}

		let taskExecutor = ItemEnumerationTaskExecutor(domainIdentifier: .test, provider: errorCloudProviderMock, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock, uploadTaskManager: uploadTaskManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, itemEnumerationTaskManager: itemEnumerationTaskManagerMock, deleteItemHelper: deleteItemHelper)

		await XCTAssertThrowsAsyncError(try await taskExecutor.execute(task: enumerationTask)) { error in
			guard let cloudProviderError = error as? CloudProviderError, cloudProviderError == .noInternetConnection else {
				XCTFail("Expected noInternetConnection error but got: \(error)")
				return
			}
		}
	}

	func testFolderEnumerationOfflineFallbackPreservesCachedFileInfo() async throws {
		let folderMetadata = ItemMetadata(id: 2, name: "Folder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false, lastEnumeratedAt: Date())
		try metadataManagerMock.cacheMetadata(folderMetadata)

		let lastModifiedDate = Date(timeIntervalSince1970: 0)
		let child1 = ItemMetadata(id: 3, name: "File 1", type: .file, size: 14, parentID: 2, lastModifiedDate: lastModifiedDate, statusCode: .isUploaded, isPlaceholderItem: false)
		let child2 = ItemMetadata(id: 4, name: "File 2", type: .file, size: 14, parentID: 2, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(child1)
		try metadataManagerMock.cacheMetadata(child2)

		let localURL = URL(fileURLWithPath: "/LocalFile 1")
		try cachedFileManagerMock.cacheLocalFileInfo(for: 3, localURL: localURL, lastModifiedDate: lastModifiedDate)

		let enumerationTaskRecord = try ItemEnumerationTaskRecord(correspondingItem: XCTUnwrap(folderMetadata.id), pageToken: nil)
		let enumerationTask = ItemEnumerationTask(taskRecord: enumerationTaskRecord, itemMetadata: folderMetadata, cloudPath: CloudPath("/").appendingPathComponent(folderMetadata.name))

		let errorCloudProviderMock = CloudProviderErrorMock()
		errorCloudProviderMock.fetchItemListResponse = { _, _ in
			throw CloudProviderError.noInternetConnection
		}

		let taskExecutor = ItemEnumerationTaskExecutor(domainIdentifier: .test, provider: errorCloudProviderMock, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock, uploadTaskManager: uploadTaskManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, itemEnumerationTaskManager: itemEnumerationTaskManagerMock, deleteItemHelper: deleteItemHelper)

		let itemList = try await taskExecutor.execute(task: enumerationTask)
		XCTAssertEqual(2, itemList.items.count)
		XCTAssertNil(itemList.nextPageToken)

		let cachedItem = itemList.items.first(where: { $0.metadata.id == 3 })
		XCTAssertNotNil(cachedItem)
		XCTAssert(try XCTUnwrap(cachedItem?.newestVersionLocallyCached))
		XCTAssertEqual(localURL, cachedItem?.localURL)

		let nonCachedItem = itemList.items.first(where: { $0.metadata.id == 4 })
		XCTAssertNotNil(nonCachedItem)
		XCTAssertFalse(try XCTUnwrap(nonCachedItem?.newestVersionLocallyCached))
		XCTAssertNil(nonCachedItem?.localURL)
	}

	// MARK: Placeholder

	/// A package folder whose creation failed holds the only copy of its contents, so it must stay browsable.
	func testPlaceholderFolderEnumerationServesLocalChildrenWithoutAskingTheCloud() async throws {
		let folderMetadata = ItemMetadata(id: 2, name: "Folder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .uploadError, isPlaceholderItem: true)
		try metadataManagerMock.cacheMetadata(folderMetadata)

		let child = ItemMetadata(id: 3, name: "File 1", type: .file, size: 14, parentID: 2, lastModifiedDate: nil, statusCode: .isUploading, isPlaceholderItem: true)
		try metadataManagerMock.cacheMetadata(child)

		let enumerationTaskRecord = try ItemEnumerationTaskRecord(correspondingItem: XCTUnwrap(folderMetadata.id), pageToken: nil)
		let enumerationTask = ItemEnumerationTask(taskRecord: enumerationTaskRecord, itemMetadata: folderMetadata, cloudPath: CloudPath("/").appendingPathComponent(folderMetadata.name))

		let errorCloudProviderMock = CloudProviderErrorMock()
		errorCloudProviderMock.fetchItemListResponse = { _, _ in
			XCTFail("Asked the cloud to list a folder that was never created there")
			throw CloudProviderError.itemNotFound
		}

		let taskExecutor = ItemEnumerationTaskExecutor(domainIdentifier: .test, provider: errorCloudProviderMock, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock, uploadTaskManager: uploadTaskManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, itemEnumerationTaskManager: itemEnumerationTaskManagerMock, deleteItemHelper: deleteItemHelper)

		let itemList = try await taskExecutor.execute(task: enumerationTask)
		XCTAssertEqual(["File 1"], itemList.items.map { $0.filename })
		XCTAssertNil(itemList.nextPageToken)
	}

	func testPlaceholderFileEnumerationServesTheLocalItemWithoutAskingTheCloud() async throws {
		let fileMetadata = ItemMetadata(id: 2, name: "File 1", type: .file, size: 14, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, isPlaceholderItem: true)
		try metadataManagerMock.cacheMetadata(fileMetadata)

		let enumerationTaskRecord = try ItemEnumerationTaskRecord(correspondingItem: XCTUnwrap(fileMetadata.id), pageToken: nil)
		let enumerationTask = ItemEnumerationTask(taskRecord: enumerationTaskRecord, itemMetadata: fileMetadata, cloudPath: CloudPath("/").appendingPathComponent(fileMetadata.name))

		let errorCloudProviderMock = CloudProviderErrorMock()
		errorCloudProviderMock.fetchItemMetadataResponse = { _ in
			XCTFail("Asked the cloud for a file that was never uploaded there")
			throw CloudProviderError.itemNotFound
		}

		let taskExecutor = ItemEnumerationTaskExecutor(domainIdentifier: .test, provider: errorCloudProviderMock, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock, uploadTaskManager: uploadTaskManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, itemEnumerationTaskManager: itemEnumerationTaskManagerMock, deleteItemHelper: deleteItemHelper)

		let itemList = try await taskExecutor.execute(task: enumerationTask)
		XCTAssertEqual(["File 1"], itemList.items.map { $0.filename })
	}

	/// The initial migration stores the root with the placeholder flag set, but the root always exists in the cloud.
	func testRootEnumerationAsksTheCloudDespiteItsPlaceholderFlag() async throws {
		let rootItemMetadata = ItemMetadata(id: NSFileProviderItemIdentifier.rootContainerDatabaseValue, name: "Home", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: true)
		try metadataManagerMock.cacheMetadata(rootItemMetadata)

		let enumerationTaskRecord = try ItemEnumerationTaskRecord(correspondingItem: XCTUnwrap(rootItemMetadata.id), pageToken: nil)
		let enumerationTask = ItemEnumerationTask(taskRecord: enumerationTaskRecord, itemMetadata: rootItemMetadata, cloudPath: CloudPath("/"))

		let taskExecutor = ItemEnumerationTaskExecutor(domainIdentifier: .test, provider: cloudProviderMock, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock, uploadTaskManager: uploadTaskManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, itemEnumerationTaskManager: itemEnumerationTaskManagerMock, deleteItemHelper: deleteItemHelper)

		let itemList = try await taskExecutor.execute(task: enumerationTask)
		XCTAssertEqual(5, itemList.items.count)
	}

	// MARK: Error Passthrough

	func testFolderEnumerationFailWithSameErrorAsProvider() async throws {
		let cloudPath = CloudPath("/Test")
		let id: Int64 = 2
		let itemMetadata = ItemMetadata(id: id, name: "Test", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(itemMetadata)

		let enumerationTaskRecord = try ItemEnumerationTaskRecord(correspondingItem: XCTUnwrap(itemMetadata.id), pageToken: nil)
		let enumerationTask = ItemEnumerationTask(taskRecord: enumerationTaskRecord, itemMetadata: itemMetadata, cloudPath: CloudPath("/").appendingPathComponent(itemMetadata.name))

		let errorCloudProviderMock = CloudProviderErrorMock()
		errorCloudProviderMock.fetchItemListResponse = { _, _ in
			throw CloudTaskTestError.correctPassthrough
		}

		let taskExecutor = ItemEnumerationTaskExecutor(domainIdentifier: .test, provider: errorCloudProviderMock, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock, uploadTaskManager: uploadTaskManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, itemEnumerationTaskManager: itemEnumerationTaskManagerMock, deleteItemHelper: deleteItemHelper)

		await XCTAssertThrowsAsyncError(try await taskExecutor.execute(task: enumerationTask)) { error in
			guard case CloudTaskTestError.correctPassthrough = error else {
				XCTFail("Rejected with the wrong error: \(error)")
				return
			}
			XCTAssert(metadataManagerMock.removedMetadataID.isEmpty, "Unexpected removal of ItemMetadata")
			XCTAssertEqual(1, itemEnumerationTaskManagerMock.removedTaskRecords.count)
			XCTAssert(itemEnumerationTaskManagerMock.removedTaskRecords.contains(where: { $0 == enumerationTaskRecord }))
		}
	}
}

extension FileProviderItem {
	override open func isEqual(_ object: Any?) -> Bool {
		let other = object as? FileProviderItem
		return filename == other?.filename && itemIdentifier == other?.itemIdentifier && parentItemIdentifier == other?.parentItemIdentifier && typeIdentifier == other?.typeIdentifier && capabilities == other?.capabilities && documentSize == other?.documentSize
	}
}
