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

	 An exactly matching item wins; otherwise the path is case-insensitively checked for equality.

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
		try cacheMetadata([metadata])
	}

	func updateMetadata(_ metadata: ItemMetadata) throws {
		try database.write { db in
			try metadata.update(db)
		}
	}

	func cacheMetadata(_ itemMetadataList: [ItemMetadata]) throws {
		// Sorted because `Dictionary` iteration order is unspecified, and it decides which folder's rows get the lower ids.
		let itemMetadataListByParentID = Dictionary(grouping: itemMetadataList, by: { $0.parentID }).sorted { $0.key < $1.key }
		try database.write { db in
			for (parentID, siblings) in itemMetadataListByParentID {
				try reconcile(siblings, inFolder: parentID, database: db)
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
		guard let parentID = parent.id else {
			throw DBManagerError.nonSavedItemMetadata
		}
		return try database.read { db in
			let rootID = NSFileProviderItemIdentifier.rootContainerDatabaseValue
			if parentID == rootID {
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
			""", arguments: [parentID])
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

	/**
	 Returns every child of the folder, ordered by id so that case-only duplicate siblings resolve to a stable row.

	 Callers match names in Swift rather than SQL: `==` on `String` treats canonically equivalent (NFC/NFD) spellings as equal, whereas SQLite compares bytes and its `NOCASE` collation folds ASCII only. Narrowing this to a `WHERE name = ?` would break that equivalence.
	 */
	private func childrenOfFolder(parentID: Int64, database: Database) throws -> [ItemMetadata] {
		let rootID = NSFileProviderItemIdentifier.rootContainerDatabaseValue
		return try ItemMetadata
			.filter(ItemMetadata.Columns.parentID == parentID && ItemMetadata.Columns.id != rootID)
			.order(ItemMetadata.Columns.id)
			.fetchAll(database)
	}

	private func childOfFolder(parentID: Int64, name: String, database: Database) throws -> ItemMetadata? {
		let children = try childrenOfFolder(parentID: parentID, database: database)
		// Exact spelling wins, so both case-only siblings stay reachable.
		if let exactMatch = children.first(where: { $0.name == name }) {
			return exactMatch
		}
		// Unlike the reconciler's fallback, this one is not gated on `isMaybeOutdated`: lookups resolve any case, they do not decide identity.
		let lowercasedName = name.lowercased()
		return children.first { $0.name.lowercased() == lowercasedName }
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
			WHERE a.id != ? AND a.depth < 1024
		)
		SELECT id, name, depth FROM ancestors ORDER BY depth DESC
		""", arguments: [id, rootID])
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

	/**
	 Reconciles freshly reported items against the folder's cached rows.

	 Names are compared case-sensitively: `Cryptor.encryptFileName(_:dirId:encoding:)` derives a different ciphertext name per case, so case-only siblings are two distinct cloud items. It precomposes to NFC first, so canonically equivalent (NFC/NFD) spellings share one ciphertext name and must resolve to a single item — including two spellings carried by the same listing, which is why freshly inserted rows join the pool.

	 A row that no reported item matches exactly may instead be claimed by a case-insensitive match, but only while it is still flagged as maybe outdated. That flag separates a case-only rename, where the old spelling is gone and the row should keep its id, tag data and favorite rank, from two case variants coexisting, where each is its own item. Placeholders never claim by case, because an item the user is creating right now must not adopt the identity of an existing row.

	 Every exact match resolves before any case-insensitive claim, so which row a given spelling ends up on never depends on where the cloud provider listed it. In a single pass the first-listed spelling of a newly added case variant would claim the row belonging to the other spelling, and the two would swap identities along with tags, favorite rank and cached content. Where both spellings are new to the cache, the listing order still decides which of them inherits the outdated row; both survive either way.
	 */
	private func reconcile(_ itemMetadataList: [ItemMetadata], inFolder parentID: Int64, database: Database) throws {
		assert(itemMetadataList.allSatisfy { $0.parentID == parentID })
		var cachedChildren = try childrenOfFolder(parentID: parentID, database: database)

		func overwrite(_ cached: ItemMetadata, with metadata: ItemMetadata) throws {
			assert(cachedChildren.contains { $0 === cached })
			metadata.id = cached.id
			metadata.statusCode = cached.statusCode
			metadata.tagData = cached.tagData
			metadata.favoriteRank = cached.favoriteRank
			metadata.lastEnumeratedAt = cached.lastEnumeratedAt
			// Clearing the flag is what stops the row being claimed by case again, here and in the remaining pages of the enumeration.
			metadata.isMaybeOutdated = false
			try metadata.update(database)
			if let index = cachedChildren.firstIndex(where: { $0 === cached }) {
				cachedChildren[index] = metadata
			}
		}

		var unmatchedMetadata = [ItemMetadata]()
		for metadata in itemMetadataList {
			if let sameName = cachedChildren.first(where: { $0.name == metadata.name }) {
				try overwrite(sameName, with: metadata)
			} else {
				unmatchedMetadata.append(metadata)
			}
		}

		for metadata in unmatchedMetadata {
			// Rows inserted earlier in this pass are in the pool, so a canonically equivalent spelling later in the same listing merges instead of duplicating.
			if let sameName = cachedChildren.first(where: { $0.name == metadata.name }) {
				try overwrite(sameName, with: metadata)
			} else if !metadata.isPlaceholderItem, let claimed = firstClaimableByCase(named: metadata.name, in: cachedChildren) {
				try overwrite(claimed, with: metadata)
			} else {
				try metadata.insert(database)
				cachedChildren.append(metadata)
			}
		}
	}

	private func firstClaimableByCase(named name: String, in cachedChildren: [ItemMetadata]) -> ItemMetadata? {
		let lowercasedName = name.lowercased()
		return cachedChildren.first { $0.isMaybeOutdated && $0.name.lowercased() == lowercasedName }
	}
}
