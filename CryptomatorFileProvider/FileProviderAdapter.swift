//
//  FileProviderAdapter.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 04.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import FileProvider
import Foundation
import Promises

public class FileProviderAdapter {
	private let uploadTaskManager: UploadTaskManager
	private let cachedFileManager: CachedFileManager
	private let itemMetadataManager: ItemMetadataManager
	private let reparentTaskManager: ReparentTaskManager
	private let deletionTaskManager: DeletionTaskManager
	private let itemEnumerationTaskManager: ItemEnumerationTaskManager
	private let downloadTaskManager: DownloadTaskManager
	private let scheduler: WorkflowScheduler
	private let provider: CloudProvider
	private weak var localURLProvider: LocalURLProvider?
	private let notificator: FileProviderItemUpdateDelegate?

	init(uploadTaskManager: UploadTaskManager, cachedFileManager: CachedFileManager, itemMetadataManager: ItemMetadataManager, reparentTaskManager: ReparentTaskManager, deletionTaskManager: DeletionTaskManager, itemEnumerationTaskManager: ItemEnumerationTaskManager, downloadTaskManager: DownloadTaskManager, scheduler: WorkflowScheduler, provider: CloudProvider, notificator: FileProviderItemUpdateDelegate? = nil, localURLProvider: LocalURLProvider? = nil) {
		self.uploadTaskManager = uploadTaskManager
		self.cachedFileManager = cachedFileManager
		self.itemMetadataManager = itemMetadataManager
		self.reparentTaskManager = reparentTaskManager
		self.deletionTaskManager = deletionTaskManager
		self.itemEnumerationTaskManager = itemEnumerationTaskManager
		self.downloadTaskManager = downloadTaskManager
		self.scheduler = scheduler
		self.provider = provider
		self.notificator = notificator
		self.localURLProvider = localURLProvider
	}

	public func persistentIdentifierForItem(at url: URL) -> NSFileProviderItemIdentifier? {
		// resolve the given URL to a persistent identifier using a database
		let pathComponents = url.pathComponents

		// exploit the fact that the path structure has been defined as
		// <base storage directory>/<item identifier>/<item file name> above
		assert(pathComponents.count > 2)

		return NSFileProviderItemIdentifier(pathComponents[pathComponents.count - 2])
	}

	/**
	 Gets the locally stored metadata for an identifier.

	 - Precondition: The passed `identifier` is a valid `identifier` and the corresponding item is stored in the database.
	 - Postcondition: If there was an upload error for the associated item, it was added to the returned `FileProviderItem`.
	 - Postcondition: If there was information about the associated local file, it was added to the returned `FileProviderItem`.
	 - Returns: `FileProviderItem` with the locally stored metadata for the passed `identifier`.
	 */
	public func item(for identifier: NSFileProviderItemIdentifier) throws -> NSFileProviderItem {
		let itemMetadata = try getCachedMetadata(for: identifier)
		let uploadTask = try uploadTaskManager.getTaskRecord(for: itemMetadata)
		let localCachedFileInfo = try cachedFileManager.getLocalCachedFileInfo(for: itemMetadata)
		let newestVersionLocallyCached = localCachedFileInfo?.isCurrentVersion(lastModifiedDateInCloud: itemMetadata.lastModifiedDate) ?? false
		let localURL = localCachedFileInfo?.localURL
		return FileProviderItem(metadata: itemMetadata, newestVersionLocallyCached: newestVersionLocallyCached, localURL: localURL, error: uploadTask?.failedWithError)
	}

	// MARK: Enumerate Item

	/**
	 Performs an enumeration on the item.

	 On a folder, this contains all items within that folder. If the `CloudProvider` supports it, only page enumeration is performed and a `pageToken` is returned.

	 If an enumeration is performed on a file, only its metadata is refreshed.

	 An enumeration on the `workingSet` always returns an empty `FileProviderItemList`.

	 This is because the contents of the working set are visible in the "Recents" tab of the Files app and could therefore also be visible when the vault is locked.

	 - Parameter identifier: The identifier of the item on which the enumeration is to be performed.
	 - Parameter pageToken: (Optional) The page token that was previously returned when this function was called with the same identifier.
	 - Precondition: The `ItemMetadata` associated with the `identifier` exists in the database.
	 - Precondition: The `itemType` of the `ItemMetadata` is either file or folder.
	 - Precondition: An authenticated `VaultDecorator` exists for the `vaultUID`.
	 - Returns: Depending on the type of item associated with the passed identifier, the following is returned:
	   - If the `identifier` is the `workingSet`: empty `FileProviderItemList`.
	   - If the `identifier` belongs to a folder: `FileProviderItemList` with children of the folder and if it was not a complete enumeration, i.e. there are more items in the folder, also a `nextPageToken`.
	   - If the `identifier` belongs to a file: `FileProviderItemList` with exactly one `FileProviderItem`, which corresponds to the `identifier`.
	 */
	public func enumerateItems(for identifier: NSFileProviderItemIdentifier, withPageToken pageToken: String?) -> Promise<FileProviderItemList> {
		// TODO: Check for internet connection here
		if identifier == .workingSet {
			return Promise(FileProviderItemList(items: [], nextPageToken: nil))
		}
		let enumerationTask: ItemEnumerationTask
		do {
			let id = try convertFileProviderItemIdentifierToInt64(identifier)
			guard let cachedItemMetadata = try itemMetadataManager.getCachedMetadata(for: id) else {
				return Promise(CloudProviderError.itemNotFound)
			}
			let itemMetadata = cachedItemMetadata
			enumerationTask = try itemEnumerationTaskManager.createTask(for: itemMetadata, pageToken: pageToken)
		} catch {
			return Promise(error)
		}
		let workflow = WorkflowFactory.createWorkflow(for: enumerationTask, provider: provider, itemMetadataManager: itemMetadataManager, cachedFileManager: cachedFileManager, reparentTaskManager: reparentTaskManager, uploadTaskManager: uploadTaskManager, deletionTaskManager: deletionTaskManager, itemEnumerationTaskManager: itemEnumerationTaskManager)
		return scheduler.schedule(workflow)
	}

	// MARK: UploadFile

	public func importDocument(at fileURL: URL, toParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
		DispatchQueue.main.async {
			autoreleasepool {
				let localItemImportResult: LocalItemImportResult
				do {
					localItemImportResult = try self.localItemImport(fileURL: fileURL, parentIdentifier: parentItemIdentifier)
				} catch let error as NSError {
					if error.domain == NSFileProviderErrorDomain, error.code == NSFileProviderError.filenameCollision.rawValue {
						DDLogInfo("FPExt: filenameCollision for: \(fileURL.lastPathComponent)")
						return completionHandler(nil, error)
					}
					return completionHandler(nil, NSFileProviderError(.noSuchItem))
				}
				completionHandler(localItemImportResult.item, nil)

				// Network Stuff
				self.uploadFile(taskRecord: localItemImportResult.uploadTaskRecord).then { item in
					self.notificator?.signalUpdate(for: item)
				}.catch { error in
					DDLogError("importDocument uploadFile failed: \(error)")
				}.always {}
			}
		}
	}

	func importDocument(at fileURL: URL, toParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier) -> Promise<NSFileProviderItem?> {
		return wrap { handler in
			self.importDocument(at: fileURL, toParentItemIdentifier: parentItemIdentifier, completionHandler: handler)
		}
	}

	/**
	 Imports a file locally.

	 If an error occurs while copying the file, the corresponding item will be removed from the database.
	 Because in this case the user will have to try importing the file again.

	 This import checks for local filename collisions via the CloudPath.
	 - Precondition: A file exists at the `fileURL`
	 - Precondition: There is not yet a local copy of the file located at the `fileURL`, i.e. the file is not yet in our document storage directory.
	 - Postcondition: The file was successfully copied to our document storage.
	 - Postcondition: A new `UploadTask` was created for the passed `item`.
	 - Postcondition: A `LocalCachedFileInfo` with the url of the copied file exists in the database and has as `correspondingItem` the `id` of the newly created `ItemMetadata` entry.
	 */
	func localItemImport(fileURL: URL, parentIdentifier: NSFileProviderItemIdentifier) throws -> LocalItemImportResult {
		let placeholderMetadata = try createPlaceholderItemForFile(for: fileURL, in: parentIdentifier)
		let itemIdentifier = convertIDToItemIdentifier(placeholderMetadata.id!)

		let localURL: URL
		do {
			guard let url = localURLProvider?.urlForItem(withPersistentIdentifier: itemIdentifier) else {
				throw NSFileProviderError(.noSuchItem)
			}
			localURL = url
			try copyItem(from: fileURL, to: localURL, itemMetadata: placeholderMetadata)
		} catch {
			// Remove the item from the database, because the local import failed and therefore the user has to start a new import.
			try itemMetadataManager.removeItemMetadata(with: placeholderMetadata.id!)
			throw error
		}

		// Register LocalURL in the DB
		try cachedFileManager.cacheLocalFileInfo(for: placeholderMetadata.id!, localURL: localURL, lastModifiedDate: nil)
		let item = FileProviderItem(metadata: placeholderMetadata, newestVersionLocallyCached: true, localURL: localURL)
		let uploadTaskRecord = try registerFileInUploadQueue(with: localURL, itemMetadata: placeholderMetadata)
		return LocalItemImportResult(item: item, uploadTaskRecord: uploadTaskRecord)
	}

	func copyItem(from sourceURL: URL, to targetURL: URL, itemMetadata: ItemMetadata) throws {
		let fileCoordinator = NSFileCoordinator()
		let stopAccess = sourceURL.startAccessingSecurityScopedResource()
		var fileManagerError: NSError?
		var fileCoordinatorError: NSError?
		fileCoordinator.coordinate(readingItemAt: sourceURL, options: .withoutChanges, error: &fileCoordinatorError) { _ in
			do {
				try FileManager.default.createDirectory(at: targetURL.deletingLastPathComponent(), withIntermediateDirectories: true)
				try FileManager.default.copyItem(at: sourceURL, to: targetURL)
			} catch let error as NSError {
				fileManagerError = error as NSError
			}
		}
		if stopAccess {
			sourceURL.stopAccessingSecurityScopedResource()
		}
		if let error = fileManagerError ?? fileCoordinatorError {
			throw error
		}
	}

	/**
	 Tells the File Provider adapter that a document has changed.

	 */
	public func itemChanged(at url: URL) {
		guard let itemIdentifier = persistentIdentifierForItem(at: url) else {
			DDLogError("itemChanged - no persistentIdentifier for item at url: \(url)")
			return
		}
		let uploadTaskRecord: UploadTaskRecord
		do {
			let itemMetadata = try getCachedMetadata(for: itemIdentifier)
			uploadTaskRecord = try registerFileInUploadQueue(with: url, itemMetadata: itemMetadata)
		} catch {
			DDLogError("itemChanged - failed to register file in upload queue with url: \(url) and identifier: \(itemIdentifier)")
			return
		}
		uploadFile(taskRecord: uploadTaskRecord).then { item in
			self.notificator?.signalUpdate(for: item)
		}
	}

	func uploadFile(taskRecord: UploadTaskRecord) -> Promise<FileProviderItem> {
		let workflow: Workflow<FileProviderItem>
		do {
			let task = try uploadTaskManager.getTask(for: taskRecord)
			workflow = WorkflowFactory.createWorkflow(for: task, provider: provider, itemMetadataManager: itemMetadataManager, cachedFileManager: cachedFileManager, uploadTaskManager: uploadTaskManager)
		} catch {
			return Promise(error)
		}
		return scheduler.schedule(workflow)
	}

	func registerFileInUploadQueue(with localURL: URL, itemMetadata: ItemMetadata) throws -> UploadTaskRecord {
		precondition(localURL.isFileURL)
		precondition(itemMetadata.type == .file)

		itemMetadata.statusCode = ItemStatus.isUploading
		let uploadTaskRecord: UploadTaskRecord
		do {
			let attributes = try FileManager.default.attributesOfItem(atPath: localURL.path)
			let lastModifiedDate = attributes[FileAttributeKey.modificationDate] as? Date
			try itemMetadataManager.updateMetadata(itemMetadata)
			try uploadTaskManager.removeTaskRecord(for: itemMetadata)
			uploadTaskRecord = try uploadTaskManager.createNewTaskRecord(for: itemMetadata)
			try cachedFileManager.cacheLocalFileInfo(for: itemMetadata.id!, localURL: localURL, lastModifiedDate: lastModifiedDate)
		} catch {
			DDLogError("Register file in upload queue failed with error: \(error)")
			throw NSFileProviderError(.noSuchItem)
		}
		return uploadTaskRecord
	}

	// MARK: Create Directory

	public func createDirectory(withName directoryName: String, inParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
		let placeholderItem: FileProviderItem
		do {
			placeholderItem = try createPlaceholderItemForFolder(withName: directoryName, in: parentItemIdentifier)
		} catch {
			return completionHandler(nil, error)
		}
		completionHandler(placeholderItem, nil)
		let task = FolderCreationTask(itemMetadata: placeholderItem.metadata)
		let workflow = WorkflowFactory.createWorkflow(for: task, provider: provider, itemMetadataManager: itemMetadataManager)
		scheduler.schedule(workflow).then { item in
			self.notificator?.signalUpdate(for: item)
		}
	}

	// MARK: Move Item

	public func renameItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toName itemName: String, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
		let result: MoveItemLocallyResult
		do {
			result = try moveItemLocally(withIdentifier: itemIdentifier, toParentItemWithIdentifier: nil, newName: itemName)
		} catch {
			return completionHandler(nil, error)
		}

		let reparentTask: ReparentTask
		do {
			reparentTask = try reparentTaskManager.getTask(for: result.reparentTaskRecord)
		} catch {
			return completionHandler(nil, error)
		}
		completionHandler(result.item, nil)
		let workflow = WorkflowFactory.createWorkflow(for: reparentTask, provider: provider, itemMetadataManager: itemMetadataManager, cachedFileManager: cachedFileManager, reparentTaskManager: reparentTaskManager)
		scheduler.schedule(workflow).then { item in
			self.notificator?.signalUpdate(for: item)
		}
	}

	public func reparentItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toParentItemWithIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, newName: String?, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
		let result: MoveItemLocallyResult
		do {
			result = try moveItemLocally(withIdentifier: itemIdentifier, toParentItemWithIdentifier: parentItemIdentifier, newName: newName)
		} catch {
			return completionHandler(nil, error)
		}

		let reparentTask: ReparentTask
		do {
			reparentTask = try reparentTaskManager.getTask(for: result.reparentTaskRecord)
		} catch {
			return completionHandler(nil, error)
		}
		completionHandler(result.item, nil)
		let workflow = WorkflowFactory.createWorkflow(for: reparentTask, provider: provider, itemMetadataManager: itemMetadataManager, cachedFileManager: cachedFileManager, reparentTaskManager: reparentTaskManager)
		scheduler.schedule(workflow).then { item in
			self.notificator?.signalUpdate(for: item)
		}
	}

	/**
	 Moves the item only locally.

	 The move only takes place in the database and the file is not moved or renamed on the local file system.

	 This ensures that previously triggered uploads, that are currently pending, do not use the wrong local URL.

	 In addition, the exact name of the item via the local URL is not further relevant (for us), since we determine the names of the items via the database.

	 - Precondition: The metadata associated with the `itemIdentifier` is stored in the database.
	 - Precondition: `parentItemIdentifier != nil || newName != nil`.
	 - Postcondition: `newName != nil` implies that the `ItemMetadata` entry in the database has the `name == newName`.
	 - Postcondition: `parentItemIdentifier != nil` implies that now the `ItemMetadata` entry in the database has the `parentID == parentItemIdentifier`.
	 - Postcondition: A `ReparentTask` was created for the passed `itemIdentifier`.
	 */
	func moveItemLocally(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toParentItemWithIdentifier parentItemIdentifier: NSFileProviderItemIdentifier?, newName: String?) throws -> MoveItemLocallyResult {
		precondition(parentItemIdentifier != nil || newName != nil)
		let itemMetadata = try getCachedMetadata(for: itemIdentifier)
		let parentID: Int64
		if let parentItemIdentifier = parentItemIdentifier {
			parentID = try convertFileProviderItemIdentifierToInt64(parentItemIdentifier)
		} else {
			parentID = itemMetadata.parentID
		}
		let name: String
		if let newName = newName {
			name = newName
		} else {
			name = itemMetadata.name
		}

		let cloudPath = try getCloudPathForPlaceholderItem(withName: name, in: parentID, type: itemMetadata.type)
		try checkLocalItemCollision(for: cloudPath)
		let taskRecord = try reparentTaskManager.createTaskRecord(for: itemMetadata, targetCloudPath: cloudPath, newParentID: parentID)

		itemMetadata.name = name
		itemMetadata.cloudPath = cloudPath
		itemMetadata.parentID = parentID
		itemMetadata.statusCode = .isUploading
		try itemMetadataManager.updateMetadata(itemMetadata)

		let localCachedFileInfo = try cachedFileManager.getLocalCachedFileInfo(for: itemMetadata)
		let newestVersionLocallyCached = localCachedFileInfo?.isCurrentVersion(lastModifiedDateInCloud: itemMetadata.lastModifiedDate) ?? false
		let item = FileProviderItem(metadata: itemMetadata, newestVersionLocallyCached: newestVersionLocallyCached)
		return MoveItemLocallyResult(item: item, reparentTaskRecord: taskRecord)
	}

	// MARK: Delete Item

	public func deleteItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (Error?) -> Void) {
		let taskRecord: DeletionTaskRecord
		do {
			taskRecord = try deleteItemLocally(withIdentifier: itemIdentifier)
		} catch let error as NSError {
			if error.domain == NSFileProviderErrorDomain, error.code == NSFileProviderError.noSuchItem.rawValue {
				DDLogInfo("Delete Item called for nonexistent item")
				completionHandler(nil)
				return
			}
			completionHandler(error)
			return
		}
		let workflow: Workflow<Void>
		do {
			let deletionTaskInfo = try deletionTaskManager.getTask(for: taskRecord)
			workflow = WorkflowFactory.createWorkflow(for: deletionTaskInfo, provider: provider, itemMetadataManager: itemMetadataManager)
		} catch {
			completionHandler(error)
			return
		}
		completionHandler(nil)
		scheduler.schedule(workflow).then {
			DDLogVerbose("DeleteItem success")
		}
	}

	/**
	 Deletes the item locally.

	 Deletes the corresponding `ItemMetadata` entry and all child items from the database and if the respective item was cached locally also from the local file system.

	 If there is no `ItemMetadata` entry for the passed `itemIdentifier` in the database, no error will be thrown.

	 This ensures that this item will be removed from the UI of the Files app anyway.

	 - Postcondition: A `DeletionTask` was created for the passed `itemIdentifier`.
	 - Postcondition: The `ItemMetadata` entry for the passed `itemIdentifier` and all `ItemMetadata` entries that have this entry as implicit parent were removed from the database and the associated locally cached files were removed from the file system.
	 */
	func deleteItemLocally(withIdentifier itemIdentifier: NSFileProviderItemIdentifier) throws -> DeletionTaskRecord {
		let itemMetadata = try getCachedMetadata(for: itemIdentifier)
		let deletionHelper = DeleteItemHelper(itemMetadataManager: itemMetadataManager, cachedFileManager: cachedFileManager)
		try deletionHelper.removeItemFromCache(itemMetadata)
		let taskRecord = try deletionTaskManager.createTaskRecord(for: itemMetadata)
		return taskRecord
	}

	// MARK: Start Providing Item

	public func startProvidingItem(at url: URL, completionHandler: @escaping ((_ error: Error?) -> Void)) {
		startProvidingItem(at: url).then {
			completionHandler(nil)
		}.catch { error in
			completionHandler(error)
		}
	}

	func startProvidingItem(at url: URL) -> Promise<Void> {
		guard let identifier = persistentIdentifierForItem(at: url) else {
			return Promise(NSFileProviderError(.noSuchItem))
		}
		if FileManager.default.fileExists(atPath: url.path) {
			return localFileIsCurrent(with: identifier).then { isCurrent in
				if isCurrent {
					return Promise(())
				} else {
					return self.startProvidingItemWithOutdatedLocalFile(identifier: identifier, url: url)
				}
			}
		} else {
			return downloadFile(with: identifier, to: url)
		}
	}

	func startProvidingItemWithOutdatedLocalFile(identifier: NSFileProviderItemIdentifier, url: URL) -> Promise<Void> {
		let hasVersioningConflict: Bool
		do {
			hasVersioningConflict = try hasPossibleVersioningConflictForItem(withIdentifier: identifier)
		} catch {
			return Promise(error)
		}
		if hasVersioningConflict {
			return startProvidingItemWithVersioningConflict(identifier: identifier, url: url)
		} else {
			return downloadFile(with: identifier, to: url, replaceExisting: true)
		}
	}

	func startProvidingItemWithVersioningConflict(identifier: NSFileProviderItemIdentifier, url: URL) -> Promise<Void> {
		let tmpDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		let tmpFileURL = tmpDirectory.appendingPathComponent(url.lastPathComponent).createCollisionURL()
		let parentItemIdentifier: NSFileProviderItemIdentifier
		do {
			try FileManager.default.createDirectory(at: tmpDirectory, withIntermediateDirectories: false, attributes: nil)
			try FileManager.default.moveItem(at: url, to: tmpFileURL)
			parentItemIdentifier = try item(for: identifier).parentItemIdentifier
		} catch {
			return Promise(error)
		}
		return wrap { handler in
			self.importDocument(at: tmpFileURL, toParentItemIdentifier: parentItemIdentifier, completionHandler: handler)
		}.then { _ in
			try FileManager.default.removeItem(at: tmpDirectory)
			let itemID = try self.convertFileProviderItemIdentifierToInt64(identifier)
			try self.uploadTaskManager.removeTaskRecord(for: itemID)
			return self.downloadFile(with: identifier, to: url, replaceExisting: false)
		}
	}

	/**
	 Checks if an item has a possible versioning conflict.

	 A possible version conflict between the local file and the file in the cloud can occur if the changes to the local file have not yet been synchronized to the cloud due to an upload error and the file in the cloud has also been changed.

	 A possible conflict can also occur if the file is being uploaded and could be overwritten due to an immediate download.

	 - Precondition: `itemIdentifier.rawValue` can be cast to a positive `Int64` value.
	 - Precondition: The metadata associated with the `itemIdentifier` is stored in the database.
	 */
	func hasPossibleVersioningConflictForItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier) throws -> Bool {
		let id = try convertFileProviderItemIdentifierToInt64(itemIdentifier)
		guard let uploadTask = try uploadTaskManager.getTaskRecord(for: id) else {
			return false
		}
		let cachedLocalFileInfo = try cachedFileManager.getLocalCachedFileInfo(for: id)
		guard let localLastModifiedDate = cachedLocalFileInfo?.localLastModifiedDate else {
			return false
		}
		guard let lastFailedUploadDate = uploadTask.lastFailedUploadDate else {
			return true
		}
		return lastFailedUploadDate > localLastModifiedDate
	}

	/**
	 Checks if the local file is still up-to-date compared to the file in the cloud.

	 For performance reasons, it should be ensured, before the call, that the local file exists for which this check is performed.

	 Only the change of the `lastModifiedDate` in the cloud is checked.

	 If a cloud shows inconsistency here (e.g., change of the file without change of the `lastModifiedDate`), this is not taken into account, although it might be possible with an additional comparison of the file size.

	 - Returns:
	   - `true` if the local file is still guaranteed to be the current one or we have no internet connection.
	   - `false` if the file in the cloud is a newer version or the cloud did not return a `lastModifiedDate` or there is no `localCachedFileInfo` for the passed `identifier`.
	 */
	func localFileIsCurrent(with identifier: NSFileProviderItemIdentifier) -> Promise<Bool> {
		let itemMetadata: ItemMetadata
		do {
			itemMetadata = try getCachedMetadata(for: identifier)
		} catch {
			return Promise(error)
		}
		if itemMetadata.statusCode == .isUploading {
			return Promise(true)
		}
		return enumerateItems(for: identifier, withPageToken: nil).then { itemList -> Bool in
			guard let item = itemList.items.first else {
				throw NSFileProviderError(.noSuchItem)
			}
			let itemMetadata = item.metadata
			guard let lastModifiedDateInCloud = itemMetadata.lastModifiedDate else {
				return false
			}
			let localCachedFileInfo = try self.cachedFileManager.getLocalCachedFileInfo(for: itemMetadata)
			let newestVersionLocallyCached = localCachedFileInfo?.isCurrentVersion(lastModifiedDateInCloud: lastModifiedDateInCloud) ?? false
			return newestVersionLocallyCached
		}
	}

	func downloadFile(with identifier: NSFileProviderItemIdentifier, to localURL: URL, replaceExisting: Bool = false) -> Promise<Void> {
		let task: DownloadTask
		do {
			let itemMetadata = try getCachedMetadata(for: identifier)
			task = try downloadTaskManager.createTask(for: itemMetadata, replaceExisting: replaceExisting, localURL: localURL)
		} catch {
			return Promise(error)
		}
		let workflow = WorkflowFactory.createWorkflow(for: task, provider: provider, itemMetadataManager: itemMetadataManager, cachedFileManager: cachedFileManager, downloadTaskManager: downloadTaskManager)
		return scheduler.schedule(workflow).then { item -> Void in
			self.notificator?.signalUpdate(for: item)
		}
	}

	// MARK: Stop Providing Item

	public func stopProvidingItem(at url: URL) {
		#warning("TODO: Implement stopProvidingItem logic")
	}

	// MARK: Placeholder

	/**
	 Creates a placeholder item for a file.

	 - Precondition: A file exists at the passed `localURL`.
	 - Precondition: The database does not yet contain an `ItemMetadata` entry for this file.
	 - Postcondition: An `ItemMetadata` entry exists in the database with the attributes of the local file, `isPlaceholderItem == true` and `statusCode == .isUploading`.
	 - Postcondition: A `LocalCachedFileInfo` with the `localURL` exists in the database and has as `correspondingItem` the `id` of the newly created `ItemMetadata` entry.
	 - Postcondition: The returned `FileProviderItem` has `newestVersionLocallyCached == true` and the passed `localURL` of the file.
	 */
	func createPlaceholderItemForFile(for localURL: URL, in parentIdentifier: NSFileProviderItemIdentifier) throws -> ItemMetadata {
		let parentID = try convertFileProviderItemIdentifierToInt64(parentIdentifier)
		let attributes = try FileManager.default.attributesOfItem(atPath: localURL.path)
		let size = attributes[FileAttributeKey.size] as? Int
		let typeFile = attributes[FileAttributeKey.type] as? FileAttributeType
		let lastModifiedDate = attributes[FileAttributeKey.modificationDate] as? Date
		if typeFile == FileAttributeType.typeDirectory {
			throw FileProviderAdapterError.folderUploadNotSupported
		}
		let cloudPath = try getCloudPathForPlaceholderItem(withName: localURL.lastPathComponent, in: parentID, type: .file)
		try checkLocalItemCollision(for: cloudPath)
		let placeholderMetadata = ItemMetadata(name: localURL.lastPathComponent, type: .file, size: size, parentID: parentID, lastModifiedDate: lastModifiedDate, statusCode: .isUploading, cloudPath: cloudPath, isPlaceholderItem: true)
		try itemMetadataManager.cacheMetadata(placeholderMetadata)
		return placeholderMetadata
	}

	/**
	 Creates a placeholder item for a folder.

	 - Precondition: The database does not yet contain an `ItemMetadata` entry for this folder.
	 - Postcondition: An `ItemMetadata` entry exists in the database with `isPlaceholderItem == true` and `statusCode == .isUploading`.
	 - Postcondition: The returned `FileProviderItem` has `newestVersionLocallyCached == true`.
	 */
	func createPlaceholderItemForFolder(withName name: String, in parentIdentifier: NSFileProviderItemIdentifier) throws -> FileProviderItem {
		let parentID = try convertFileProviderItemIdentifierToInt64(parentIdentifier)
		let cloudPath = try getCloudPathForPlaceholderItem(withName: name, in: parentID, type: .folder)
		try checkLocalItemCollision(for: cloudPath)
		let placeholderMetadata = ItemMetadata(name: name, type: .folder, size: nil, parentID: parentID, lastModifiedDate: nil, statusCode: .isUploading, cloudPath: cloudPath, isPlaceholderItem: true)
		try itemMetadataManager.cacheMetadata(placeholderMetadata)
		return FileProviderItem(metadata: placeholderMetadata, newestVersionLocallyCached: true)
	}

	/**
	 Gets the cloud path based on the item name and parent id.

	 - Precondition: The passed `parentID` must belong to an item with the type `.folder`.
	 */
	func getCloudPathForPlaceholderItem(withName name: String, in parentID: Int64, type: CloudItemType) throws -> CloudPath {
		guard let parentItemMetadata = try itemMetadataManager.getCachedMetadata(for: parentID), parentItemMetadata.type == .folder else {
			throw FileProviderAdapterError.parentFolderNotFound
		}
		let parentCloudPath = parentItemMetadata.cloudPath
		let cloudPath = parentCloudPath.appendingPathComponent(name)
		return cloudPath
	}

	/**
	 Checks if there is a local item collision.

	 A local item collision occurs if there is already an item in the DB that has the passed `path` as path and there is no existing `DeleteItemTask` for this item.
	 Because in case of an existing `DeleteItemTask`, there is no conflict as the item can be considered as deleted.
	 */
	func checkLocalItemCollision(for path: CloudPath) throws {
		if let existingItemMetadata = try itemMetadataManager.getCachedMetadata(for: path) {
			do {
				_ = try deletionTaskManager.getTaskRecord(for: existingItemMetadata.id!)
			} catch DBManagerError.taskNotFound {
				throw NSError.fileProviderErrorForCollision(with: FileProviderItem(metadata: existingItemMetadata))
			}
		}
	}

	// MARK: Internal

	func getCachedMetadata(for identifier: NSFileProviderItemIdentifier) throws -> ItemMetadata {
		let id = try convertFileProviderItemIdentifierToInt64(identifier)
		guard let itemMetadata = try itemMetadataManager.getCachedMetadata(for: id) else {
			throw NSFileProviderError(.noSuchItem)
		}
		return itemMetadata
	}

	func convertFileProviderItemIdentifierToInt64(_ identifier: NSFileProviderItemIdentifier) throws -> Int64 {
		switch identifier {
		case .rootContainer:
			return itemMetadataManager.getRootContainerID()
		default:
			guard let id = Int64(identifier.rawValue) else {
				throw FileProviderAdapterError.unsupportedItemIdentifier
			}
			return id
		}
	}

	func convertIDToItemIdentifier(_ id: Int64) -> NSFileProviderItemIdentifier {
		if id == itemMetadataManager.getRootContainerID() {
			return .rootContainer
		}
		return NSFileProviderItemIdentifier("\(id)")
	}

	struct LocalItemImportResult {
		let item: FileProviderItem
		let uploadTaskRecord: UploadTaskRecord
	}

	struct MoveItemLocallyResult {
		let item: FileProviderItem
		let reparentTaskRecord: ReparentTaskRecord
	}
}

public protocol LocalURLProvider: AnyObject {
	func urlForItem(withPersistentIdentifier identifier: NSFileProviderItemIdentifier) -> URL?
}
