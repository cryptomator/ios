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
	func getRootContainerID() -> Int64
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

extension ItemMetadataManager {
	func getRootContainerID() -> Int64 {
		1
	}
}

class ItemMetadataDBManager: ItemMetadataManager {
	static func getRootContainerID() -> Int64 {
		rootContainerId
	}

	private let database: DatabaseWriter
	static let rootContainerId: Int64 = 1

	init(database: DatabaseWriter) {
		self.database = database
	}

	func cacheMetadata(_ metadata: ItemMetadata) throws {
		if let cachedMetadata = try getCachedMetadata(for: metadata.cloudPath) {
			metadata.id = cachedMetadata.id
			metadata.statusCode = cachedMetadata.statusCode
			metadata.tagData = cachedMetadata.tagData
			metadata.favoriteRank = cachedMetadata.favoriteRank
			try updateMetadata(metadata)
		} else {
			try database.write { db in
				try metadata.save(db)
			}
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
				try db.execute(
					sql: """
					INSERT INTO \(ItemMetadata.databaseTableName)
					(\(ItemMetadata.Columns.name), \(ItemMetadata.Columns.type), \(ItemMetadata.Columns.size), \(ItemMetadata.Columns.parentID), \(ItemMetadata.Columns.lastModifiedDate), \(ItemMetadata.Columns.statusCode), \(ItemMetadata.Columns.cloudPath), \(ItemMetadata.Columns.isPlaceholderItem), \(ItemMetadata.Columns.isMaybeOutdated), \(ItemMetadata.Columns.favoriteRank), \(ItemMetadata.Columns.tagData)) VALUES
					(:name, :type, :size, :parentID, :lastModifiedDate, :statusCode, :cloudPath, :isPlaceholderItem, :isMaybeOutdated, :favoriteRank, :tagData)
					ON CONFLICT (\(ItemMetadata.Columns.cloudPath))
					DO UPDATE SET \(ItemMetadata.Columns.name) = excluded.\(ItemMetadata.Columns.name),
					\(ItemMetadata.Columns.type) = excluded.\(ItemMetadata.Columns.type),
					\(ItemMetadata.Columns.size) = excluded.\(ItemMetadata.Columns.size),
					\(ItemMetadata.Columns.parentID) = excluded.\(ItemMetadata.Columns.parentID),
					\(ItemMetadata.Columns.lastModifiedDate) = excluded.\(ItemMetadata.Columns.lastModifiedDate),
					\(ItemMetadata.Columns.cloudPath) = excluded.\(ItemMetadata.Columns.cloudPath),
					\(ItemMetadata.Columns.isPlaceholderItem) = excluded.\(ItemMetadata.Columns.isPlaceholderItem),
					\(ItemMetadata.Columns.isMaybeOutdated) = excluded.\(ItemMetadata.Columns.isMaybeOutdated)
					""",
					arguments: ["name": metadata.name,
					            "type": metadata.type,
					            "size": metadata.size,
					            "parentID": metadata.parentID,
					            "lastModifiedDate": metadata.lastModifiedDate,
					            "statusCode": metadata.statusCode,
					            "cloudPath": metadata.cloudPath,
					            "isPlaceholderItem": metadata.isPlaceholderItem,
					            "isMaybeOutdated": metadata.isMaybeOutdated,
					            "favoriteRank": metadata.favoriteRank,
					            "tagData": metadata.tagData]
				)
				let metadataID = db.lastInsertedRowID
				metadata.id = metadataID
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
				.filter(ItemMetadata.Columns.parentID == parentID && ItemMetadata.Columns.isPlaceholderItem && ItemMetadata.Columns.id != ItemMetadataDBManager.rootContainerId)
				.fetchAll(db)
		}
		return itemMetadata
	}

	func getCachedMetadata(withParentID parentId: Int64) throws -> [ItemMetadata] {
		let itemMetadata: [ItemMetadata] = try database.read { db in
			return try ItemMetadata
				.filter(ItemMetadata.Columns.parentID == parentId && ItemMetadata.Columns.id != ItemMetadataDBManager.rootContainerId)
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
			if parent.id == ItemMetadataDBManager.rootContainerId {
				request = ItemMetadata.filter(ItemMetadata.Columns.id != ItemMetadataDBManager.rootContainerId)
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
}
