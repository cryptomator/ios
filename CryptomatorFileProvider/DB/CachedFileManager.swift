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
	static let databaseTableName = "cachedFiles"
	static let lastModifiedDateKey = "lastModifiedDate"
	static let correspondingItemKey = "correspondingItem"
	static let localLastModifiedDateKey = "localLastModifiedDate"
	let lastModifiedDate: Date?
	let correspondingItem: Int64
	let localLastModifiedDate: Date
}

extension CachedEntry: PersistableRecord {
	func encode(to container: inout PersistenceContainer) {
		container[CachedEntry.lastModifiedDateKey] = lastModifiedDate
		container[CachedEntry.correspondingItemKey] = correspondingItem
		container[CachedEntry.localLastModifiedDateKey] = localLastModifiedDate
	}
}

class CachedFileManager {
	let dbPool: DatabasePool

	init(with dbPool: DatabasePool) {
		self.dbPool = dbPool
	}

	func hasCurrentVersionLocal(for identifier: Int64, with lastModifiedDateInCloud: Date?) throws -> Bool {
		guard let lastModifiedDateInCloud = lastModifiedDateInCloud else {
			return false
		}
		let fetchedEntry = try dbPool.read { db in
			return try CachedEntry.fetchOne(db, key: identifier)
		}
		guard let cachedEntry = fetchedEntry, let lastModifiedDateLocal = cachedEntry.lastModifiedDate else {
			return false
		}
		return Calendar(identifier: .gregorian).isDate(lastModifiedDateLocal, equalTo: lastModifiedDateInCloud, toGranularity: .second)
	}

	func getLastModifiedDate(for identifier: Int64) throws -> Date? {
		let fetchedEntry = try dbPool.read { db in
			return try CachedEntry.fetchOne(db, key: identifier)
		}
		return fetchedEntry?.lastModifiedDate
	}

	func getLocalLastModifiedDate(for identifier: Int64) throws -> Date? {
		let fetchedEntry = try dbPool.read { db in
			return try CachedEntry.fetchOne(db, key: identifier)
		}
		return fetchedEntry?.localLastModifiedDate
	}

	func cacheLocalFileInfo(for identifier: Int64, lastModifiedDate: Date?) throws {
		try dbPool.write { db in
			try CachedEntry(lastModifiedDate: lastModifiedDate, correspondingItem: identifier, localLastModifiedDate: Date()).save(db)
		}
	}

	func removeCachedFile(for identifier: Int64, at localURL: URL) throws {
		return try dbPool.write { db in
			if let entry = try CachedEntry.fetchOne(db, key: identifier) {
				try FileManager.default.removeItem(at: localURL)
				try entry.delete(db)
			}
		}
	}
}
