//
//  GoogleDriveCloudIdentifierCacheManager.swift
//  CloudAccessPrivate
//
//  Created by Philipp Schmid on 11.05.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import Foundation
import GRDB
class GoogleDriveCloudIdentifierCacheManager {
	private let inMemoryDB: DatabaseQueue

	init?() {
		self.inMemoryDB = DatabaseQueue()
		do {
			try inMemoryDB.write { db in
				try db.create(table: GoogleDriveCachedIdentifier.databaseTableName) { table in
					table.column("itemIdentifier", .text)
					table.column("cloudPath", .text).primaryKey()
				}
			}
			try cacheIdentifier("root", for: CloudPath("/"))
		} catch {
			return nil
		}
	}

	func cacheIdentifier(_ identifier: String, for cloudPath: CloudPath) throws {
		try inMemoryDB.write { db in
			if let cachedIdentifier = try GoogleDriveCachedIdentifier.fetchOne(db, key: ["cloudPath": cloudPath]) {
				var updatedCachedIdentifier = cachedIdentifier
				updatedCachedIdentifier.itemIdentifier = identifier
				try updatedCachedIdentifier.updateChanges(db, from: cachedIdentifier)
			} else {
				let newCachedIdentifier = GoogleDriveCachedIdentifier(itemIdentifier: identifier, cloudPath: cloudPath)
				try newCachedIdentifier.insert(db)
			}
		}
	}

	func getIdentifier(for cloudPath: CloudPath) -> String? {
		try? inMemoryDB.read { db in
			let cachedIdentifier = try GoogleDriveCachedIdentifier.fetchOne(db, key: ["cloudPath": cloudPath])
			return cachedIdentifier?.itemIdentifier
		}
	}

	func uncacheIdentifier(for cloudPath: CloudPath) throws {
		try inMemoryDB.write { db in
			if let cachedIdentifier = try GoogleDriveCachedIdentifier.fetchOne(db, key: ["cloudPath": cloudPath]) {
				try cachedIdentifier.delete(db)
			}
		}
	}
}
