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
	/// Resolves the cloud path by walking the `parentID` chain to root.
	func getCloudPath(for id: Int64) throws -> CloudPath
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
	 Returns every descendant of the given folder, walking the `parentID` chain downward (deep, not just direct children).
	 */
	func getAllCachedMetadata(inside parent: ItemMetadata) throws -> [ItemMetadata]
	// Returns all items that have a `favoriteRank` or `tagData`.
	func getAllCachedMetadataInsideWorkingSet() throws -> [ItemMetadata]
	func setFavoriteRank(to favoriteRank: Int64?, forItemWithID id: Int64) throws
	func setTagData(to tagData: Data?, forItemWithID id: Int64) throws
	func setLastEnumeratedAt(_ date: Date, forItemWithID id: Int64) throws
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

	func getCloudPath(for id: Int64) throws -> CloudPath {
		return try database.read { db in
			try resolveCloudPath(for: id, database: db)
		}
	}

	func getCachedMetadata(for cloudPath: CloudPath) throws -> ItemMetadata? {
		return try database.read { db in
			try resolveMetadata(for: cloudPath, database: db)
		}
	}

	func getCachedMetadata(for identifier: Int64) throws -> ItemMetadata? {
		return try database.read { db in
			return try getCachedMetadata(for: identifier, database: db)
		}
	}

	func getPlaceholderMetadata(withParentID parentID: Int64) throws -> [ItemMetadata] {
		return try database.read { db in
			return try ItemMetadata
				.filter(ItemMetadata.Columns.parentID == parentID && ItemMetadata.Columns.isPlaceholderItem && ItemMetadata.Columns.id != NSFileProviderItemIdentifier.rootContainerDatabaseValue)
				.fetchAll(db)
		}
	}

	func getCachedMetadata(withParentID parentId: Int64) throws -> [ItemMetadata] {
		return try database.read { db in
			return try ItemMetadata
				.filter(ItemMetadata.Columns.parentID == parentId && ItemMetadata.Columns.id != NSFileProviderItemIdentifier.rootContainerDatabaseValue)
				.fetchAll(db)
		}
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
			let rootID = NSFileProviderItemIdentifier.rootContainerDatabaseValue
			if parent.id == rootID {
				return try ItemMetadata.filter(ItemMetadata.Columns.id != rootID).fetchAll(db)
			}
			return try ItemMetadata.fetchAll(db, sql: """
			WITH RECURSIVE descendants(id, depth) AS (
				SELECT id, 0 FROM itemMetadata WHERE parentID = ? AND id != parentID
				UNION ALL
				SELECT m.id, d.depth + 1
				FROM itemMetadata m
				JOIN descendants d ON m.parentID = d.id
				WHERE d.depth < 1024
			)
			SELECT * FROM itemMetadata WHERE id IN (SELECT id FROM descendants)
			""", arguments: [parent.id!])
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

	func setLastEnumeratedAt(_ date: Date, forItemWithID id: Int64) throws {
		try database.write { db in
			let cachedMetadata = try getCachedMetadata(for: id, database: db)
			cachedMetadata?.lastEnumeratedAt = date
			try cachedMetadata?.update(db)
		}
	}

	private func getCachedMetadata(for id: Int64, database: Database) throws -> ItemMetadata? {
		return try ItemMetadata.fetchOne(database, key: id)
	}

	private func childOfFolder(parentID: Int64, name: String, database: Database) throws -> ItemMetadata? {
		let rootID = NSFileProviderItemIdentifier.rootContainerDatabaseValue
		let lowercasedName = name.lowercased()
		let siblings = try ItemMetadata
			.filter(ItemMetadata.Columns.parentID == parentID && ItemMetadata.Columns.id != rootID)
			.fetchAll(database)
		return siblings.first { $0.name.lowercased() == lowercasedName }
	}

	private func resolveMetadata(for cloudPath: CloudPath, database db: Database) throws -> ItemMetadata? {
		let rootID = NSFileProviderItemIdentifier.rootContainerDatabaseValue
		if cloudPath == CloudPath("/") {
			return try ItemMetadata.fetchOne(db, key: rootID)
		}
		let components = cloudPath.pathComponents.dropFirst()
		var currentID = rootID
		var current: ItemMetadata?
		for component in components {
			guard let child = try childOfFolder(parentID: currentID, name: String(component), database: db) else {
				return nil
			}
			currentID = child.id!
			current = child
		}
		return current
	}

	private func resolveCloudPath(for id: Int64, database db: Database) throws -> CloudPath {
		let rootID = NSFileProviderItemIdentifier.rootContainerDatabaseValue
		if id == rootID {
			return CloudPath("/")
		}
		let rows = try Row.fetchAll(db, sql: """
		WITH RECURSIVE ancestors(id, parentID, name, depth) AS (
			SELECT id, parentID, name, 0 FROM itemMetadata WHERE id = ?
			UNION ALL
			SELECT m.id, m.parentID, m.name, a.depth + 1
			FROM itemMetadata m
			JOIN ancestors a ON m.id = a.parentID
			WHERE a.id != 1 AND a.depth < 1024
		)
		SELECT id, name, depth FROM ancestors ORDER BY depth DESC
		""", arguments: [id])
		guard !rows.isEmpty else {
			throw FileProviderAdapterError.itemNotFound
		}
		// Chain must terminate at root; otherwise it's a cycle or orphan.
		let topRow = rows.first!
		let topID: Int64 = topRow["id"]
		if topID != rootID {
			throw FileProviderAdapterError.unresolvableParentChain
		}
		let names: [String] = rows.dropFirst().map { $0["name"] }
		return names.reduce(CloudPath("/")) { $0.appendingPathComponent($1) }
	}

	private func cacheMetadata(_ metadata: ItemMetadata, database: Database) throws {
		let cached = try childOfFolder(parentID: metadata.parentID, name: metadata.name, database: database)
		if let cached = cached {
			metadata.id = cached.id
			metadata.statusCode = cached.statusCode
			metadata.tagData = cached.tagData
			metadata.favoriteRank = cached.favoriteRank
			metadata.lastEnumeratedAt = cached.lastEnumeratedAt
			try metadata.update(database)
		} else {
			try metadata.insert(database)
		}
	}
}
