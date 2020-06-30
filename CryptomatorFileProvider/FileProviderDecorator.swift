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
	private let provider: CloudProvider
	private let itemMetadataManager: MetadataManager
	private let homeRoot: URL
	public init(for domainIdentifier: NSFileProviderDomainIdentifier) throws {
		// TODO: Real SetUp with CryptoDecorator,etc.
		self.provider = LocalFileSystemProvider()
		self.itemMetadataManager = try MetadataManager(for: domainIdentifier)
		let homeDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		let emptyContent = ""
		self.homeRoot = homeDirectory.appendingPathComponent(NSFileProviderItemIdentifier.rootContainer.rawValue, isDirectory: true)
		for i in 0 ... 5 {
			try FileManager.default.createDirectory(at: homeRoot.appendingPathComponent("Folder \(i)", isDirectory: true), withIntermediateDirectories: true, attributes: nil)
			try emptyContent.write(to: homeRoot.appendingPathComponent("File \(i)", isDirectory: false), atomically: true, encoding: .utf8)
		}
	}

	public func fetchItemList(for folderIdentifier: NSFileProviderItemIdentifier, withPageToken pageToken: String?) -> Promise<FileProviderItemList> {
		// TODO: Check for Internet Connection here

		// TODO: Remove HomeDirectory later.. only for first Testing with Local

		// let remoteURL = URL(fileURLWithPath: folderIdentifier.rawValue, isDirectory: true)

		var remoteURL: URL!
		if folderIdentifier == .rootContainer {
			remoteURL = homeRoot
		} else {
			remoteURL = URL(fileURLWithPath: folderIdentifier.rawValue, isDirectory: true)
		}
		return provider.fetchItemList(forFolderAt: remoteURL, withPageToken: pageToken).then { itemList -> FileProviderItemList in
			var metadatas = [ItemMetadata]()
			for cloudItem in itemList.items {
				let fileProviderItemMetadata = self.createItemMetadata(for: cloudItem, withParentId: folderIdentifier)
				metadatas.append(fileProviderItemMetadata)
			}
			try self.itemMetadataManager.cacheMetadatas(metadatas)
			let placeholderMetadatas = try self.itemMetadataManager.getPlaceholderMetadata(for: folderIdentifier.rawValue)
			metadatas.append(contentsOf: placeholderMetadatas)
			let items = metadatas.map { return FileProviderItem(metadata: $0) }
			if let nextPageTokenData = itemList.nextPageToken?.data(using: .utf8) {
				return FileProviderItemList(items: items, nextPageToken: NSFileProviderPage(nextPageTokenData))
			}
			return FileProviderItemList(items: items, nextPageToken: nil)
		}
	}

	func createItemMetadata(for item: CloudItemMetadata, withParentId parentId: NSFileProviderItemIdentifier, isPlaceholderItem: Bool = false) -> ItemMetadata {
		let metadata = ItemMetadata(name: item.name, type: item.itemType, size: item.size, remoteParentPath: parentId.rawValue, lastModifiedDate: item.lastModifiedDate, statusCode: .isUploaded, remotePath: item.remoteURL.relativePath, isPlaceholderItem: isPlaceholderItem)
		return metadata
	}

	public func getFileProviderItem(for identifier: NSFileProviderItemIdentifier) throws -> FileProviderItem {
		guard let itemMetadata = try itemMetadataManager.getCachedMetadata(for: identifier.rawValue) else {
			throw NSFileProviderError(.noSuchItem)
		}
		return FileProviderItem(metadata: itemMetadata)
	}
}
