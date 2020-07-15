//
//  FileProviderDecorator.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 24.06.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CloudAccessPrivate
import CryptomatorCloudAccess
import FileProvider
import Foundation
import GRDB
import Promises
public class FileProviderDecorator {
	// Needed to mock the class
	private let internalProvider: CloudProvider
	var provider: CloudProvider {
		return internalProvider
	}

	private let uploadQueue: DispatchQueue
	private let downloadQueue: DispatchQueue

	let itemMetadataManager: MetadataManager
	let cachedFileManager: CachedFileManager
	let uploadTaskManager: UploadTaskManager
	public let notificator: FileProviderNotificator
	var homeRoot: URL
	let domain: NSFileProviderDomain
	let manager: NSFileProviderManager
	public init(for domain: NSFileProviderDomain, with manager: NSFileProviderManager) throws {
		self.uploadQueue = DispatchQueue(label: "FileProviderDecorator-Upload", qos: .userInitiated)
		self.downloadQueue = DispatchQueue(label: "FileProviderDecorator-Download", qos: .userInitiated)
		// TODO: Real SetUp with CryptoDecorator, PersistentDBPool, DBMigrator, etc.
		self.internalProvider = LocalFileSystemProvider()
		let inMemoryDB = DatabaseQueue()
		self.notificator = FileProviderNotificator(manager: manager)
		self.itemMetadataManager = try MetadataManager(with: inMemoryDB)
		self.cachedFileManager = try CachedFileManager(with: inMemoryDB)
		self.uploadTaskManager = try UploadTaskManager(with: inMemoryDB)
		self.domain = domain
		self.manager = manager

		// MARK: Demo Content for FileProviderExtension

		self.homeRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		let testContent = "Demo File Content"
		for i in 0 ... 5 {
			try FileManager.default.createDirectory(at: homeRoot.appendingPathComponent("Folder \(i)", isDirectory: true), withIntermediateDirectories: true, attributes: nil)
			try testContent.write(to: homeRoot.appendingPathComponent("File \(i).txt", isDirectory: false), atomically: true, encoding: .utf8)
		}
	}

	public func fetchItemList(for folderIdentifier: NSFileProviderItemIdentifier, withPageToken pageToken: String?) -> Promise<FileProviderItemList> {
		// TODO: Check for Internet Connection here

		// let remoteURL = URL(fileURLWithPath: folderIdentifier.rawValue, isDirectory: true)

		let parentId: Int64
		let remoteURL: URL
		do {
			parentId = try convertFileProviderItemIdentifierToInt64(folderIdentifier)
			guard let metadata = try itemMetadataManager.getCachedMetadata(for: parentId) else {
				return Promise(CloudProviderError.itemNotFound)
			}
			// TODO: Remove HomeDirectory later.. only for first Testing with Local
			if folderIdentifier == .rootContainer || parentId == MetadataManager.rootContainerId {
				remoteURL = homeRoot
			} else {
				remoteURL = URL(fileURLWithPath: metadata.remotePath, isDirectory: true)
			}
		} catch {
			return Promise(error)
		}
		return provider.fetchItemList(forFolderAt: remoteURL, withPageToken: pageToken).then { itemList -> FileProviderItemList in
			if pageToken == nil {
				try self.itemMetadataManager.flagAllItemsAsMaybeOutdated(insideParentId: parentId)
			}

			var metadatas = [ItemMetadata]()
			for cloudItem in itemList.items {
				let fileProviderItemMetadata = self.createItemMetadata(for: cloudItem, withParentId: parentId)
				metadatas.append(fileProviderItemMetadata)
			}
			try self.itemMetadataManager.cacheMetadatas(metadatas)
			let placeholderMetadatas = try self.itemMetadataManager.getPlaceholderMetadata(for: parentId)
			metadatas.append(contentsOf: placeholderMetadatas)
			let ids = metadatas.map { return $0.id! }
			let uploadTasks = try self.uploadTaskManager.getCorrespondingTasks(ids: ids)
			assert(metadatas.count == uploadTasks.count)
			let items = metadatas.enumerated().map { index, metadata in
				return FileProviderItem(metadata: metadata, uploadTask: uploadTasks[index])
			}
			if let nextPageTokenData = itemList.nextPageToken?.data(using: .utf8) {
				return FileProviderItemList(items: items, nextPageToken: NSFileProviderPage(nextPageTokenData))
			}
			try self.cleanUpNoLongerInTheCloudExistingItems(insideParentId: parentId)
			return FileProviderItemList(items: items, nextPageToken: nil)
		}
	}

	func createItemMetadata(for item: CloudItemMetadata, withParentId parentId: Int64, isPlaceholderItem: Bool = false) -> ItemMetadata {
		let metadata = ItemMetadata(name: item.name, type: item.itemType, size: item.size, parentId: parentId, lastModifiedDate: item.lastModifiedDate, statusCode: .isUploaded, remotePath: item.remoteURL.relativePath, isPlaceholderItem: isPlaceholderItem)
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
		return FileProviderItem(metadata: itemMetadata, uploadTask: uploadTask)
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
		let remoteURL = URL(fileURLWithPath: metadata.remotePath, isDirectory: metadata.type == .folder)

		return provider.fetchItemMetadata(at: remoteURL).then { cloudMetadata -> Bool in
			guard let lastModifiedDateInCloud = cloudMetadata.lastModifiedDate else {
				return false
			}
			return try self.cachedFileManager.hasCurrentVersionLocal(for: metadata.id!, with: lastModifiedDateInCloud)
		}
	}

	public func downloadFile(with identifier: NSFileProviderItemIdentifier, to localURL: URL) -> Promise<Void> {
		let metadata: ItemMetadata
		do {
			metadata = try getCachedMetadata(for: identifier)
		} catch {
			return Promise(error)
		}
		let remoteURL = URL(fileURLWithPath: metadata.remotePath, isDirectory: metadata.type == .folder)
		var lastModifiedDate: Date?
		return provider.fetchItemMetadata(at: remoteURL).then { cloudMetadata -> Promise<Void> in
			lastModifiedDate = cloudMetadata.lastModifiedDate
			return self.provider.downloadFile(from: remoteURL, to: localURL)
		}.then {
			try self.cachedFileManager.cacheLocalFileInfo(for: metadata.id!, lastModifiedDate: lastModifiedDate)
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
		let remoteURL = try getRemoteURLForPlaceholderItem(withName: localURL.lastPathComponent, in: parentId)
		let placeholderMetadata = ItemMetadata(name: localURL.lastPathComponent, type: .file, size: size, parentId: parentId, lastModifiedDate: lastModifiedDate, statusCode: .isUploading, remotePath: remoteURL.relativePath, isPlaceholderItem: true)
		try itemMetadataManager.cacheMetadata(placeholderMetadata)
		try cachedFileManager.cacheLocalFileInfo(for: placeholderMetadata.id!, lastModifiedDate: lastModifiedDate)
		return FileProviderItem(metadata: placeholderMetadata)
	}

	public func createPlaceholderItemForFolder(withName name: String, in parentIdentifier: NSFileProviderItemIdentifier) throws -> FileProviderItem {
		let parentId = try convertFileProviderItemIdentifierToInt64(parentIdentifier)
		let remoteURL = try getRemoteURLForPlaceholderItem(withName: name, in: parentId)
		let placeholderMetadata = ItemMetadata(name: name, type: .folder, size: nil, parentId: parentId, lastModifiedDate: nil, statusCode: .isUploading, remotePath: remoteURL.relativePath, isPlaceholderItem: true)
		try itemMetadataManager.cacheMetadata(placeholderMetadata)
		return FileProviderItem(metadata: placeholderMetadata)
	}

	func getRemoteURLForPlaceholderItem(withName name: String, in parentId: Int64) throws -> URL {
		guard let parentItemMetadata = try itemMetadataManager.getCachedMetadata(for: parentId), parentItemMetadata.type == .folder else {
			throw FileProviderDecoratorError.parentFolderNotFound
		}
		// TODO: Remove homeRoot <-- only for demo purpose with LocalFileSystemProvider
		var parentRemoteURL = URL(fileURLWithPath: parentItemMetadata.remotePath, isDirectory: true)
		if parentId == MetadataManager.rootContainerId {
			parentRemoteURL = homeRoot
		}
		let remoteURL = parentRemoteURL.appendingPathComponent(name, isDirectory: false)

		if let existingItemMetadata = try itemMetadataManager.getCachedMetadata(for: remoteURL.relativePath) {
			throw NSError.fileProviderErrorForCollision(with: FileProviderItem(metadata: existingItemMetadata))
		}
		return remoteURL
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
		itemMetadata.remotePath = collisionFreeLocalURL.relativePath
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
		let remoteURL = URL(fileURLWithPath: itemMetadata.remotePath, isDirectory: false)
		print("uploadTo: \(remoteURL)")
		return Promise<FileProviderItem>(on: uploadQueue) { fulfill, reject in
			self.provider.uploadFile(from: localURL, to: remoteURL, replaceExisting: !itemMetadata.isPlaceholderItem).then { cloudItemMetadata in
				itemMetadata.statusCode = .isUploaded
				itemMetadata.isPlaceholderItem = false
				itemMetadata.lastModifiedDate = cloudItemMetadata.lastModifiedDate
				itemMetadata.size = cloudItemMetadata.size
				try self.itemMetadataManager.updateMetadata(itemMetadata)
				try self.uploadTaskManager.removeTask(for: itemMetadata.id!)
				try self.cachedFileManager.cacheLocalFileInfo(for: itemMetadata.id!, lastModifiedDate: cloudItemMetadata.lastModifiedDate)
				fulfill(FileProviderItem(metadata: itemMetadata))
			}.catch { error in
				let errorToReport: NSError
				if let cloudProviderError = error as? CloudProviderError {
					if cloudProviderError == .itemAlreadyExists {
						reject(CloudProviderError.itemAlreadyExists)
						return
					}
					errorToReport = self.mapCloudProviderErrorToNSFileProviderError(cloudProviderError) as NSError
				} else {
					errorToReport = error as NSError
				}
				print("Report now Error: \(errorToReport)")
				let item = self.reportErrorWithFileProviderItem(error: errorToReport, itemMetadata: itemMetadata)
				fulfill(item)
			}
		}
	}

	func reportErrorWithFileProviderItem(error: NSError, itemMetadata: ItemMetadata) -> FileProviderItem {
		itemMetadata.statusCode = .uploadError
		var uploadTask = try? uploadTaskManager.getTask(for: itemMetadata.id!)
		if uploadTask != nil {
			try? uploadTaskManager.updateTask(&uploadTask!, error: error)
		}
		try? itemMetadataManager.updateMetadata(itemMetadata)
		return FileProviderItem(metadata: itemMetadata, uploadTask: uploadTask)
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
			try removeItemFromCache(with: outdatedItem.id!)
		}
	}

	func removeItemFromCache(with id: Int64) throws {
		let identifier = NSFileProviderItemIdentifier(String(id))
		guard let url = urlForItem(withPersistentIdentifier: identifier) else {
			throw NSFileProviderError(.noSuchItem)
		}
		let hasLocalItem = try cachedFileManager.removeCachedEntry(for: id)
		if hasLocalItem {
			try FileManager.default.removeItem(at: url)
		}
		try itemMetadataManager.removeItemMetadata(with: id)
	}

	/**
	  - Precondition: the metadata is stored in the database as PlaceholderItem
	 */
	public func createFolderInCloud(for item: FileProviderItem) -> Promise<FileProviderItem> {
		let itemMetadata = item.metadata
		precondition(itemMetadata.isPlaceholderItem)
		precondition(itemMetadata.id != nil)
		precondition(itemMetadata.type == .folder)
		let remoteURL = URL(fileURLWithPath: itemMetadata.remotePath, isDirectory: true)
		return provider.createFolder(at: remoteURL).then { _ -> FileProviderItem in
			itemMetadata.statusCode = .isUploaded
			itemMetadata.isPlaceholderItem = false
			try self.itemMetadataManager.updateMetadata(itemMetadata)
			return FileProviderItem(metadata: itemMetadata)
		}.recover { error -> Promise<FileProviderItem> in
			let errorToReport: NSError
			if let cloudProviderError = error as? CloudProviderError {
				errorToReport = self.mapCloudProviderErrorToNSFileProviderError(cloudProviderError) as NSError
			} else {
				errorToReport = error as NSError
			}
			let item: FileProviderItem = self.reportErrorWithFileProviderItem(error: errorToReport, itemMetadata: itemMetadata)
			return Promise(item)
		}
	}
}

/**
 ```
 root
 ├─ Directory 1
 │  ├─ Directory 2
 │  └─ File 5
 ├─ File 1
 ├─ File 2
 ├─ File 3
 └─ File 4
 ```
 */
private class CloudProviderMock: CloudProvider {
	let folders: Set = [
		"/Directory 1",
		"/Directory 1/Directory 2"
	]
	var files: [String: Data?] = [
		"/File 1": "File 1 content".data(using: .utf8),
		"/File 2": "File 2 content".data(using: .utf8),
		"/File 3": "File 3 content".data(using: .utf8),
		"/File 4": "File 4 content".data(using: .utf8),
		"/Directory 1/File 5": "File 5 content".data(using: .utf8)
	]
	var lastModifiedDate: [String: Date?] = ["/Directory 1": nil,
											 "/Directory 1/Directory 2": nil,
											 "/File 1": Date(timeIntervalSince1970: 0),
											 "/File 2": Date(timeIntervalSince1970: 0),
											 "/File 3": Date(timeIntervalSince1970: 0),
											 "/File 4": Date(timeIntervalSince1970: 0),
											 "/Directory 1/File 5": Date(timeIntervalSince1970: 0)]

	var createdFolders: [String] = []
	var createdFiles: [String: Data] = [:]
	var deleted: [String] = []
	var moved: [String: String] = [:]

	public func fetchItemMetadata(at remoteURL: URL) -> Promise<CloudItemMetadata> {
		precondition(remoteURL.isFileURL)
		if folders.contains(remoteURL.relativePath) {
			return Promise(CloudItemMetadata(name: remoteURL.lastPathComponent, remoteURL: remoteURL, itemType: .folder, lastModifiedDate: lastModifiedDate[remoteURL.relativePath] ?? nil, size: 0))
		} else if let data = files[remoteURL.relativePath] {
			return Promise(CloudItemMetadata(name: remoteURL.lastPathComponent, remoteURL: remoteURL, itemType: .file, lastModifiedDate: lastModifiedDate[remoteURL.relativePath] ?? nil, size: data!.count))
		} else {
			return Promise(CloudProviderError.itemNotFound)
		}
	}

	public func fetchItemList(forFolderAt remoteURL: URL, withPageToken _: String?) -> Promise<CloudItemList> {
		precondition(remoteURL.isFileURL)
		precondition(remoteURL.hasDirectoryPath)
		let parentPath = remoteURL.relativePath
		let parentPathLvl = parentPath.components(separatedBy: "/").count - (parentPath.hasSuffix("/") ? 1 : 0)
		let childDirs = folders.filter { $0.hasPrefix(parentPath) && $0.components(separatedBy: "/").count == parentPathLvl + 1 }
		let childFiles = files.keys.filter { $0.hasPrefix(parentPath) && $0.components(separatedBy: "/").count == parentPathLvl + 1 }
		let children = childDirs + childFiles
		let metadataPromises = children.map { self.fetchItemMetadata(at: URL(fileURLWithPath: $0, isDirectory: childDirs.contains($0))) }
		return all(metadataPromises).then { metadata -> CloudItemList in
			let sortedMetadatas = metadata.sorted {
				$0.name < $1.name
			}
			return CloudItemList(items: sortedMetadatas)
		}
	}

	public func downloadFile(from remoteURL: URL, to localURL: URL) -> Promise<Void> {
		precondition(remoteURL.isFileURL)
		precondition(localURL.isFileURL)
		precondition(!remoteURL.hasDirectoryPath)
		precondition(!localURL.hasDirectoryPath)
		if let data = files[remoteURL.relativePath] {
			do {
				try data!.write(to: localURL, options: .withoutOverwriting)
			} catch {
				return Promise(error)
			}
			return Promise(())
		} else {
			return Promise(CloudProviderError.itemNotFound)
		}
	}

	public func uploadFile(from localURL: URL, to remoteURL: URL, replaceExisting: Bool) -> Promise<CloudItemMetadata> {
		precondition(localURL.isFileURL)
		precondition(remoteURL.isFileURL)
		precondition(!localURL.hasDirectoryPath)
		precondition(!remoteURL.hasDirectoryPath)
		return Promise(CloudProviderError.quotaInsufficient)
		switch remoteURL {
		case URL(fileURLWithPath: "/itemNotFound.txt", isDirectory: false):
			return Promise(CloudProviderError.itemNotFound)
		case URL(fileURLWithPath: "/itemAlreadyExists.txt", isDirectory: false):
			return Promise(CloudProviderError.itemAlreadyExists)
		case URL(fileURLWithPath: "/quotaInsufficient.txt", isDirectory: false):
			return Promise(CloudProviderError.quotaInsufficient)
		case URL(fileURLWithPath: "/noInternetConnection.txt", isDirectory: false):
			return Promise(CloudProviderError.noInternetConnection)
		case URL(fileURLWithPath: "/unauthorized.txt", isDirectory: false):
			return Promise(CloudProviderError.unauthorized)
		default:
			return normalUpload(from: localURL, to: remoteURL)
		}
	}

	private func normalUpload(from localURL: URL, to remoteURL: URL) -> Promise<CloudItemMetadata> {
		precondition(localURL.isFileURL)
		precondition(remoteURL.isFileURL)
		precondition(!localURL.hasDirectoryPath)
		precondition(!remoteURL.hasDirectoryPath)
		do {
			let data = try Data(contentsOf: localURL)
			createdFiles[remoteURL.relativePath] = data
			return Promise(CloudItemMetadata(name: remoteURL.lastPathComponent, remoteURL: remoteURL, itemType: .file, lastModifiedDate: lastModifiedDate[remoteURL.relativePath] ?? nil, size: data.count))
		} catch {
			return Promise(error)
		}
	}

	public func createFolder(at remoteURL: URL) -> Promise<Void> {
		precondition(remoteURL.isFileURL)
		precondition(remoteURL.hasDirectoryPath)
		createdFolders.append(remoteURL.relativePath)
		return Promise(())
	}

	public func deleteItem(at remoteURL: URL) -> Promise<Void> {
		precondition(remoteURL.isFileURL)
		deleted.append(remoteURL.relativePath)
		return Promise(())
	}

	public func moveItem(from oldRemoteURL: URL, to newRemoteURL: URL) -> Promise<Void> {
		precondition(oldRemoteURL.isFileURL)
		precondition(newRemoteURL.isFileURL)
		precondition(oldRemoteURL.hasDirectoryPath == newRemoteURL.hasDirectoryPath)
		moved[oldRemoteURL.relativePath] = newRemoteURL.relativePath
		return Promise(())
	}

	public func setLastModifiedDate(_ date: Date?, for remoteURL: URL) {
		lastModifiedDate[remoteURL.relativePath] = date
	}
}
