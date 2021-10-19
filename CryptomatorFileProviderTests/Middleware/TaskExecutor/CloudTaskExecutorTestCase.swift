//
//  CloudTaskExecutorTestCase.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 26.05.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Promises
import XCTest
@testable import CryptomatorFileProvider

class CloudTaskExecutorTestCase: XCTestCase {
	var cloudProviderMock: CloudProviderMock!
	var metadataManagerMock: MetadataManagerMock!
	var cachedFileManagerMock: CachedFileManagerMock!
	var uploadTaskManagerMock: UploadTaskManagerMock!
	var reparentTaskManagerMock: ReparentTaskManagerMock!
	var deletionTaskManagerMock: DeletionTaskManagerMock!
	var itemEnumerationTaskManagerMock: ItemEnumerationTaskManagerMock!
	var deleteItemHelper: DeleteItemHelper!
	var tmpDirectory: URL!

	override func setUpWithError() throws {
		cloudProviderMock = CloudProviderMock()
		metadataManagerMock = MetadataManagerMock()
		cachedFileManagerMock = CachedFileManagerMock()
		uploadTaskManagerMock = UploadTaskManagerMock()
		reparentTaskManagerMock = ReparentTaskManagerMock()
		deletionTaskManagerMock = DeletionTaskManagerMock()
		itemEnumerationTaskManagerMock = ItemEnumerationTaskManagerMock()
		deleteItemHelper = DeleteItemHelper(itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock)
		tmpDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: tmpDirectory, withIntermediateDirectories: false, attributes: nil)
	}

	override func tearDownWithError() throws {
		try FileManager.default.removeItem(at: tmpDirectory)
	}

	class MetadataManagerMock: ItemMetadataManager {
		var cachedMetadata = [Int64: ItemMetadata]()
		var removedMetadataID = [Int64]()
		var updatedMetadata = [ItemMetadata]()

		func cacheMetadata(_ metadata: ItemMetadata) throws {
			if let cachedItemMetadata = try getCachedMetadata(for: metadata.cloudPath) {
				metadata.id = cachedItemMetadata.id
				metadata.statusCode = cachedItemMetadata.statusCode
				cachedMetadata[cachedItemMetadata.id!] = metadata
				return
			}
			if let itemID = metadata.id {
				cachedMetadata[itemID] = metadata
			} else {
				let itemID = Int64(cachedMetadata.count + 1)
				metadata.id = itemID
				cachedMetadata[itemID] = metadata
			}
		}

		func getCachedMetadata(for identifier: Int64) throws -> ItemMetadata? {
			return cachedMetadata[identifier]
		}

		func updateMetadata(_ metadata: ItemMetadata) throws {
			updatedMetadata.append(metadata)
		}

		func cacheMetadata(_ itemMetadataList: [ItemMetadata]) throws {
			for metadata in itemMetadataList {
				try cacheMetadata(metadata)
			}
		}

		func getCachedMetadata(for cloudPath: CloudPath) throws -> ItemMetadata? {
			cachedMetadata.first(where: { $1.cloudPath == cloudPath })?.value
		}

		func getPlaceholderMetadata(withParentID parentID: Int64) throws -> [ItemMetadata] {
			var result = [ItemMetadata]()
			for metadata in cachedMetadata.values where metadata.parentID == parentID && metadata.isPlaceholderItem {
				result.append(metadata)
			}
			return result
		}

		func getCachedMetadata(withParentID parentID: Int64) throws -> [ItemMetadata] {
			var result = [ItemMetadata]()
			for metadata in cachedMetadata.values where metadata.parentID == parentID {
				result.append(metadata)
			}
			return result
		}

		func flagAllItemsAsMaybeOutdated(withParentID parentID: Int64) throws {
			for metadata in cachedMetadata.values where metadata.parentID == parentID && metadata.id != getRootContainerID() {
				metadata.isMaybeOutdated = true
			}
		}

		func getMaybeOutdatedItems(withParentID parentID: Int64) throws -> [ItemMetadata] {
			var result = [ItemMetadata]()
			for metadata in cachedMetadata.values where metadata.isMaybeOutdated && metadata.parentID == parentID {
				result.append(metadata)
			}
			return result
		}

		func removeItemMetadata(with identifier: Int64) throws {
			removedMetadataID.append(identifier)
			cachedMetadata[identifier] = nil
		}

		func removeItemMetadata(_ identifiers: [Int64]) throws {
			for id in identifiers {
				try removeItemMetadata(with: id)
			}
		}

		func getCachedMetadata(forIDs ids: [Int64]) throws -> [ItemMetadata] {
			return try ids.map { try getCachedMetadata(for: $0)! }
		}

		func getAllCachedMetadata(inside parent: ItemMetadata) throws -> [ItemMetadata] {
			var result = [ItemMetadata]()
			for metadata in cachedMetadata.values {
				if metadata.id == parent.id {
					continue
				}
				if metadata.parentID == parent.id {
					result.append(metadata)
				} else if metadata.cloudPath.path.hasPrefix(parent.cloudPath.path) {
					result.append(metadata)
				}
			}
			return result
		}
	}

	class CachedFileManagerMock: CachedFileManager {
		func clearCache() throws {}

		var cachedLocalFileInfo = [Int64: LocalCachedFileInfo]()
		var removeCachedFile = [Int64]()

		func getLocalCachedFileInfo(for identifier: Int64) throws -> LocalCachedFileInfo? {
			cachedLocalFileInfo[identifier]
		}

		func cacheLocalFileInfo(for identifier: Int64, localURL: URL, lastModifiedDate: Date?) throws {
			cachedLocalFileInfo[identifier] = LocalCachedFileInfo(lastModifiedDate: lastModifiedDate, correspondingItem: identifier, localLastModifiedDate: Date(), localURL: localURL)
		}

		func removeCachedFile(for identifier: Int64) throws {
			cachedLocalFileInfo[identifier] = nil
			removeCachedFile.append(identifier)
		}

		func getLocalCacheSizeInBytes() throws -> Int {
			return 0
		}
	}

	class UploadTaskManagerMock: UploadTaskManager {
		var uploadTasks = [Int64: UploadTaskRecord]()
		var removedUploadTaskID = [Int64]()
		var associatedItemMetadata = [Int64: ItemMetadata]()

		func createNewTaskRecord(for itemMetadata: ItemMetadata) throws -> UploadTaskRecord {
			let taskRecord = UploadTaskRecord(correspondingItem: itemMetadata.id!, lastFailedUploadDate: nil, uploadErrorCode: nil, uploadErrorDomain: nil)
			uploadTasks[itemMetadata.id!] = taskRecord
			associatedItemMetadata[itemMetadata.id!] = itemMetadata
			return taskRecord
		}

		func getTaskRecord(for identifier: Int64) throws -> UploadTaskRecord? {
			return uploadTasks[identifier]
		}

		func updateTaskRecord(with identifier: Int64, lastFailedUploadDate: Date, uploadErrorCode: Int, uploadErrorDomain: String) throws {
			throw MockError.notMocked
		}

		func updateTaskRecord(_ task: inout UploadTaskRecord, error: NSError) throws {
			throw MockError.notMocked
		}

		func getCorrespondingTaskRecords(ids: [Int64]) throws -> [UploadTaskRecord?] {
			ids.map { uploadTasks[$0] }
		}

		func updateTaskRecord(_ task: UploadTaskRecord) throws {
			throw MockError.notMocked
		}

		func removeTaskRecord(for identifier: Int64) throws {
			uploadTasks.removeValue(forKey: identifier)
			removedUploadTaskID.append(identifier)
		}

		func getTask(for uploadTask: UploadTaskRecord) throws -> UploadTask {
			guard let itemMetadata = associatedItemMetadata[uploadTask.correspondingItem] else {
				throw DBManagerError.missingItemMetadata
			}
			return UploadTask(taskRecord: uploadTask, itemMetadata: itemMetadata)
		}
	}

	enum MockError: Error {
		case notMocked
	}

	class CloudProviderErrorMock: CloudProvider {
		var fetchItemMetadataResponse: ((CloudPath) -> Promise<CloudItemMetadata>)?
		var fetchItemListResponse: ((CloudPath, String?) -> Promise<CloudItemList>)?
		var downloadFileResponse: ((CloudPath, URL) -> Promise<Void>)?
		var uploadFileResponse: ((URL, CloudPath, Bool) -> Promise<CloudItemMetadata>)?
		var deleteFileResponse: ((CloudPath) -> Promise<Void>)?
		var deleteFolderResponse: ((CloudPath) -> Promise<Void>)?
		var moveFileResponse: ((CloudPath, CloudPath) -> Promise<Void>)?
		var moveFolderResponse: ((CloudPath, CloudPath) -> Promise<Void>)?
		var createFolderResponse: ((CloudPath) -> Promise<Void>)?

		func fetchItemMetadata(at cloudPath: CloudPath) -> Promise<CloudItemMetadata> {
			fetchItemMetadataResponse?(cloudPath) ?? Promise(MockError.notMocked)
		}

		func fetchItemList(forFolderAt cloudPath: CloudPath, withPageToken pageToken: String?) -> Promise<CloudItemList> {
			fetchItemListResponse?(cloudPath, pageToken) ?? Promise(MockError.notMocked)
		}

		func downloadFile(from cloudPath: CloudPath, to localURL: URL) -> Promise<Void> {
			downloadFileResponse?(cloudPath, localURL) ?? Promise(MockError.notMocked)
		}

		func uploadFile(from localURL: URL, to cloudPath: CloudPath, replaceExisting: Bool) -> Promise<CloudItemMetadata> {
			uploadFileResponse?(localURL, cloudPath, replaceExisting) ?? Promise(MockError.notMocked)
		}

		func createFolder(at cloudPath: CloudPath) -> Promise<Void> {
			createFolderResponse?(cloudPath) ?? Promise(MockError.notMocked)
		}

		func deleteFile(at cloudPath: CloudPath) -> Promise<Void> {
			deleteFileResponse?(cloudPath) ?? Promise(MockError.notMocked)
		}

		func deleteFolder(at cloudPath: CloudPath) -> Promise<Void> {
			deleteFolderResponse?(cloudPath) ?? Promise(MockError.notMocked)
		}

		func moveFile(from sourceCloudPath: CloudPath, to targetCloudPath: CloudPath) -> Promise<Void> {
			moveFileResponse?(sourceCloudPath, targetCloudPath) ?? Promise(MockError.notMocked)
		}

		func moveFolder(from sourceCloudPath: CloudPath, to targetCloudPath: CloudPath) -> Promise<Void> {
			moveFolderResponse?(sourceCloudPath, targetCloudPath) ?? Promise(MockError.notMocked)
		}
	}

	class DeletionTaskManagerMock: DeletionTaskManager {
		var deletionTasks = [Int64: DeletionTaskRecord]()
		var associatedItemMetadata = [Int64: ItemMetadata]()

		func createTaskRecord(for item: ItemMetadata) throws -> DeletionTaskRecord {
			let deletionTask = DeletionTaskRecord(correspondingItem: item.id!, cloudPath: item.cloudPath, parentID: item.parentID, itemType: item.type)
			deletionTasks[item.id!] = deletionTask
			associatedItemMetadata[item.id!] = item
			return deletionTask
		}

		func getTaskRecord(for id: Int64) throws -> DeletionTaskRecord {
			throw MockError.notMocked
		}

		func removeTaskRecord(_ task: DeletionTaskRecord) throws {
			throw MockError.notMocked
		}

		func getTaskRecordsForItemsWhichWere(in parentID: Int64) throws -> [DeletionTaskRecord] {
			var result = [DeletionTaskRecord]()
			for deletionTask in deletionTasks.values where deletionTask.parentID == parentID {
				result.append(deletionTask)
			}
			return result
		}

		func getTask(for deletionTask: DeletionTaskRecord) throws -> DeletionTask {
			guard let itemMetadata = associatedItemMetadata[deletionTask.correspondingItem] else {
				throw DBManagerError.missingItemMetadata
			}
			return DeletionTask(taskRecord: deletionTask, itemMetadata: itemMetadata)
		}
	}

	class ReparentTaskManagerMock: ReparentTaskManager {
		var associatedItemMetadata = [Int64: ItemMetadata]()
		var reparentTasks = [Int64: ReparentTaskRecord]()
		var removedReparentTasks = [ReparentTaskRecord]()

		func createTaskRecord(for itemMetadata: ItemMetadata, targetCloudPath: CloudPath, newParentID: Int64) throws -> ReparentTaskRecord {
			let taskRecord = ReparentTaskRecord(correspondingItem: itemMetadata.id!, sourceCloudPath: itemMetadata.cloudPath, targetCloudPath: targetCloudPath, oldParentID: itemMetadata.parentID, newParentID: newParentID)
			reparentTasks[itemMetadata.id!] = taskRecord
			associatedItemMetadata[itemMetadata.id!] = itemMetadata
			return taskRecord
		}

		func removeTaskRecord(_ task: ReparentTaskRecord) throws {
			removedReparentTasks.append(task)
		}

		func getTaskRecordsForItemsWhichWere(in parentID: Int64) throws -> [ReparentTaskRecord] {
			var result = [ReparentTaskRecord]()
			for reparentTask in reparentTasks.values where reparentTask.oldParentID == parentID {
				result.append(reparentTask)
			}
			return result
		}

		func getTaskRecordsForItemsWhichAreSoon(in parentID: Int64) throws -> [ReparentTaskRecord] {
			var result = [ReparentTaskRecord]()
			for reparentTask in reparentTasks.values where reparentTask.newParentID == parentID {
				result.append(reparentTask)
			}
			return result
		}

		func getTask(for reparentTask: ReparentTaskRecord) throws -> ReparentTask {
			guard let itemMetadata = associatedItemMetadata[reparentTask.correspondingItem] else {
				throw DBManagerError.missingItemMetadata
			}
			return ReparentTask(taskRecord: reparentTask, itemMetadata: itemMetadata)
		}
	}

	class ItemEnumerationTaskManagerMock: ItemEnumerationTaskManager {
		var removedTaskRecords = [ItemEnumerationTaskRecord]()
		var createdTasks = [ItemEnumerationTask]()

		func createTask(for item: ItemMetadata, pageToken: String?) throws -> ItemEnumerationTask {
			let taskRecord = ItemEnumerationTaskRecord(correspondingItem: item.id!, pageToken: pageToken)
			let task = ItemEnumerationTask(taskRecord: taskRecord, itemMetadata: item)
			createdTasks.append(task)
			return task
		}

		func removeTaskRecord(_ task: ItemEnumerationTaskRecord) throws {
			removedTaskRecords.append(task)
		}
	}

	enum CloudTaskTestError: Error {
		case correctPassthrough
	}
}
