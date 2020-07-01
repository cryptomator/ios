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
		print(type(of: provider))
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

	/**
	 - Precondition: The file associated with the ItemIdentifier (this can be an older version), is located at the local URL associated with the ItemIdentifier.
	 */
	/* func startProvidingLocalItem(for identifier: NSFileProviderItemIdentifier) -> Promise<Void>{
	 	let metadata: ItemMetadata
	 	do{
	 		metadata = try getCachedMetadata(for: identifier)
	 	} catch{
	 		return Promise(error)
	 	}
	 	let remoteURL = URL(fileURLWithPath: metadata.remotePath, isDirectory: metadata.type == .folder)

	 	/*
	 	if fileIsCurrent {
	 	 	callCompletion(nil)
	 	 } else {
	 	 	if localFileHasChanges {
	 	 		// in this case, a version of the file is on disk, but we know of a more recent version
	 	 		// we need to implement a strategy to resolve this conflict
	 	 		moveLocalFileAside()
	 	 		scheduleUploadOfLocalFile()
	 	 		downloadRemoteFile()
	 	 		callCompletion(downloadErrorOrNil)
	 	 	} else {
	 	 		downloadRemoteFile()
	 	 		callCompletion(downloadErrorOrNil)
	 	 	}
	 	 }*/
	 } */

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
		return provider.downloadFile(from: remoteURL, to: localURL).then{
			try self.cachedFileManager.cacheLocalFileInfo(for: metadata.id!, lastModifiedDate: metadata.lastModifiedDate)
		}
	}

	func fetchItemMetadata(at remoteURL: URL) -> Promise<CloudItemMetadata> {
		provider.fetchItemMetadata(at: remoteURL).then { _ in
		}
	}
}
