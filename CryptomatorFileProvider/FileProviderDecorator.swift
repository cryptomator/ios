//
//  FileProviderDecorator.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 24.06.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CloudAccessPrivateCore
import CryptomatorCloudAccess
import FileProvider
import Foundation
import GRDB
import Promises

public class FileProviderDecorator {
	// Needed to mock the class
	private let internalProvider: CloudProvider
//	private let mock = CloudProviderMock()
	var provider: CloudProvider {
		return internalProvider
//		return mock
	}

	private let uploadQueue: DispatchQueue
	private let downloadQueue: DispatchQueue
	private let uploadSemaphore = DispatchSemaphore(value: 1)
	let itemMetadataManager: MetadataManager
	let cachedFileManager: CachedFileManager
	let uploadTaskManager: UploadTaskManager
	let reparentTaskManager: ReparentTaskManager
	let deletionTaskManager: DeletionTaskManager
	public let notificator: FileProviderNotificator
	let domain: NSFileProviderDomain
	let manager: NSFileProviderManager
	let demoRoot: URL
	public init(for domain: NSFileProviderDomain, with manager: NSFileProviderManager, dbPath: URL) throws {
		self.uploadQueue = DispatchQueue(label: "FileProviderDecorator-Upload", qos: .userInitiated)
		self.downloadQueue = DispatchQueue(label: "FileProviderDecorator-Download", qos: .userInitiated)
		// TODO: Real SetUp with CryptoDecorator, PersistentDBQueue, DBMigrator, etc.

		self.demoRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: demoRoot, withIntermediateDirectories: true, attributes: nil)
		self.internalProvider = LocalFileSystemProvider(rootURL: demoRoot)
		let database = try DataBaseHelper.getDBMigratedQueue(at: dbPath.path)
		self.notificator = FileProviderNotificator(manager: manager)
		self.itemMetadataManager = MetadataManager(with: database)
		self.cachedFileManager = CachedFileManager(with: database)
		self.uploadTaskManager = UploadTaskManager(with: database)
		self.reparentTaskManager = try ReparentTaskManager(with: database)
		self.deletionTaskManager = try DeletionTaskManager(with: database)
		self.domain = domain
		self.manager = manager

		// MARK: Demo Content for FileProviderExtension

		let testContent = "Demo File Content"
		for i in 0 ... 5 {
			try FileManager.default.createDirectory(at: demoRoot.appendingPathComponent("Folder \(i)", isDirectory: true), withIntermediateDirectories: true, attributes: nil)
			try testContent.write(to: demoRoot.appendingPathComponent("File \(i).txt", isDirectory: false), atomically: true, encoding: .utf8)
		}
	}

	// CleanUp Demo Content
	deinit {
		try? FileManager.default.removeItem(at: demoRoot)
	}

	public func fetchItemList(for folderIdentifier: NSFileProviderItemIdentifier, withPageToken pageToken: String?) -> Promise<FileProviderItemList> {
		// TODO: Check for Internet Connection here

		let parentId: Int64
		let cloudPath: CloudPath
		do {
			parentId = try convertFileProviderItemIdentifierToInt64(folderIdentifier)
			guard let metadata = try itemMetadataManager.getCachedMetadata(for: parentId) else {
				return Promise(CloudProviderError.itemNotFound)
			}
			cloudPath = metadata.cloudPath
		} catch {
			return Promise(error)
		}
		return provider.fetchItemList(forFolderAt: cloudPath, withPageToken: pageToken).then { itemList -> FileProviderItemList in
			if pageToken == nil {
				try self.itemMetadataManager.flagAllItemsAsMaybeOutdated(insideParentId: parentId)
			}

			var metadatas = [ItemMetadata]()
			for cloudItem in itemList.items {
				let fileProviderItemMetadata = self.createItemMetadata(for: cloudItem, withParentId: parentId)
				metadatas.append(fileProviderItemMetadata)
			}
			metadatas = try self.filterOutWaitingReparentTasks(parentId: parentId, for: metadatas)
			metadatas = try self.filterOutWaitingDeletionTasks(parentId: parentId, for: metadatas)
			try self.itemMetadataManager.cacheMetadatas(metadatas)
			let reparentMetadata = try self.getReparentMetadata(for: parentId)
			metadatas.append(contentsOf: reparentMetadata)
			let placeholderMetadatas = try self.itemMetadataManager.getPlaceholderMetadata(for: parentId)
			metadatas.append(contentsOf: placeholderMetadatas)
			let ids = metadatas.map { return $0.id! }
			let uploadTasks = try self.uploadTaskManager.getCorrespondingTasks(ids: ids)
			assert(metadatas.count == uploadTasks.count)
			let items = try metadatas.enumerated().map { index, metadata -> FileProviderItem in
				let newestVersionLocallyCached = try self.cachedFileManager.hasCurrentVersionLocal(for: metadata.id!, with: metadata.lastModifiedDate)
				return FileProviderItem(metadata: metadata, newestVersionLocallyCached: newestVersionLocallyCached, error: uploadTasks[index]?.error)
			}
			if let nextPageTokenData = itemList.nextPageToken?.data(using: .utf8) {
				return FileProviderItemList(items: items, nextPageToken: NSFileProviderPage(nextPageTokenData))
			}
			try self.cleanUpNoLongerInTheCloudExistingItems(insideParentId: parentId)
			return FileProviderItemList(items: items, nextPageToken: nil)
		}
	}

	func getReparentMetadata(for parentId: Int64) throws -> [ItemMetadata] {
		let reparentTasks = try reparentTaskManager.getTasksForItemsWhichAreSoon(in: parentId)
		let reparentMetadata = try itemMetadataManager.getCachedMetadata(forIds: reparentTasks.map { $0.correspondingItem })
		return reparentMetadata
	}

	func filterOutWaitingReparentTasks(parentId: Int64, for itemMetadatas: [ItemMetadata]) throws -> [ItemMetadata] {
		let runningReparentTasks = try reparentTaskManager.getTasksForItemsWhichWere(in: parentId)
		return itemMetadatas.filter { element in
			!runningReparentTasks.contains { $0.sourceCloudPath == element.cloudPath }
		}
	}

	func filterOutWaitingDeletionTasks(parentId: Int64, for itemMetadata: [ItemMetadata]) throws -> [ItemMetadata] {
		let runningDeletionTasks = try deletionTaskManager.getTasksForItemsWhichWere(in: parentId)
		return itemMetadata.filter { element in
			!runningDeletionTasks.contains { $0.cloudPath == element.cloudPath }
		}
	}

	func createItemMetadata(for item: CloudItemMetadata, withParentId parentId: Int64, isPlaceholderItem: Bool = false) -> ItemMetadata {
		let metadata = ItemMetadata(name: item.name, type: item.itemType, size: item.size, parentId: parentId, lastModifiedDate: item.lastModifiedDate, statusCode: .isUploaded, cloudPath: item.cloudPath, isPlaceholderItem: isPlaceholderItem)
		return metadata
	}

	func convertFileProviderItemIdentifierToInt64(_ identifier: NSFileProviderItemIdentifier) throws -> Int64 {
		switch identifier {
		case .rootContainer:
			return MetadataManager.rootContainerId
		default:
			guard let id = Int64(identifier.rawValue) else {
				throw FileProviderDecoratorError.unsupportedItemIdentifier
			}
			return id
		}
	}

	public func getFileProviderItem(for identifier: NSFileProviderItemIdentifier) throws -> FileProviderItem {
		let itemMetadata = try getCachedMetadata(for: identifier)
		let uploadTask = try uploadTaskManager.getTask(for: itemMetadata.id!)
		let newestVersionLocallyCached = try cachedFileManager.hasCurrentVersionLocal(for: itemMetadata.id!, with: itemMetadata.lastModifiedDate)
		return FileProviderItem(metadata: itemMetadata, newestVersionLocallyCached: newestVersionLocallyCached, error: uploadTask?.error)
	}

	func getCachedMetadata(for identifier: NSFileProviderItemIdentifier) throws -> ItemMetadata {
		let id = try convertFileProviderItemIdentifierToInt64(identifier)
		guard let itemMetadata = try itemMetadataManager.getCachedMetadata(for: id) else {
			throw NSFileProviderError(.noSuchItem)
		}
		return itemMetadata
	}

	public func localFileIsCurrent(with identifier: NSFileProviderItemIdentifier) -> Promise<Bool> {
		let metadata: ItemMetadata
		do {
			metadata = try getCachedMetadata(for: identifier)
		} catch {
			return Promise(error)
		}
		if metadata.statusCode == .isUploading {
			return Promise(true)
		}

		let cloudPath = metadata.cloudPath

		return provider.fetchItemMetadata(at: cloudPath).then { cloudMetadata -> Bool in
			guard let lastModifiedDateInCloud = cloudMetadata.lastModifiedDate else {
				return false
			}
			return try self.cachedFileManager.hasCurrentVersionLocal(for: metadata.id!, with: lastModifiedDateInCloud)
		}.recover { error -> Bool in
			if case CloudProviderError.noInternetConnection = error {
				return true
			}
			return false
		}
	}

	/**
	 - Precondition: `localURL` must be a file URL
	 - Precondition: `localURL` must point to a file
	 - Precondition: The ItemMetadata associated with the `identifier` exists in the DB.
	 - Postcondition: The ItemMetadata associated with the `identifier` has the status `.isDownloaded` and the associated localCachedEntry has the `lastModifiedDate` of the item downloaded from the cloud and both were stored in the DB.
	 */
	public func downloadFile(with identifier: NSFileProviderItemIdentifier, to localURL: URL) -> Promise<Void> {
		let metadata: ItemMetadata
		do {
			metadata = try getCachedMetadata(for: identifier)
		} catch {
			return Promise(error)
		}
		var lastModifiedDate: Date?
		let cloudPath = metadata.cloudPath
		return provider.fetchItemMetadata(at: cloudPath).then { cloudMetadata -> Promise<Void> in
			lastModifiedDate = cloudMetadata.lastModifiedDate
			let progress = Progress.discreteProgress(totalUnitCount: 1)
			let task = FileProviderNetworkTask(with: progress)
			self.manager.register(task, forItemWithIdentifier: NSFileProviderItemIdentifier(String(metadata.id!))) { error in
				if let error = error {
					print("Register Task Error: \(error)")
				}
			}
			progress.becomeCurrent(withPendingUnitCount: 1)
			return self.provider.downloadFile(from: cloudPath, to: localURL).then {
				progress.resignCurrent()
			}
		}.then {
			metadata.statusCode = .isDownloaded
			try self.itemMetadataManager.updateMetadata(metadata)
			try self.cachedFileManager.cacheLocalFileInfo(for: metadata.id!, lastModifiedDate: lastModifiedDate)
		}.recover { error -> Promise<Void> in
			metadata.statusCode = .downloadError
			try self.itemMetadataManager.updateMetadata(metadata)
			if let cloudProviderError = error as? CloudProviderError {
				return Promise(self.mapCloudProviderErrorToNSFileProviderError(cloudProviderError))
			}
			return Promise(error)
		}
	}

	public func createPlaceholderItemForFile(for localURL: URL, in parentIdentifier: NSFileProviderItemIdentifier) throws -> FileProviderItem {
		let parentId = try convertFileProviderItemIdentifierToInt64(parentIdentifier)
		let attributes = try FileManager.default.attributesOfItem(atPath: localURL.path)
		let size = attributes[FileAttributeKey.size] as? Int
		let typeFile = attributes[FileAttributeKey.type] as? FileAttributeType
		let lastModifiedDate = attributes[FileAttributeKey.modificationDate] as? Date
		if typeFile == FileAttributeType.typeDirectory {
			throw FileProviderDecoratorError.folderUploadNotSupported
		}
		let cloudPath = try getCloudPathForPlaceholderItem(withName: localURL.lastPathComponent, in: parentId, type: .file)
		let placeholderMetadata = ItemMetadata(name: localURL.lastPathComponent, type: .file, size: size, parentId: parentId, lastModifiedDate: lastModifiedDate, statusCode: .isUploading, cloudPath: cloudPath, isPlaceholderItem: true)
		try itemMetadataManager.cacheMetadata(placeholderMetadata)
		try cachedFileManager.cacheLocalFileInfo(for: placeholderMetadata.id!, lastModifiedDate: lastModifiedDate)
		return FileProviderItem(metadata: placeholderMetadata, newestVersionLocallyCached: true)
	}

	public func createPlaceholderItemForFolder(withName name: String, in parentIdentifier: NSFileProviderItemIdentifier) throws -> FileProviderItem {
		let parentId = try convertFileProviderItemIdentifierToInt64(parentIdentifier)
		let cloudPath = try getCloudPathForPlaceholderItem(withName: name, in: parentId, type: .folder)
		let placeholderMetadata = ItemMetadata(name: name, type: .folder, size: nil, parentId: parentId, lastModifiedDate: nil, statusCode: .isUploading, cloudPath: cloudPath, isPlaceholderItem: true)
		try itemMetadataManager.cacheMetadata(placeholderMetadata)
		return FileProviderItem(metadata: placeholderMetadata, newestVersionLocallyCached: true)
	}

	func getCloudPathForPlaceholderItem(withName name: String, in parentId: Int64, type: CloudItemType) throws -> CloudPath {
		guard let parentItemMetadata = try itemMetadataManager.getCachedMetadata(for: parentId), parentItemMetadata.type == .folder else {
			throw FileProviderDecoratorError.parentFolderNotFound
		}
		// TODO: Remove homeRoot <-- only for demo purpose with LocalFileSystemProvider
		let parentCloudPath = parentItemMetadata.cloudPath
		let cloudPath = parentCloudPath.appendingPathComponent(name)

		if let existingItemMetadata = try itemMetadataManager.getCachedMetadata(for: cloudPath) {
			throw NSError.fileProviderErrorForCollision(with: FileProviderItem(metadata: existingItemMetadata))
//			DEBUG:
//			throw CloudProviderError.noInternetConnection
		}
		return cloudPath
	}

	// MARK: UploadFile

	public func reportLocalUploadError(for identifier: NSFileProviderItemIdentifier, error: NSError) throws {
		let itemMetadata = try getCachedMetadata(for: identifier)
		var uploadTask = try uploadTaskManager.createNewTask(for: itemMetadata.id!)
		try uploadTaskManager.updateTask(&uploadTask, error: error)

		itemMetadata.statusCode = .uploadError
		try itemMetadataManager.updateMetadata(itemMetadata)
	}

	public func uploadFile(with localURL: URL, itemMetadata: ItemMetadata) -> Promise<FileProviderItem> {
		return uploadFileWithoutRecover(from: localURL, itemMetadata: itemMetadata).recover { error -> Promise<FileProviderItem> in
			guard itemMetadata.isPlaceholderItem, case CloudProviderError.itemAlreadyExists = error else {
				let errorItem = self.reportErrorWithFileProviderItem(error: error as NSError, itemMetadata: itemMetadata)
				return Promise(errorItem)
			}
			return self.collisionHandlingUpload(from: localURL, itemMetadata: itemMetadata)
		}
	}

	func cloudFileNameCollisionHandling(for localURL: URL, with collisionFreeLocalURL: URL, itemMetadata: ItemMetadata) throws {
		let filename = collisionFreeLocalURL.lastPathComponent
		itemMetadata.name = filename
		itemMetadata.cloudPath = itemMetadata.cloudPath.deletingLastPathComponent().appendingPathComponent(filename)
		try FileManager.default.moveItem(at: localURL, to: collisionFreeLocalURL)
		try itemMetadataManager.updateMetadata(itemMetadata)
	}

	func collisionHandlingUpload(from localURL: URL, itemMetadata: ItemMetadata) -> Promise<FileProviderItem> {
		let collisionFreeLocalURL = localURL.createCollisionURL()
		do {
			try cloudFileNameCollisionHandling(for: localURL, with: collisionFreeLocalURL, itemMetadata: itemMetadata)
		} catch {
			return Promise(error)
		}

		return uploadFileWithoutRecover(from: collisionFreeLocalURL, itemMetadata: itemMetadata).recover { error -> FileProviderItem in
			let errorToReport: NSError
			if let cloudProviderError = error as? CloudProviderError {
				errorToReport = self.mapCloudProviderErrorToNSFileProviderError(cloudProviderError) as NSError
			} else {
				errorToReport = error as NSError
			}
			return self.reportErrorWithFileProviderItem(error: errorToReport, itemMetadata: itemMetadata)
		}
	}

	/**
	  - Precondition: `identifier.rawValue ` can be casted to a positive Int64 value
	  - Precondition: the metadata associated with the `identifier` is stored in the database
	  - Precondition: `localURL` must be a file URL
	  - Precondition: `localURL` must point to a file
	  - Postcondition: the `ItemMetadata` entry associated with the `identifier` has the statusCode: `ItemStatus.isUploading`
	  - Postcondition: a new UploadTask was registered for the ItemIdentifier.
	  - Postcondition:  if a previous UploadTask for the ItemIdentifier existed in the database, it was removed.
	  - Postcondition: in the local FileInfo table the entry for the passed identifier was updated to the local lastModifiedDate.
	  - Returns: For convenience, returns the ItemMetadata for the file to upload.
	  - throws: throws an NSFileProviderError.noSuchItem if the identifier could not be converted or no ItemMetadata exists for the identifier or an error occurs while writing to the database.
	 */
	public func registerFileInUploadQueue(with localURL: URL, identifier: NSFileProviderItemIdentifier) throws -> ItemMetadata {
		precondition(localURL.isFileURL)
		precondition(!localURL.hasDirectoryPath)
		let id: Int64
		do {
			id = try convertFileProviderItemIdentifierToInt64(identifier)
		} catch {
			throw NSFileProviderError(.noSuchItem)
		}
		guard let metadata = try? itemMetadataManager.getCachedMetadata(for: id) else {
			throw NSFileProviderError(.noSuchItem)
		}
		metadata.statusCode = ItemStatus.isUploading
		do {
			let attributes = try FileManager.default.attributesOfItem(atPath: localURL.path)
			let lastModifiedDate = attributes[FileAttributeKey.modificationDate] as? Date
			try itemMetadataManager.updateMetadata(metadata)
			try uploadTaskManager.removeTask(for: id)
			_ = try uploadTaskManager.createNewTask(for: id)
			try cachedFileManager.cacheLocalFileInfo(for: id, lastModifiedDate: lastModifiedDate)
		} catch {
			throw NSFileProviderError(.noSuchItem)
		}
		return metadata
	}

	/**
	 - Postcondition: The file is stored under the `remoteURL` of the cloud provider.
	 - Postcondition: itemMetadata.statusCode = .isUploaded && itemMetadata.isPlaceholderItem = false
	 - Postcondition: The associated CachedFileEntry contains the lastModifiedDate from the cloud.
	 - Returns: Promise with FileProviderItem. If the upload fails with an error different to `CloudProviderError.itemAlreadyExists`  the Promise fulfills with a FileProviderItem, which contains a failed UploadTask to inform the FileProvider about the error. :
	 	- `NSFileProviderError.noSuchItem` if the provider rejected the upload with `CloudProviderError.itemNotFound`
	 	- `NSFileProviderError.insufficientQuota` if the provider rejected the upload with `CloudProviderError.quotaInsufficient`
	 	- `NSFileProviderError.serverUnreachable` if the provider rejected the upload with `CloudProviderError.noInternetConnection`
	 	- `NSFileProviderError.notAuthenticated` if the provider rejected the upload with `CloudProviderError.unauthorized`
	 */
	func uploadFileWithoutRecover(from localURL: URL, itemMetadata: ItemMetadata) -> Promise<FileProviderItem> {
		precondition(itemMetadata.statusCode == .isUploading)
		let cloudPath = itemMetadata.cloudPath
		print("uploadTo: \(cloudPath)")
		let progress = Progress.discreteProgress(totalUnitCount: 1)
		let task = FileProviderNetworkTask(with: progress)
		manager.register(task, forItemWithIdentifier: NSFileProviderItemIdentifier(String(itemMetadata.id!))) { error in
			if let error = error {
				print("Register Task Error: \(error)")
			}
		}
		return Promise<FileProviderItem>(on: uploadQueue) { fulfill, reject in
			self.uploadSemaphore.wait()
			task.resume()
			progress.becomeCurrent(withPendingUnitCount: 1)
			self.provider.uploadFile(from: localURL, to: cloudPath, replaceExisting: !itemMetadata.isPlaceholderItem).then { cloudItemMetadata in
				itemMetadata.statusCode = .isUploaded
				itemMetadata.isPlaceholderItem = false
				itemMetadata.lastModifiedDate = cloudItemMetadata.lastModifiedDate
				itemMetadata.size = cloudItemMetadata.size
				try self.itemMetadataManager.updateMetadata(itemMetadata)
				try self.uploadTaskManager.removeTask(for: itemMetadata.id!)
				try self.cachedFileManager.cacheLocalFileInfo(for: itemMetadata.id!, lastModifiedDate: cloudItemMetadata.lastModifiedDate)
				fulfill(FileProviderItem(metadata: itemMetadata, newestVersionLocallyCached: true))
			}.catch { error in
				do {
					let item = try self.errorHandlingForUserDrivenActions(error: error, itemMetadata: itemMetadata)
					fulfill(item)
				} catch {
					reject(error)
				}
			}.always {
				self.uploadSemaphore.signal()
			}

			progress.resignCurrent()
		}
	}

	/**
	 - Precondition: `itemMetadata` is already stored in the db
	 - Postcondition: `itemMetadata.statusCode` == .uploadError
	 - Postcondition: If an UploadTask associated with the ItemMetadata exists, the error was passed to it and persisted in the DB.
	 - returns: FileProviderItem from the passed `itemMetadata` and the passed `error`
	 */
	func reportErrorWithFileProviderItem(error: NSError, itemMetadata: ItemMetadata) -> FileProviderItem {
		itemMetadata.statusCode = .uploadError
		if var uploadTask = try? uploadTaskManager.getTask(for: itemMetadata.id!) {
			try? uploadTaskManager.updateTask(&uploadTask, error: error)
		}
		try? itemMetadataManager.updateMetadata(itemMetadata)
		return FileProviderItem(metadata: itemMetadata, error: error)
	}

	/**
	 - Precondition: `itemMetadata` is already stored in the db
	 - Postcondition: `itemMetadata.statusCode` == .uploadError
	 - Postcondition: If an UploadTask associated with the ItemMetadata exists, the error was passed to it and persisted in the DB.
	 - returns: FileProviderItem from the passed `itemMetadata` and the passed `error`.
	 - throws:  If the passed `error` is  `CloudProviderError.itemAlreadyExists`
	 */
	func errorHandlingForUserDrivenActions(error: Error, itemMetadata: ItemMetadata) throws -> FileProviderItem {
		let errorToReport: NSError
		if let cloudProviderError = error as? CloudProviderError {
			if cloudProviderError == .itemAlreadyExists {
				throw CloudProviderError.itemAlreadyExists
			}
			errorToReport = mapCloudProviderErrorToNSFileProviderError(cloudProviderError) as NSError

		} else {
			errorToReport = error as NSError
		}
		let item = reportErrorWithFileProviderItem(error: errorToReport, itemMetadata: itemMetadata)
		return item
	}

	func mapCloudProviderErrorToNSFileProviderError(_ error: CloudProviderError) -> NSFileProviderError {
		switch error {
		case .itemAlreadyExists:
			return NSFileProviderError(.filenameCollision)
		case .itemNotFound:
			return NSFileProviderError(.noSuchItem)
		case .itemTypeMismatch:
			return NSFileProviderError(.noSuchItem)
		case .noInternetConnection:
			return NSFileProviderError(.serverUnreachable)
		case .pageTokenInvalid:
			return NSFileProviderError(.pageExpired)
		case .parentFolderDoesNotExist:
			return NSFileProviderError(.noSuchItem)
		case .quotaInsufficient:
			return NSFileProviderError(.insufficientQuota)
		case .unauthorized:
			return NSFileProviderError(.notAuthenticated)
		}
	}

	/**
	 - warning: Call this function only from a FileProvider Extension. Otherwise, an error is thrown.
	 */
	public func urlForItem(withPersistentIdentifier identifier: NSFileProviderItemIdentifier) -> URL? {
		guard let itemMetadata = try? getCachedMetadata(for: identifier) else {
			return nil
		}
		let domainDocumentStorage = domain.pathRelativeToDocumentStorage
		let domainURL = manager.documentStorageURL.appendingPathComponent(domainDocumentStorage)
		let perItemDirectory = domainURL.appendingPathComponent(identifier.rawValue, isDirectory: true)
		return perItemDirectory.appendingPathComponent(itemMetadata.name, isDirectory: false)
	}

	func cleanUpNoLongerInTheCloudExistingItems(insideParentId parentId: Int64) throws {
		let outdatedItems = try itemMetadataManager.getMaybeOutdatedItems(insideParentId: parentId)
		for outdatedItem in outdatedItems {
			try removeItemFromCache(outdatedItem)
		}
	}

	func removeItemFromCache(_ item: ItemMetadata) throws {
		if item.type == .folder {
			try removeFolderFromCache(item)
		} else if item.type == .file {
			try removeFileFromCache(item)
		}
		try itemMetadataManager.removeItemMetadata(with: item.id!)
	}

	/**
	 Deletes the folder from the cache and all items contained in the folder.
	 This includes in particular all subfolders and their contents. Locally cached files contained in this folder are also removed from the device.
	 - Precondition: The passed item is a folder
	 */
	func removeFolderFromCache(_ folder: ItemMetadata) throws {
		assert(folder.type == .folder)
		let innerItems = try itemMetadataManager.getAllCachedMetadata(inside: folder)
		for item in innerItems {
			if item.type == .file {
				try removeFileFromCache(item)
			}
		}
		let identifiers = innerItems.map({ $0.id! })
		try itemMetadataManager.removeItemMetadata(identifiers)
	}

	func removeFileFromCache(_ file: ItemMetadata) throws {
		assert(file.type == .file)
		let identifier = NSFileProviderItemIdentifier(String(file.id!))
		guard let url = urlForItem(withPersistentIdentifier: identifier) else {
			throw NSFileProviderError(.noSuchItem)
		}
		try cachedFileManager.removeCachedFile(for: file.id!, at: url)
	}

	/**
	  - Precondition: the metadata is stored in the database as PlaceholderItem
	 */
	public func createFolderInCloud(for item: FileProviderItem) -> Promise<FileProviderItem> {
		let itemMetadata = item.metadata
		precondition(itemMetadata.isPlaceholderItem)
		precondition(itemMetadata.id != nil)
		precondition(itemMetadata.type == .folder)
		return createFolderInCloud(for: itemMetadata, at: itemMetadata.cloudPath).recover { error -> Promise<FileProviderItem> in
			if let item = try? self.errorHandlingForUserDrivenActions(error: error, itemMetadata: itemMetadata) {
				return Promise(item)
			}
			let collisionFreeCloudPath = itemMetadata.cloudPath.createCollisionCloudPath()
			do {
				try self.cloudFolderNameCollisionUpdate(with: collisionFreeCloudPath, itemMetadata: itemMetadata)
			} catch {
				return Promise(error)
			}
			return self.createFolderInCloud(for: itemMetadata, at: collisionFreeCloudPath)
		}
	}

	func cloudFolderNameCollisionUpdate(with collisionFreeCloudPath: CloudPath, itemMetadata: ItemMetadata) throws {
		itemMetadata.name = collisionFreeCloudPath.lastPathComponent
		itemMetadata.cloudPath = collisionFreeCloudPath
		try itemMetadataManager.updateMetadata(itemMetadata)
	}

	func createFolderInCloud(for itemMetadata: ItemMetadata, at cloudPath: CloudPath) -> Promise<FileProviderItem> {
		assert(itemMetadata.isPlaceholderItem)
		assert(itemMetadata.id != nil)
		assert(itemMetadata.type == .folder)
		return provider.createFolder(at: cloudPath).then { _ -> FileProviderItem in
			itemMetadata.statusCode = .isUploaded
			itemMetadata.isPlaceholderItem = false
			try self.itemMetadataManager.updateMetadata(itemMetadata)
			return FileProviderItem(metadata: itemMetadata, newestVersionLocallyCached: true)
		}
	}

	/**
	 - Precondition: the metadata associated with the `itemIdentifier` is stored in the database
	 - Precondition: `parentItemIdentifier != nil || newName != nil`
	 - Postcondition:
	 */
	public func moveItemLocally(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toParentItemWithIdentifier parentItemIdentifier: NSFileProviderItemIdentifier?, newName: String?) throws -> FileProviderItem {
		precondition(parentItemIdentifier != nil || newName != nil)
		let metadata = try getCachedMetadata(for: itemIdentifier)
		let parentId: Int64
		if let parentItemIdentifier = parentItemIdentifier {
			parentId = try convertFileProviderItemIdentifierToInt64(parentItemIdentifier)
		} else {
			parentId = metadata.parentId
		}
		let name: String
		if let newName = newName {
			name = newName
		} else {
			name = metadata.name
		}

		let cloudPath = try getCloudPathForPlaceholderItem(withName: name, in: parentId, type: metadata.type)
		let oldCloudPath = metadata.cloudPath
		let oldParentId = metadata.parentId
		metadata.name = name
		metadata.cloudPath = cloudPath
		metadata.parentId = parentId
		metadata.statusCode = .isUploading
		try itemMetadataManager.updateMetadata(metadata)
		try reparentTaskManager.createTask(for: metadata.id!, oldCloudPath: oldCloudPath, newCloudPath: cloudPath, oldParentId: oldParentId, newParentId: parentId)
		let newestVersionLocallyCached = try cachedFileManager.hasCurrentVersionLocal(for: metadata.id!, with: metadata.lastModifiedDate)
		return FileProviderItem(metadata: metadata, newestVersionLocallyCached: newestVersionLocallyCached)
	}

	public func moveItemInCloud(withIdentifier itemIdentifier: NSFileProviderItemIdentifier) -> Promise<FileProviderItem> {
		let metadata: ItemMetadata
		let reparentTask: ReparentTask
		do {
			metadata = try getCachedMetadata(for: itemIdentifier)
			reparentTask = try reparentTaskManager.getTask(for: metadata.id!)
		} catch {
			return Promise(error)
		}
		return moveItemInCloud(metadata: metadata, sourceCloudPath: reparentTask.sourceCloudPath, targetCloudPath: reparentTask.targetCloudPath).recover { error -> Promise<FileProviderItem> in
			if let item = try? self.errorHandlingForUserDrivenActions(error: error, itemMetadata: metadata) {
				return Promise(item)
			}
			let collisionFreeCloudPath = reparentTask.targetCloudPath.createCollisionCloudPath()
			do {
				try self.cloudFolderNameCollisionUpdate(with: collisionFreeCloudPath, itemMetadata: metadata)
			} catch {
				return Promise(error)
			}
			return self.moveItemInCloud(metadata: metadata, sourceCloudPath: reparentTask.sourceCloudPath, targetCloudPath: collisionFreeCloudPath)
		}.always {
			try? self.reparentTaskManager.removeTask(reparentTask) // MARK: Discuss if it is ok that we do not pass on an error when deleting the reparent task.
		}
	}

	func moveItemInCloud(metadata: ItemMetadata, sourceCloudPath: CloudPath, targetCloudPath: CloudPath) -> Promise<FileProviderItem> {
		return moveFileOrFolderInCloud(metadata: metadata, sourceCloudPath: sourceCloudPath, targetCloudPath: targetCloudPath).then { _ -> FileProviderItem in
			metadata.statusCode = .isUploaded
			try self.itemMetadataManager.cacheMetadata(metadata)
			let newestVersionLocallyCached = try self.cachedFileManager.hasCurrentVersionLocal(for: metadata.id!, with: metadata.lastModifiedDate)
			return FileProviderItem(metadata: metadata, newestVersionLocallyCached: newestVersionLocallyCached)
		}
	}

	func moveFileOrFolderInCloud(metadata: ItemMetadata, sourceCloudPath: CloudPath, targetCloudPath: CloudPath) -> Promise<Void> {
		switch metadata.type {
		case .file:
			return provider.moveFile(from: sourceCloudPath, to: targetCloudPath)
		case .folder:
			return provider.moveFolder(from: sourceCloudPath, to: targetCloudPath)
		default:
			return Promise(FileProviderDecoratorError.unsupportedItemType)
		}
	}

	public func deleteItemLocally(withIdentifier itemIdentifier: NSFileProviderItemIdentifier) throws {
		let metadata: ItemMetadata
		do {
			metadata = try getCachedMetadata(for: itemIdentifier)
		} catch {
			return
		}
		try deletionTaskManager.createTask(for: metadata)
		try removeItemFromCache(metadata)
	}

	public func deleteItemInCloud(withIdentifier itemIdentifier: NSFileProviderItemIdentifier) -> Promise<Void> {
		let deletionTask: DeletionTask
		do {
			let id = try convertFileProviderItemIdentifierToInt64(itemIdentifier)
			deletionTask = try deletionTaskManager.getTask(for: id)
		} catch {
			return Promise(error)
		}

		return deleteItemInCloud(with: deletionTask).always {
			try? self.deletionTaskManager.removeTask(deletionTask) // MARK: Discuss if it is ok that we do not pass on an error when deleting the deletion task.
		}
	}

	func deleteItemInCloud(with deletionTask: DeletionTask) -> Promise<Void> {
		switch deletionTask.itemType {
		case .file:
			return provider.deleteFile(at: deletionTask.cloudPath)
		case .folder:
			return provider.deleteFolder(at: deletionTask.cloudPath)
		default:
			return Promise(FileProviderDecoratorError.unsupportedItemType)
		}
	}

	/**
	 A possible version conflict between the local file and the file in the cloud can occur if the changes to the local file have not yet been synchronized to the cloud due to an upload error and the file in the cloud has also been changed.
	 A possible conflict can also occur if the file is being uploaded and could be overwritten due to an immediate download.
	 - Precondition: `itemIdentifier.rawValue ` can be casted to a positive Int64 value
	 - Precondition: the metadata associated with the `itemIdentifier` is stored in the database
	     */
	public func hasPossibleVersioningConflictForItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier) throws -> Bool {
		let id = try convertFileProviderItemIdentifierToInt64(itemIdentifier)
		guard let uploadTask = try uploadTaskManager.getTask(for: id) else {
			return false
		}
		guard let localLastModifiedDate = try cachedFileManager.getLocalLastModifiedDate(for: id) else {
			return false
		}
		guard let lastFailedUploadDate = uploadTask.lastFailedUploadDate else {
			return true
		}
		return lastFailedUploadDate > localLastModifiedDate
	}
}
