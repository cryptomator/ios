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

	let itemMetadataManager: MetadataManager
	let cachedFileManager: CachedFileManager
	var homeRoot: URL
	public init(for domainIdentifier: NSFileProviderDomainIdentifier) throws {
		// TODO: Real SetUp with CryptoDecorator, PersistentDBPool, DBMigrator, etc.
		self.internalProvider = LocalFileSystemProvider()
		let inMemoryDB = DatabaseQueue()
		self.itemMetadataManager = try MetadataManager(with: inMemoryDB)
		self.cachedFileManager = try CachedFileManager(with: inMemoryDB)
		self.homeRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)

		// MARK: Demo Content for FileProviderExtension

		let emptyContent = ""
		for i in 0 ... 5 {
			try FileManager.default.createDirectory(at: homeRoot.appendingPathComponent("Folder \(i)", isDirectory: true), withIntermediateDirectories: true, attributes: nil)
			try emptyContent.write(to: homeRoot.appendingPathComponent("File \(i)", isDirectory: false), atomically: true, encoding: .utf8)
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
		let parentRemoteURL = URL(fileURLWithPath: parentItemMetadata.remotePath, isDirectory: true)
		let remoteURL = parentRemoteURL.appendingPathComponent(localURL.lastPathComponent, isDirectory: false)
		let placeholderMetadata = ItemMetadata(name: localURL.lastPathComponent, type: .file, size: size, parentId: parentId, lastModifiedDate: lastModifiedDate, statusCode: .isUploading, remotePath: remoteURL.relativePath, isPlaceholderItem: true)
		try itemMetadataManager.cacheMetadata(placeholderMetadata)
		try cachedFileManager.cacheLocalFileInfo(for: placeholderMetadata.id!, lastModifiedDate: lastModifiedDate)
		return FileProviderItem(metadata: placeholderMetadata)
	}

	public func removePlaceholderItem(with identifier: NSFileProviderItemIdentifier) throws {
		let id = try convertFileProviderItemIdentifierToInt64(identifier)
		try itemMetadataManager.removePlaceholderMetadata(with: id)
		try cachedFileManager.removeCachedEntry(for: id)
	}
}
