//
//  CachedFileManager.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 01.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation
import GRDB

private struct CachedEntry: Decodable, FetchableRecord, TableRecord {
	static let databaseTableName = "entries"
	static let lastModifiedDateKey = "lastModifiedDate"
	static let correspondingItemKey = "correspondingItem"
	let lastModifiedDate: Date?
	let correspondingItem: Int64
}

extension CachedEntry: PersistableRecord {
	func encode(to container: inout PersistenceContainer) {
		container[CachedEntry.lastModifiedDateKey] = lastModifiedDate
		container[CachedEntry.correspondingItemKey] = correspondingItem
	}
}

class CachedFileManager {
	/* let dbPool: DatabasePool

	 init(with dbPool: DatabasePool) {
	 	self.dbPool = dbPool
	 } */
	// TODO: use later a DB Pool.. dbQueue is only for demo as it supports in-memory DB
	let dbQueue: DatabaseQueue
	init(with dbQueue: DatabaseQueue) throws {
		self.dbQueue = dbQueue
		// TODO: Use Migrator to create DB
		try dbQueue.write { db in
			try db.create(table: CachedEntry.databaseTableName) { table in
				table.column(CachedEntry.correspondingItemKey, .integer).primaryKey(onConflict: .replace).references(ItemMetadata.databaseTableName) // TODO: Add Reference to ItemMetadata Table in Migrator
				table.column(CachedEntry.lastModifiedDateKey, .text)
			}
		}
	}

	func hasCurrentVersionLocal(for identifier: Int64, with lastModifiedDateInCloud: Date) throws -> Bool {
		let fetchedEntry = try dbQueue.read { db in
			return try CachedEntry.fetchOne(db, key: identifier)
		}
		guard let cachedEntry = fetchedEntry, let lastModifiedDateLocal = cachedEntry.lastModifiedDate else {
			return false
		}
		return lastModifiedDateLocal == lastModifiedDateInCloud
	}

	func getLastModifiedDate(for identifier: Int64) throws -> Date? {
		let fetchedEntry = try dbQueue.read { db in
			return try CachedEntry.fetchOne(db, key: identifier)
		}
		return fetchedEntry?.lastModifiedDate
	}

	func cacheLocalFileInfo(for identifier: Int64, lastModifiedDate: Date?) throws {
		try dbQueue.write { db in
			try CachedEntry(lastModifiedDate: lastModifiedDate, correspondingItem: identifier).save(db)
		}
	}

	/**
	 - returns: `true` If an entry was really deleted. `false` If an entry did not exist.
	 */
	func removeCachedEntry(for identifier: Int64) throws -> Bool {
		return try dbQueue.write { db in
			let hasDeletedEntry = try CachedEntry.deleteOne(db, key: identifier)
			return hasDeletedEntry
		}
	}
}
