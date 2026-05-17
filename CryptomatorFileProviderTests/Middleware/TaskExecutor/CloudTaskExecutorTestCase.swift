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
@testable import CryptomatorCommonCore
@testable import CryptomatorFileProvider

class CloudTaskExecutorTestCase: XCTestCase {
	var cloudProviderMock: CustomCloudProviderMock!
	var metadataManagerMock: MetadataManagerMock!
	var cachedFileManagerMock: CachedFileManagerMock!
	var uploadTaskManagerMock: UploadTaskManagerMock!
	var reparentTaskManagerMock: ReparentTaskManagerMock!
	var deletionTaskManagerMock: DeletionTaskManagerMock!
	var itemEnumerationTaskManagerMock: ItemEnumerationTaskManagerMock!
	var downloadTaskManagerMock: DownloadTaskManagerMock!
	var deleteItemHelper: DeleteItemHelper!
	var tmpDirectory: URL!

	override func setUpWithError() throws {
		cloudProviderMock = CustomCloudProviderMock()
		metadataManagerMock = MetadataManagerMock()
		cachedFileManagerMock = CachedFileManagerMock()
		uploadTaskManagerMock = UploadTaskManagerMock()
		reparentTaskManagerMock = ReparentTaskManagerMock()
		deletionTaskManagerMock = DeletionTaskManagerMock()
		itemEnumerationTaskManagerMock = ItemEnumerationTaskManagerMock()
		itemEnumerationTaskManagerMock.itemMetadataManager = metadataManagerMock
		downloadTaskManagerMock = DownloadTaskManagerMock()
		downloadTaskManagerMock.itemMetadataManager = metadataManagerMock
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
		var workingSetMetadata = [ItemMetadata]()
		var setTagData = [Int64: Data?]()
		var setFavoriteRank = [Int64: Int64?]()

		func cacheMetadata(_ metadata: ItemMetadata) throws {
			if let cachedItemMetadata = try childOfFolder(parentID: metadata.parentID, name: metadata.name), cachedItemMetadata.id != NSFileProviderItemIdentifier.rootContainerDatabaseValue {
				metadata.id = cachedItemMetadata.id
				metadata.statusCode = cachedItemMetadata.statusCode
				metadata.tagData = cachedItemMetadata.tagData
				metadata.favoriteRank = cachedItemMetadata.favoriteRank
				metadata.lastEnumeratedAt = cachedItemMetadata.lastEnumeratedAt
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
			if let id = metadata.id {
				cachedMetadata[id] = metadata
			}
		}

		func cacheMetadata(_ itemMetadataList: [ItemMetadata]) throws {
			for metadata in itemMetadataList {
				try cacheMetadata(metadata)
			}
		}

		func getCloudPath(for id: Int64) throws -> CloudPath {
			let rootID = NSFileProviderItemIdentifier.rootContainerDatabaseValue
			if id == rootID {
				return CloudPath("/")
			}
			var components = [String]()
			var currentID = id
			var depth = 0
			while currentID != rootID {
				guard let metadata = cachedMetadata[currentID] else {
					throw FileProviderAdapterError.itemNotFound
				}
				components.insert(metadata.name, at: 0)
				currentID = metadata.parentID
				depth += 1
				if depth > 1024 {
					throw FileProviderAdapterError.unresolvableParentChain
				}
			}
			return components.reduce(CloudPath("/")) { $0.appendingPathComponent($1) }
		}

		func getCachedMetadata(for cloudPath: CloudPath) throws -> ItemMetadata? {
			let rootID = NSFileProviderItemIdentifier.rootContainerDatabaseValue
			if cloudPath == CloudPath("/") {
				return cachedMetadata[rootID]
			}
			var currentID = rootID
			var current: ItemMetadata?
			let components = cloudPath.pathComponents.dropFirst()
			for component in components {
				guard let child = try childOfFolder(parentID: currentID, name: String(component)) else {
					return nil
				}
				currentID = child.id!
				current = child
			}
			return current
		}

		private func childOfFolder(parentID: Int64, name: String) throws -> ItemMetadata? {
			let lowercasedName = name.lowercased()
			return cachedMetadata.values.first(where: { $0.parentID == parentID && $0.name.lowercased() == lowercasedName && $0.id != NSFileProviderItemIdentifier.rootContainerDatabaseValue })
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
			for metadata in cachedMetadata.values where metadata.parentID == parentID && metadata.id != NSFileProviderItemIdentifier.rootContainerDatabaseValue {
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
			let rootID = NSFileProviderItemIdentifier.rootContainerDatabaseValue
			if parent.id == rootID {
				return cachedMetadata.values.filter { $0.id != rootID }
			}
			var result = [ItemMetadata]()
			var queue: [Int64] = [parent.id!]
			while let current = queue.first {
				queue.removeFirst()
				for metadata in cachedMetadata.values where metadata.parentID == current && metadata.id != current {
					result.append(metadata)
					queue.append(metadata.id!)
				}
			}
			return result
		}

		func getAllCachedMetadataInsideWorkingSet() throws -> [ItemMetadata] {
			return workingSetMetadata
		}

		func setTagData(to tagData: Data?, forItemWithID id: Int64) throws {
			let metadata = cachedMetadata[id]
			metadata?.tagData = tagData
			cachedMetadata[id] = metadata
			setTagData[id] = tagData
		}

		func setFavoriteRank(to favoriteRank: Int64?, forItemWithID id: Int64) throws {
			let metadata = cachedMetadata[id]
			metadata?.favoriteRank = favoriteRank
			cachedMetadata[id] = metadata
			setFavoriteRank[id] = favoriteRank
		}

		func setLastEnumeratedAt(_ date: Date, forItemWithID id: Int64) throws {
			let metadata = cachedMetadata[id]
			metadata?.lastEnumeratedAt = date
			cachedMetadata[id] = metadata
		}
	}

	class CachedFileManagerMock: CachedFileManager {
		func clearCache() throws {}

		var cachedLocalFileInfo = [Int64: LocalCachedFileInfo]()
		var removeCachedFile = [Int64]()

		func getLocalCachedFileInfo(for identifier: Int64) throws -> LocalCachedFileInfo? {
			cachedLocalFileInfo[identifier]
		}

		func getLocalCachedFileInfo(forIds ids: [Int64]) throws -> [LocalCachedFileInfo?] {
			ids.map { cachedLocalFileInfo[$0] }
		}

		func cacheLocalFileInfo(for identifier: Int64, localURL: URL, lastModifiedDate: Date?) throws {
			cachedLocalFileInfo[identifier] = LocalCachedFileInfo(lastModifiedDate: lastModifiedDate, correspondingItem: identifier, localLastModifiedDate: Date(), localURL: localURL)
		}

		func removeCachedFile(for identifier: Int64) throws {
			let localFileInfo = cachedLocalFileInfo[identifier]
			cachedLocalFileInfo[identifier] = nil
			removeCachedFile.append(identifier)
			if let localURL = localFileInfo?.localURL {
				try? FileManager.default.removeItem(at: localURL)
			}
		}

		func getLocalCacheSizeInBytes() throws -> Int {
			return 0
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

		func downloadFile(from cloudPath: CryptomatorCloudAccessCore.CloudPath, to localURL: URL, onTaskCreation: ((URLSessionDownloadTask?) -> Void)?) -> Promises.Promise<Void> {
			downloadFileResponse?(cloudPath, localURL) ?? Promise(MockError.notMocked)
		}

		func uploadFile(from localURL: URL, to cloudPath: CryptomatorCloudAccessCore.CloudPath, replaceExisting: Bool, onTaskCreation: ((URLSessionUploadTask?) -> Void)?) -> Promises.Promise<CryptomatorCloudAccessCore.CloudItemMetadata> {
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

		func createTaskRecord(for item: ItemMetadata, cloudPath: CloudPath) throws -> DeletionTaskRecord {
			let deletionTask = DeletionTaskRecord(correspondingItem: item.id!, cloudPath: cloudPath, parentID: item.parentID, itemType: item.type)
			deletionTasks[item.id!] = deletionTask
			associatedItemMetadata[item.id!] = item
			return deletionTask
		}

		func getTaskRecord(for id: Int64) throws -> DeletionTaskRecord {
			guard let record = deletionTasks[id] else {
				throw DBManagerError.taskNotFound
			}
			return record
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
			return DeletionTask(taskRecord: deletionTask, itemMetadata: itemMetadata, cloudPath: deletionTask.cloudPath)
		}
	}

	class ReparentTaskManagerMock: ReparentTaskManager {
		var associatedItemMetadata = [Int64: ItemMetadata]()
		var reparentTasks = [Int64: ReparentTaskRecord]()
		var removedReparentTasks = [ReparentTaskRecord]()

		func createTaskRecord(for itemMetadata: ItemMetadata, sourceCloudPath: CloudPath, targetCloudPath: CloudPath, newParentID: Int64) throws -> ReparentTaskRecord {
			let taskRecord = ReparentTaskRecord(correspondingItem: itemMetadata.id!, sourceCloudPath: sourceCloudPath, targetCloudPath: targetCloudPath, oldParentID: itemMetadata.parentID, newParentID: newParentID)
			reparentTasks[itemMetadata.id!] = taskRecord
			associatedItemMetadata[itemMetadata.id!] = itemMetadata
			return taskRecord
		}

		func renameItemAndUpdateReparentTask(itemMetadata: ItemMetadata, newName: String, targetCloudPath: CloudPath, reparentRecord: ReparentTaskRecord) throws -> ReparentTaskRecord {
			itemMetadata.name = newName
			let refreshed = ReparentTaskRecord(correspondingItem: reparentRecord.correspondingItem, sourceCloudPath: reparentRecord.sourceCloudPath, targetCloudPath: targetCloudPath, oldParentID: reparentRecord.oldParentID, newParentID: reparentRecord.newParentID)
			reparentTasks[reparentRecord.correspondingItem] = refreshed
			return refreshed
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
			return ReparentTask(taskRecord: reparentTask, itemMetadata: itemMetadata, cloudPath: reparentTask.sourceCloudPath)
		}
	}

	class ItemEnumerationTaskManagerMock: ItemEnumerationTaskManager {
		var removedTaskRecords = [ItemEnumerationTaskRecord]()
		var createdTasks = [ItemEnumerationTask]()

		var itemMetadataManager: ItemMetadataManager?
		var stubCloudPath: CloudPath?

		func createTask(for item: ItemMetadata, pageToken: String?) throws -> ItemEnumerationTask {
			let taskRecord = ItemEnumerationTaskRecord(correspondingItem: item.id!, pageToken: pageToken)
			let cloudPath = try stubCloudPath ?? itemMetadataManager?.getCloudPath(for: item.id!) ?? CloudPath("/")
			let task = ItemEnumerationTask(taskRecord: taskRecord, itemMetadata: item, cloudPath: cloudPath)
			createdTasks.append(task)
			return task
		}

		func removeTaskRecord(_ task: ItemEnumerationTaskRecord) throws {
			removedTaskRecords.append(task)
		}
	}

	class DownloadTaskManagerMock: DownloadTaskManager {
		var removedTasks = [DownloadTaskRecord]()

		var itemMetadataManager: ItemMetadataManager?
		var stubCloudPath: CloudPath?

		func createTask(for item: ItemMetadata, replaceExisting: Bool, localURL: URL, onURLSessionTaskCreation: CryptomatorFileProvider.URLSessionTaskCreationClosure?) throws -> DownloadTask {
			let taskRecord = DownloadTaskRecord(correspondingItem: item.id!, replaceExisting: replaceExisting, localURL: localURL)
			let cloudPath = try stubCloudPath ?? itemMetadataManager?.getCloudPath(for: item.id!) ?? CloudPath("/")
			return DownloadTask(taskRecord: taskRecord, itemMetadata: item, cloudPath: cloudPath, onURLSessionTaskCreation: onURLSessionTaskCreation)
		}

		func removeTaskRecord(_ task: DownloadTaskRecord) throws {
			removedTasks.append(task)
		}
	}

	enum CloudTaskTestError: Error {
		case correctPassthrough
	}
}
