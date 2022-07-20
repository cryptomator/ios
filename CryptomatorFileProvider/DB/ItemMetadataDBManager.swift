//
//  ItemMetadataDBManager.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 24.06.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import FileProvider
import Foundation
import GRDB

protocol ItemMetadataManager {
	func cacheMetadata(_ metadata: ItemMetadata) throws
	func updateMetadata(_ metadata: ItemMetadata) throws
	func cacheMetadata(_ metadataList: [ItemMetadata]) throws
	/**
	 Returns the item metadata that has the same path.

	 The path is case-insensitively checked for equality.

	 However, it is stored and returned case-preserving in the database, because this is important for the `VaultDecorator` since the two cleartext paths "/foo" and "/Foo" lead to different ciphertext paths.
	 */
	func getCachedMetadata(for cloudPath: CloudPath) throws -> ItemMetadata?
	func getCachedMetadata(for id: Int64) throws -> ItemMetadata?
	func getPlaceholderMetadata(withParentID parentID: Int64) throws -> [ItemMetadata]
	func getCachedMetadata(withParentID parentID: Int64) throws -> [ItemMetadata]
	func flagAllItemsAsMaybeOutdated(withParentID parentID: Int64) throws
	func getMaybeOutdatedItems(withParentID parentID: Int64) throws -> [ItemMetadata]
	func removeItemMetadata(with id: Int64) throws
	func removeItemMetadata(_ ids: [Int64]) throws
	func getCachedMetadata(forIDs ids: [Int64]) throws -> [ItemMetadata]
	/**
	 Returns the items that have the item as parent because of its cloud path. This also includes all subfolders including their items.
	 */
	func getAllCachedMetadata(inside parent: ItemMetadata) throws -> [ItemMetadata]
	// Returns all items that have a `favoriteRank` or `tagData`.
	func getAllCachedMetadataInsideWorkingSet() throws -> [ItemMetadata]
	func setFavoriteRank(to favoriteRank: Int64?, forItemWithID id: Int64) throws
	func setTagData(to tagData: Data?, forItemWithID id: Int64) throws
}

class ItemMetadataDBManager: ItemMetadataManager {
	private let database: DatabaseWriter

	init(database: DatabaseWriter) {
		self.database = database
	}

	func cacheMetadata(_ metadata: ItemMetadata) throws {
		try database.write { db in
			try cacheMetadata(metadata, database: db)
		}
	}

	func updateMetadata(_ metadata: ItemMetadata) throws {
		try database.write { db in
			try metadata.update(db)
		}
	}

	func cacheMetadata(_ itemMetadataList: [ItemMetadata]) throws {
		try database.write { db in
			for metadata in itemMetadataList {
				try cacheMetadata(metadata, database: db)
			}
		}
	}

	func getCachedMetadata(for cloudPath: CloudPath) throws -> ItemMetadata? {
		let itemMetadata: ItemMetadata? = try database.read { db in
			return try ItemMetadata.filter(ItemMetadata.Columns.cloudPath.lowercased == cloudPath.path.lowercased()).fetchOne(db)
		}
		return itemMetadata
	}

	func getCachedMetadata(for identifier: Int64) throws -> ItemMetadata? {
		let itemMetadata: ItemMetadata? = try database.read { db in
			return try getCachedMetadata(for: identifier, database: db)
		}
		return itemMetadata
	}

	func getPlaceholderMetadata(withParentID parentID: Int64) throws -> [ItemMetadata] {
		let itemMetadata: [ItemMetadata] = try database.read { db in
			return try ItemMetadata
				.filter(ItemMetadata.Columns.parentID == parentID && ItemMetadata.Columns.isPlaceholderItem && ItemMetadata.Columns.id != NSFileProviderItemIdentifier.rootContainerDatabaseValue)
				.fetchAll(db)
		}
		return itemMetadata
	}

	func getCachedMetadata(withParentID parentId: Int64) throws -> [ItemMetadata] {
		let itemMetadata: [ItemMetadata] = try database.read { db in
			return try ItemMetadata
				.filter(ItemMetadata.Columns.parentID == parentId && ItemMetadata.Columns.id != NSFileProviderItemIdentifier.rootContainerDatabaseValue)
				.fetchAll(db)
		}
		return itemMetadata
	}

	// TODO: find a more meaningful name
	func flagAllItemsAsMaybeOutdated(withParentID parentId: Int64) throws {
		_ = try database.write { db in
			try ItemMetadata
				.filter(ItemMetadata.Columns.parentID == parentId && !ItemMetadata.Columns.isPlaceholderItem)
				.updateAll(db, ItemMetadata.Columns.isMaybeOutdated.set(to: true))
		}
	}

	func getMaybeOutdatedItems(withParentID parentId: Int64) throws -> [ItemMetadata] {
		try database.read { db in
			return try ItemMetadata
				.filter(ItemMetadata.Columns.parentID == parentId && ItemMetadata.Columns.isMaybeOutdated)
				.fetchAll(db)
		}
	}

	func removeItemMetadata(with identifier: Int64) throws {
		_ = try database.write { db in
			try ItemMetadata.deleteOne(db, key: identifier)
		}
	}

	func removeItemMetadata(_ identifiers: [Int64]) throws {
		_ = try database.write { db in
			try ItemMetadata.deleteAll(db, keys: identifiers)
		}
	}

	func getCachedMetadata(forIDs ids: [Int64]) throws -> [ItemMetadata] {
		try database.read { db in
			return try ItemMetadata.fetchAll(db, keys: ids)
		}
	}

	func getAllCachedMetadata(inside parent: ItemMetadata) throws -> [ItemMetadata] {
		precondition(parent.type == .folder)
		return try database.read { db in
			let request: QueryInterfaceRequest<ItemMetadata>
			if parent.id == NSFileProviderItemIdentifier.rootContainerDatabaseValue {
				request = ItemMetadata.filter(ItemMetadata.Columns.id != NSFileProviderItemIdentifier.rootContainerDatabaseValue)
			} else {
				request = ItemMetadata.filter(ItemMetadata.Columns.cloudPath.like("\(parent.cloudPath.path + "/")_%"))
			}
			return try request.fetchAll(db)
		}
	}

	func getAllCachedMetadataInsideWorkingSet() throws -> [ItemMetadata] {
		return try database.read { db in
			try ItemMetadata.filter(ItemMetadata.Columns.tagData != nil || ItemMetadata.Columns.favoriteRank != nil).fetchAll(db)
		}
	}

	func setFavoriteRank(to favoriteRank: Int64?, forItemWithID id: Int64) throws {
		try database.write { db in
			let cachedMetadata = try getCachedMetadata(for: id, database: db)
			cachedMetadata?.favoriteRank = favoriteRank
			try cachedMetadata?.update(db)
		}
	}

	func setTagData(to tagData: Data?, forItemWithID id: Int64) throws {
		try database.write { db in
			let cachedMetadata = try getCachedMetadata(for: id, database: db)
			cachedMetadata?.tagData = tagData
			try cachedMetadata?.update(db)
		}
	}

	private func getCachedMetadata(for id: Int64, database: Database) throws -> ItemMetadata? {
		return try ItemMetadata.fetchOne(database, key: id)
	}

	private func cacheMetadata(_ metadata: ItemMetadata, database: Database) throws {
		if let cachedMetadata = try ItemMetadata.fetchOne(database, key: ["cloudPath": metadata.cloudPath]) {
			metadata.id = cachedMetadata.id
			metadata.statusCode = cachedMetadata.statusCode
			metadata.tagData = cachedMetadata.tagData
			metadata.favoriteRank = cachedMetadata.favoriteRank
			try metadata.update(database)
		} else {
			try metadata.insert(database)
		}
	}
}
