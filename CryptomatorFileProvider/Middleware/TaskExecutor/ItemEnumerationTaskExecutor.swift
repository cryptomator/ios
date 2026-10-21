//
//  ItemEnumerationTaskExecutor.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 18.05.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import FileProvider
import Foundation
import GRDB

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

	func execute(task: CloudTask) async throws -> FileProviderItemList {
		guard let enumerationTask = task as? ItemEnumerationTask else {
			throw WorkflowMiddlewareError.incompatibleCloudTask
		}
		defer {
			do {
				try itemEnumerationTaskManager.removeTaskRecord(enumerationTask.taskRecord)
			} catch {
				DDLogError("Remove ItemEnumerationTask failed with error: \(error)")
			}
		}
		let itemMetadata = enumerationTask.itemMetadata
		let cloudPath = enumerationTask.cloudPath
		// The cloud knows nothing about an item whose creation failed or never ran, so its local rows are all there is. The root
		// is excluded, because its row carries the placeholder flag from the initial migration.
		if itemMetadata.isPlaceholderItem, itemMetadata.id != NSFileProviderItemIdentifier.rootContainerDatabaseValue {
			return try buildPlaceholderItemList(for: itemMetadata)
		}
		switch itemMetadata.type {
		case .folder:
			let taskRecord = enumerationTask.taskRecord
			return try await fetchItemList(folderMetadata: itemMetadata, folderCloudPath: cloudPath, pageToken: taskRecord.pageToken)
		case .file:
			return try await fetchItemMetadata(fileMetadata: itemMetadata, fileCloudPath: cloudPath)
		default:
			DDLogError("Unable to enumerate items on metadata type: \(itemMetadata.type)")
			throw NSFileProviderError(.noSuchItem)
		}
	}

	func fetchItemList(folderMetadata: ItemMetadata, folderCloudPath: CloudPath, pageToken: String?) async throws -> FileProviderItemList {
		do {
			let itemList = try await provider.fetchItemList(forFolderAt: folderCloudPath, withPageToken: pageToken)
			if pageToken == nil {
				try itemMetadataManager.flagAllItemsAsMaybeOutdated(withParentID: folderMetadata.id!)
			}

			var metadataList = [ItemMetadata]()
			for cloudItem in itemList.items {
				let fileProviderItemMetadata = ItemMetadata(item: cloudItem, withParentID: folderMetadata.id!)
				metadataList.append(fileProviderItemMetadata)
			}
			metadataList = try filterOutWaitingReparentTasks(parentID: folderMetadata.id!, for: metadataList)
			metadataList = try filterOutWaitingDeletionTasks(parentID: folderMetadata.id!, for: metadataList)
			try itemMetadataManager.cacheMetadata(metadataList)
			let reparentMetadata = try getReparentMetadata(for: folderMetadata.id!)
			metadataList.append(contentsOf: reparentMetadata)
			let placeholderMetadata = try itemMetadataManager.getPlaceholderMetadata(withParentID: folderMetadata.id!)
			metadataList.append(contentsOf: placeholderMetadata)
			let items = try FileProviderItem.items(from: metadataList, domainIdentifier: domainIdentifier, uploadTaskManager: uploadTaskManager, cachedFileManager: cachedFileManager)
			if let nextPageToken = itemList.nextPageToken {
				let nextPageTokenData = Data(nextPageToken.utf8)
				return FileProviderItemList(items: items, nextPageToken: NSFileProviderPage(nextPageTokenData))
			}
			try cleanUpNoLongerInTheCloudExistingItems(insideParentID: folderMetadata.id!)
			try itemMetadataManager.setLastEnumeratedAt(Date(), forItemWithID: folderMetadata.id!)
			return FileProviderItemList(items: items, nextPageToken: nil)
		} catch let error where error.isNoInternetConnectionError && pageToken == nil {
			return try buildOfflineItemList(folderMetadata: folderMetadata, folderCloudPath: folderCloudPath, originalError: error)
		}
	}

	private func buildOfflineItemList(folderMetadata: ItemMetadata, folderCloudPath: CloudPath, originalError: Error) throws -> FileProviderItemList {
		guard folderMetadata.lastEnumeratedAt != nil else {
			throw originalError
		}
		do {
			let itemList = try buildCachedItemList(folderMetadata: folderMetadata)
			DDLogInfo("Offline fallback: serving \(itemList.items.count) cached items for folder \(folderCloudPath.path)")
			return itemList
		} catch {
			DDLogError("Offline fallback failed for folder \(folderCloudPath.path): \(error)")
			throw error
		}
	}

	private func buildPlaceholderItemList(for itemMetadata: ItemMetadata) throws -> FileProviderItemList {
		if itemMetadata.type == .folder {
			return try buildCachedItemList(folderMetadata: itemMetadata)
		}
		let items = try FileProviderItem.items(from: [itemMetadata], domainIdentifier: domainIdentifier, uploadTaskManager: uploadTaskManager, cachedFileManager: cachedFileManager)
		return FileProviderItemList(items: items, nextPageToken: nil)
	}

	private func buildCachedItemList(folderMetadata: ItemMetadata) throws -> FileProviderItemList {
		let cachedMetadata = try itemMetadataManager.getCachedMetadata(withParentID: folderMetadata.id!)
		let items = try FileProviderItem.items(from: cachedMetadata, domainIdentifier: domainIdentifier, uploadTaskManager: uploadTaskManager, cachedFileManager: cachedFileManager)
		return FileProviderItemList(items: items, nextPageToken: nil)
	}

	func getReparentMetadata(for parentID: Int64) throws -> [ItemMetadata] {
		let reparentTasks = try reparentTaskManager.getTaskRecordsForItemsWhichAreSoon(in: parentID)
		return try itemMetadataManager.getCachedMetadata(forIDs: reparentTasks.map { $0.correspondingItem })
	}

	func filterOutWaitingReparentTasks(parentID: Int64, for itemMetadata: [ItemMetadata]) throws -> [ItemMetadata] {
		let runningReparentTasks = try reparentTaskManager.getTaskRecordsForItemsWhichWere(in: parentID)
		return itemMetadata.filter { element in
			!runningReparentTasks.contains { $0.oldParentID == element.parentID && $0.sourceCloudPath.lastPathComponent == element.name }
		}
	}

	func filterOutWaitingDeletionTasks(parentID: Int64, for itemMetadata: [ItemMetadata]) throws -> [ItemMetadata] {
		let runningDeletionTasks = try deletionTaskManager.getTaskRecordsForItemsWhichWere(in: parentID)
		return itemMetadata.filter { element in
			!runningDeletionTasks.contains { $0.parentID == element.parentID && $0.cloudPath.lastPathComponent == element.name }
		}
	}

	func fetchItemMetadata(fileMetadata: ItemMetadata, fileCloudPath: CloudPath) async throws -> FileProviderItemList {
		let cloudItem = try await provider.fetchItemMetadata(at: fileCloudPath)
		let fileProviderItemMetadata = ItemMetadata(item: cloudItem, withParentID: fileMetadata.parentID)
		try itemMetadataManager.cacheMetadata(fileProviderItemMetadata)
		assert(fileProviderItemMetadata.id == fileMetadata.id)
		let localCachedFileInfo = try cachedFileManager.getLocalCachedFileInfo(for: fileProviderItemMetadata)
		let uploadTask = try uploadTaskManager.getTaskRecord(for: fileProviderItemMetadata)
		let item = FileProviderItem(metadata: fileProviderItemMetadata, domainIdentifier: domainIdentifier, localCachedFileInfo: localCachedFileInfo, error: uploadTask?.failedWithError)
		return FileProviderItemList(items: [item], nextPageToken: nil)
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
