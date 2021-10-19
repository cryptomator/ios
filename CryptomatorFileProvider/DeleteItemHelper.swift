//
//  DeleteItemHelper.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 31.05.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation

class DeleteItemHelper {
	private let itemMetadataManager: ItemMetadataManager
	private let cachedFileManager: CachedFileManager

	init(itemMetadataManager: ItemMetadataManager, cachedFileManager: CachedFileManager) {
		self.itemMetadataManager = itemMetadataManager
		self.cachedFileManager = cachedFileManager
	}

	func removeItemFromCache(_ item: ItemMetadata) throws {
		if item.type == .folder {
			try removeFolderFromCache(item)
		} else if item.type == .file {
			try removeFileFromCache(item)
		}
	}

	/**
	 Deletes the folder from the cache and all items contained in the folder.

	 This includes in particular all subfolders and their contents. Locally cached files contained in this folder are also removed from the device.

	 - Precondition: The passed item is a folder
	 */
	private func removeFolderFromCache(_ folder: ItemMetadata) throws {
		assert(folder.type == .folder)
		let innerItems = try itemMetadataManager.getAllCachedMetadata(inside: folder)
		for item in innerItems where item.type == .file {
			try removeFileFromCache(item)
		}
		let identifiers = innerItems.map({ $0.id! })
		try itemMetadataManager.removeItemMetadata(identifiers)
	}

	private func removeFileFromCache(_ file: ItemMetadata) throws {
		assert(file.type == .file)
		try cachedFileManager.removeCachedFile(for: file.id!)
	}
}
