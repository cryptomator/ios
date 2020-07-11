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
	var homeRoot: URL
	public init(for domainIdentifier: NSFileProviderDomainIdentifier) throws {
		self.uploadQueue = DispatchQueue(label: "FileProviderDecorator-Upload", qos: .userInitiated)
		self.downloadQueue = DispatchQueue(label: "FileProviderDecorator-Download", qos: .userInitiated)
		// TODO: Real SetUp with CryptoDecorator, PersistentDBPool, DBMigrator, etc.
		self.internalProvider = LocalFileSystemProvider()
		let inMemoryDB = DatabaseQueue()
		self.itemMetadataManager = try MetadataManager(with: inMemoryDB)
		self.cachedFileManager = try CachedFileManager(with: inMemoryDB)
		self.uploadTaskManager = try UploadTaskManager(with: inMemoryDB)
		self.homeRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)

		// MARK: Demo Content for FileProviderExtension

		let emptyContent = ""
		for i in 0 ... 5 {
			try FileManager.default.createDirectory(at: homeRoot.appendingPathComponent("Folder \(i)", isDirectory: true), withIntermediateDirectories: true, attributes: nil)
			try emptyContent.write(to: homeRoot.appendingPathComponent("File \(i).txt", isDirectory: false), atomically: true, encoding: .utf8)
		}
	}

	public func fetchItemList(for folderIdentifier: NSFileProviderItemIdentifier, withPageToken pageToken: String?) -> Promise<FileProviderItemList> {
		// TODO: Check for Internet Connection here

		// let remoteURL = URL(fileURLWithPath: folderIdentifier.rawValue, isDirectory: true)

		let parentIdentifier: Int64
		let remoteURL: URL
		do {
			parentIdentifier = try convertFileProviderItemIdentifierToInt64(folderIdentifier)
			guard let metadata = try itemMetadataManager.getCachedMetadata(for: parentIdentifier) else {
				return Promise(CloudProviderError.itemNotFound)
			}
			// TODO: Remove HomeDirectory later.. only for first Testing with Local
			if folderIdentifier == .rootContainer || parentIdentifier == MetadataManager.rootContainerId {
				remoteURL = homeRoot
			} else {
				remoteURL = URL(fileURLWithPath: metadata.remotePath, isDirectory: true)
			}
		} catch {
			return Promise(error)
		}
		return provider.fetchItemList(forFolderAt: remoteURL, withPageToken: pageToken).then { itemList -> FileProviderItemList in
			var metadatas = [ItemMetadata]()
			for cloudItem in itemList.items {
				let fileProviderItemMetadata = self.createItemMetadata(for: cloudItem, withParentId: parentIdentifier)
				metadatas.append(fileProviderItemMetadata)
			}
			try self.itemMetadataManager.cacheMetadatas(metadatas)
			let placeholderMetadatas = try self.itemMetadataManager.getPlaceholderMetadata(for: parentIdentifier)
			metadatas.append(contentsOf: placeholderMetadatas)
			let items = metadatas.map { return FileProviderItem(metadata: $0) }
			if let nextPageTokenData = itemList.nextPageToken?.data(using: .utf8) {
				return FileProviderItemList(items: items, nextPageToken: NSFileProviderPage(nextPageTokenData))
			}
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
		return FileProviderItem(metadata: itemMetadata)
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

		return fetchItemMetadata(at: remoteURL).then { cloudMetadata -> Bool in
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
		return provider.downloadFile(from: remoteURL, to: localURL).then {
			try self.cachedFileManager.cacheLocalFileInfo(for: metadata.id!, lastModifiedDate: metadata.lastModifiedDate)
		}
	}

	func fetchItemMetadata(at remoteURL: URL) -> Promise<CloudItemMetadata> {
		provider.fetchItemMetadata(at: remoteURL).then { _ in

			// MARK: Discuss if fetchItem should cache every time
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
		guard let parentItemMetadata = try itemMetadataManager.getCachedMetadata(for: parentId), parentItemMetadata.type == .folder else {
			throw FileProviderDecoratorError.parentFolderNotFound
		}
		// TODO: Remove homeRoot <-- only for demo purpose with LocalFileSystemProvider
		var parentRemoteURL = URL(fileURLWithPath: parentItemMetadata.remotePath, isDirectory: true)
		if parentIdentifier == .rootContainer {
			parentRemoteURL = homeRoot
		}
		let remoteURL = parentRemoteURL.appendingPathComponent(localURL.lastPathComponent, isDirectory: false)

		if let existingItemMetadata = try itemMetadataManager.getCachedMetadata(for: remoteURL.relativePath) {
			throw NSError.fileProviderErrorForCollision(with: FileProviderItem(metadata: existingItemMetadata))
		}

		let placeholderMetadata = ItemMetadata(name: localURL.lastPathComponent, type: .file, size: size, parentId: parentId, lastModifiedDate: lastModifiedDate, statusCode: .isUploading, remotePath: remoteURL.relativePath, isPlaceholderItem: true)
		try itemMetadataManager.cacheMetadata(placeholderMetadata)
		try cachedFileManager.cacheLocalFileInfo(for: placeholderMetadata.id!, lastModifiedDate: lastModifiedDate)
		return FileProviderItem(metadata: placeholderMetadata)
	}

	public func removePlaceholderItem(with identifier: NSFileProviderItemIdentifier) throws {
		let id = try convertFileProviderItemIdentifierToInt64(identifier)
		try itemMetadataManager.removeItemMetadata(with: id)
		try cachedFileManager.removeCachedEntry(for: id)
	}

	public func reportLocalUploadError(for identifier: NSFileProviderItemIdentifier) throws {
		let id = try convertFileProviderItemIdentifierToInt64(identifier)
	}

	public func uploadFile(with localURL: URL, identifier: NSFileProviderItemIdentifier) -> Promise<FileProviderItem> {
		let itemMetadata: ItemMetadata
		do {
			itemMetadata = try registerFileInUploadQueue(with: localURL, identifier: identifier)
		} catch {
			return Promise(error)
		}
		return uploadFile(from: localURL, itemMetadata: itemMetadata).recover { error -> Promise<FileProviderItem> in
			guard itemMetadata.isPlaceholderItem, case CloudProviderError.itemAlreadyExists = error else {
				return Promise(error)
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

		return uploadFile(from: collisionFreeLocalURL, itemMetadata: itemMetadata).recover { error -> FileProviderItem in
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
	func registerFileInUploadQueue(with localURL: URL, identifier: NSFileProviderItemIdentifier) throws -> ItemMetadata {
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
			try itemMetadataManager.updateMetadata(metadata)
			try uploadTaskManager.addNewTask(for: id)
			let attributes = try FileManager.default.attributesOfItem(atPath: localURL.path)
			let lastModifiedDate = attributes[FileAttributeKey.modificationDate] as? Date
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
	func uploadFile(from localURL: URL, itemMetadata: ItemMetadata) -> Promise<FileProviderItem> {
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
				let item = self.reportErrorWithFileProviderItem(error: errorToReport, itemMetadata: itemMetadata)
				fulfill(item)
			}
		}
	}

	func reportErrorWithFileProviderItem(error: NSError, itemMetadata: ItemMetadata) -> FileProviderItem {
		itemMetadata.statusCode = .uploadError
		var uploadTask = try? uploadTaskManager.getTask(for: itemMetadata.id!)
		try? uploadTaskManager.updateTask(&uploadTask, error: error)
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
}
