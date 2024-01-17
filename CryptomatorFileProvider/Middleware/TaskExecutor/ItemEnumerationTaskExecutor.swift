//
//  ItemEnumerationTaskExecutor.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 18.05.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCloudAccessCore
import FileProvider
import Foundation
import GRDB
import Promises

class ItemEnumerationTaskExecutor: WorkflowMiddleware {
	private var next: AnyWorkflowMiddleware<FileProviderItemList>?

	func setNext(_ next: AnyWorkflowMiddleware<FileProviderItemList>) {
		self.next = next
	}

	func getNext() throws -> AnyWorkflowMiddleware<FileProviderItemList> {
		guard let nextMiddleware = next else {
			throw WorkflowMiddlewareError.missingMiddleware
		}
		return nextMiddleware
	}

	private let itemMetadataManager: ItemMetadataManager
	private let cachedFileManager: CachedFileManager
	private let uploadTaskManager: UploadTaskManager
	private let reparentTaskManager: ReparentTaskManager
	private let deletionTaskManager: DeletionTaskManager
	private let itemEnumerationTaskManager: ItemEnumerationTaskManager
	private let deleteItemHelper: DeleteItemHelper
	private let provider: CloudProvider
	private let domainIdentifier: NSFileProviderDomainIdentifier

	init(domainIdentifier: NSFileProviderDomainIdentifier,
	     provider: CloudProvider,
	     itemMetadataManager: ItemMetadataManager,
	     cachedFileManager: CachedFileManager,
	     uploadTaskManager: UploadTaskManager,
	     reparentTaskManager: ReparentTaskManager,
	     deletionTaskManager: DeletionTaskManager,
	     itemEnumerationTaskManager: ItemEnumerationTaskManager,
	     deleteItemHelper: DeleteItemHelper) {
		self.domainIdentifier = domainIdentifier
		self.provider = provider
		self.itemMetadataManager = itemMetadataManager
		self.cachedFileManager = cachedFileManager
		self.uploadTaskManager = uploadTaskManager
		self.reparentTaskManager = reparentTaskManager
		self.deletionTaskManager = deletionTaskManager
		self.itemEnumerationTaskManager = itemEnumerationTaskManager
		self.deleteItemHelper = deleteItemHelper
	}

	func execute(task: CloudTask) -> Promise<FileProviderItemList> {
		guard let enumerationTask = task as? ItemEnumerationTask else {
			return Promise(WorkflowMiddlewareError.incompatibleCloudTask)
		}
		let itemMetadata = enumerationTask.itemMetadata
		let promise: Promise<FileProviderItemList>
		switch itemMetadata.type {
		case .folder:
			let taskRecord = enumerationTask.taskRecord
			promise = fetchItemList(folderMetadata: itemMetadata, pageToken: taskRecord.pageToken)
		case .file:
			promise = fetchItemMetadata(fileMetadata: itemMetadata)
		default:
			DDLogError("Unable to enumerate items on metadata type: \(itemMetadata.type)")
			promise = Promise(NSFileProviderError(.noSuchItem))
		}
		promise.always {
			do {
				try self.itemEnumerationTaskManager.removeTaskRecord(enumerationTask.taskRecord)
			} catch {
				DDLogError("Remove ItemEnumerationTask failed with error: \(error)")
			}
		}
		return promise
	}

	func fetchItemList(folderMetadata: ItemMetadata, pageToken: String?) -> Promise<FileProviderItemList> {
		return provider.fetchItemList(forFolderAt: folderMetadata.cloudPath, withPageToken: pageToken).then { itemList -> FileProviderItemList in
			if pageToken == nil {
				try self.itemMetadataManager.flagAllItemsAsMaybeOutdated(withParentID: folderMetadata.id!)
			}

			var metadataList = [ItemMetadata]()
			for cloudItem in itemList.items {
				let fileProviderItemMetadata = ItemMetadata(item: cloudItem, withParentID: folderMetadata.id!)
				metadataList.append(fileProviderItemMetadata)
			}
			metadataList = try self.filterOutWaitingReparentTasks(parentID: folderMetadata.id!, for: metadataList)
			metadataList = try self.filterOutWaitingDeletionTasks(parentID: folderMetadata.id!, for: metadataList)
			try self.itemMetadataManager.cacheMetadata(metadataList)
			let reparentMetadata = try self.getReparentMetadata(for: folderMetadata.id!)
			metadataList.append(contentsOf: reparentMetadata)
			let placeholderMetadata = try self.itemMetadataManager.getPlaceholderMetadata(withParentID: folderMetadata.id!)
			metadataList.append(contentsOf: placeholderMetadata)
			let uploadTasks = try self.uploadTaskManager.getTaskRecords(for: metadataList)
			assert(metadataList.count == uploadTasks.count)
			let items = try metadataList.enumerated().map { index, metadata -> FileProviderItem in
				let localCachedFileInfo = try self.cachedFileManager.getLocalCachedFileInfo(for: metadata)
				let newestVersionLocallyCached = localCachedFileInfo?.isCurrentVersion(lastModifiedDateInCloud: metadata.lastModifiedDate) ?? false
				let localURL = localCachedFileInfo?.localURL
				return FileProviderItem(metadata: metadata, domainIdentifier: self.domainIdentifier, newestVersionLocallyCached: newestVersionLocallyCached, localURL: localURL, error: uploadTasks[index]?.failedWithError)
			}
			if let nextPageTokenData = itemList.nextPageToken?.data(using: .utf8) {
				return FileProviderItemList(items: items, nextPageToken: NSFileProviderPage(nextPageTokenData))
			}
			try self.cleanUpNoLongerInTheCloudExistingItems(insideParentID: folderMetadata.id!)
			return FileProviderItemList(items: items, nextPageToken: nil)
		}
	}

	func getReparentMetadata(for parentID: Int64) throws -> [ItemMetadata] {
		let reparentTasks = try reparentTaskManager.getTaskRecordsForItemsWhichAreSoon(in: parentID)
		let reparentMetadata = try itemMetadataManager.getCachedMetadata(forIDs: reparentTasks.map { $0.correspondingItem })
		return reparentMetadata
	}

	func filterOutWaitingReparentTasks(parentID: Int64, for itemMetadata: [ItemMetadata]) throws -> [ItemMetadata] {
		let runningReparentTasks = try reparentTaskManager.getTaskRecordsForItemsWhichWere(in: parentID)
		return itemMetadata.filter { element in
			!runningReparentTasks.contains { $0.sourceCloudPath == element.cloudPath }
		}
	}

	func filterOutWaitingDeletionTasks(parentID: Int64, for itemMetadata: [ItemMetadata]) throws -> [ItemMetadata] {
		let runningDeletionTasks = try deletionTaskManager.getTaskRecordsForItemsWhichWere(in: parentID)
		return itemMetadata.filter { element in
			!runningDeletionTasks.contains { $0.cloudPath == element.cloudPath }
		}
	}

	func fetchItemMetadata(fileMetadata: ItemMetadata) -> Promise<FileProviderItemList> {
		return provider.fetchItemMetadata(at: fileMetadata.cloudPath).then { cloudItem -> FileProviderItemList in
			let fileProviderItemMetadata = ItemMetadata(item: cloudItem, withParentID: fileMetadata.parentID)
			try self.itemMetadataManager.cacheMetadata(fileProviderItemMetadata)
			assert(fileProviderItemMetadata.id == fileMetadata.id)
			let localCachedFileInfo = try self.cachedFileManager.getLocalCachedFileInfo(for: fileProviderItemMetadata)
			let newestVersionLocallyCached = localCachedFileInfo?.isCurrentVersion(lastModifiedDateInCloud: fileProviderItemMetadata.lastModifiedDate) ?? false
			let localURL = localCachedFileInfo?.localURL
			let uploadTask = try self.uploadTaskManager.getTaskRecord(for: fileProviderItemMetadata)

			let item = FileProviderItem(metadata: fileProviderItemMetadata, domainIdentifier: self.domainIdentifier, newestVersionLocallyCached: newestVersionLocallyCached, localURL: localURL, error: uploadTask?.failedWithError)
			return FileProviderItemList(items: [item], nextPageToken: nil)
		}
	}

	func cleanUpNoLongerInTheCloudExistingItems(insideParentID parentID: Int64) throws {
		let outdatedItems = try itemMetadataManager.getMaybeOutdatedItems(withParentID: parentID)
		for outdatedItem in outdatedItems {
			do {
				try deleteItemHelper.removeItemFromCache(outdatedItem)
				try itemMetadataManager.removeItemMetadata(with: outdatedItem.id!)
			} catch CachedFileManagerError.fileHasUnsyncedEdits {
				// TODO: If this happens, it shouldn't be just "ignored". The outdated item is probably a folder, which contains files with unsynced edits. If that's true, they will never successfully sync and need a recovery strategy.
				DDLogError("Removing outdated item \(outdatedItem.id!) with type \(outdatedItem.type) failed due to having unsynced edits")
			}
		}
	}
}
