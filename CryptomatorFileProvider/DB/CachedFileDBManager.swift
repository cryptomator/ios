//
//  CachedFileDBManager.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 01.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation
import GRDB

protocol CachedFileManager {
	func getLocalCachedFileInfo(for id: Int64) throws -> LocalCachedFileInfo?
	func cacheLocalFileInfo(for id: Int64, localURL: URL, lastModifiedDate: Date?) throws
	func removeCachedFile(for id: Int64) throws
}

extension CachedFileManager {
	func getLocalCachedFileInfo(for itemMetadata: ItemMetadata) throws -> LocalCachedFileInfo? {
		guard let id = itemMetadata.id else {
			throw DBManagerError.nonSavedItemMetadata
		}
		return try getLocalCachedFileInfo(for: id)
	}
}

class CachedFileDBManager: CachedFileManager {
	private let database: DatabaseWriter

	init(database: DatabaseWriter) {
		self.database = database
	}

	func getLocalCachedFileInfo(for id: Int64) throws -> LocalCachedFileInfo? {
		let fetchedEntry = try database.read { db in
			return try LocalCachedFileInfo.fetchOne(db, key: id)
		}
		return fetchedEntry
	}

	func cacheLocalFileInfo(for id: Int64, localURL: URL, lastModifiedDate: Date?) throws {
		try database.write { db in
			try LocalCachedFileInfo(lastModifiedDate: lastModifiedDate, correspondingItem: id, localLastModifiedDate: Date(), localURL: localURL).save(db)
		}
	}

	func removeCachedFile(for id: Int64) throws {
		return try database.write { db in
			guard let entry = try LocalCachedFileInfo.fetchOne(db, key: id) else {
				return
			}
			try entry.delete(db)
			try FileManager.default.removeItem(at: entry.localURL)
		}
	}
}
