//
//  FileProviderDecorator.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 24.06.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation
import FileProvider
import CryptomatorCloudAccess
import GRDB
import Promises
public class FileProviderDecorator {
	private let provider: CloudProvider
	private let itemMetadataManager: MetadataManager

	public init(for domainIdentifier: NSFileProviderDomainIdentifier) throws {
		//TODO: Real SetUp with CryptoDecorator,etc.
		self.provider = LocalFileSystemProvider()
		self.itemMetadataManager = try MetadataManager(for: domainIdentifier)
	}

	public func fetchItemList(for folderIdentifier: NSFileProviderItemIdentifier, withPageToken pageToken: String?) -> Promise<FileProviderItemList> {

		//TODO: Check for Internet Connection here
		
		let remoteURL = URL(fileURLWithPath: folderIdentifier.rawValue, isDirectory: true)
		print("fetchItemList")
		return provider.fetchItemList(forFolderAt: remoteURL, withPageToken: pageToken).then{ itemList -> FileProviderItemList in
			var metadatas = [ItemMetadata]()
			for cloudItem in itemList.items {
				let fileProviderItemMetadata = self.createItemMetadata(for: cloudItem, withParentId: folderIdentifier)
				metadatas.append(fileProviderItemMetadata)

			}
			try self.itemMetadataManager.cacheMetadatas(metadatas)
			let items = metadatas.map{ return FileProviderItem(metadata: $0)}
			if let nextPageTokenData = itemList.nextPageToken?.data(using: .utf8)  {
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
