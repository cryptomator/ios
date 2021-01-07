//
//  CachedFileManager.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 01.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation
import GRDB

struct LocalCachedFileInfo: Decodable, FetchableRecord, TableRecord {
	static let databaseTableName = "cachedFiles"
	static let lastModifiedDateKey = "lastModifiedDate"
	static let correspondingItemKey = "correspondingItem"
	static let localLastModifiedDateKey = "localLastModifiedDate"
	static let localURLKey = "localURL"
	let lastModifiedDate: Date?
	let correspondingItem: Int64
	let localLastModifiedDate: Date
	let localURL: URL
}

extension LocalCachedFileInfo: PersistableRecord {
	func encode(to container: inout PersistenceContainer) {
		container[LocalCachedFileInfo.lastModifiedDateKey] = lastModifiedDate
		container[LocalCachedFileInfo.correspondingItemKey] = correspondingItem
		container[LocalCachedFileInfo.localLastModifiedDateKey] = localLastModifiedDate
		container[LocalCachedFileInfo.localURLKey] = localURL
	}
}

extension LocalCachedFileInfo {
	func isCurrentVersion(lastModifiedDateInCloud: Date?) -> Bool {
		guard let lastModifiedDateInCloud = lastModifiedDateInCloud, let lastModifiedDateLocal = lastModifiedDate else {
			return false
		}
		return Calendar(identifier: .gregorian).isDate(lastModifiedDateLocal, equalTo: lastModifiedDateInCloud, toGranularity: .second)
	}
}

class CachedFileManager {
	let dbPool: DatabasePool

	init(with dbPool: DatabasePool) {
		self.dbPool = dbPool
	}

	func getLocalCachedFileInfo(for identifier: Int64) throws -> LocalCachedFileInfo? {
		let fetchedEntry = try dbPool.read { db in
			return try LocalCachedFileInfo.fetchOne(db, key: identifier)
		}
		return fetchedEntry
	}

	func getLastModifiedDate(for identifier: Int64) throws -> Date? {
		let fetchedEntry = try dbPool.read { db in
			return try LocalCachedFileInfo.fetchOne(db, key: identifier)
		}
		return fetchedEntry?.lastModifiedDate
	}

	func getLocalLastModifiedDate(for identifier: Int64) throws -> Date? {
		let fetchedEntry = try dbPool.read { db in
			return try LocalCachedFileInfo.fetchOne(db, key: identifier)
		}
		return fetchedEntry?.localLastModifiedDate
	}

	func cacheLocalFileInfo(for identifier: Int64, localURL: URL, lastModifiedDate: Date?) throws {
		try dbPool.write { db in
			try LocalCachedFileInfo(lastModifiedDate: lastModifiedDate, correspondingItem: identifier, localLastModifiedDate: Date(), localURL: localURL).save(db)
		}
	}

	func getLocalURL(for identifier: Int64) throws -> URL? {
		let fetchedEntry = try dbPool.read { db in
			return try LocalCachedFileInfo.fetchOne(db, key: identifier)
		}
		return fetchedEntry?.localURL
	}

	func removeCachedFile(for identifier: Int64) throws {
		return try dbPool.write { db in
			if let entry = try LocalCachedFileInfo.fetchOne(db, key: identifier) {
				try FileManager.default.removeItem(at: entry.localURL)
				try entry.delete(db)
			}
		}
	}
}
