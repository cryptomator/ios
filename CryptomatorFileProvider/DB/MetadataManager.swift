//
//  MetadataManager.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 24.06.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import FileProvider
import Foundation
import GRDB
class MetadataManager {
	private let dbQueue: DatabaseQueue
	static let rootContainerId: Int64 = 1
	init(with dbQueue: DatabaseQueue) throws {
		self.dbQueue = dbQueue
		// TODO: Use Migrator to create DB
		try dbQueue.write { db in
			try db.create(table: ItemMetadata.databaseTableName) { table in
				table.column("name", .text).notNull()
				table.column("type", .text).notNull()
				table.column("size", .integer)
				table.column("parentId", .integer).notNull()
				table.column("lastModifiedDate", .date)
				table.column("statusCode", .integer).notNull()
				table.column("remotePath", .text).unique(onConflict: .replace)
				table.column("isPlaceholderItem", .boolean).notNull().defaults(to: false)
			}
			let rootURL = URL(fileURLWithPath: "/", isDirectory: true)
			let rootFolderMetadata = ItemMetadata(name: "Home", type: .folder, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: rootURL.relativePath, isPlaceholderItem: false)
			try rootFolderMetadata.save(db)
		}
	}

	func cacheMetadata(_ metadata: ItemMetadata) throws {
		try dbQueue.write { db in
			try metadata.save(db)
		}
	}

	func cacheMetadatas(_ metadatas: [ItemMetadata]) throws {
		try dbQueue.inTransaction { db in
			for metadata in metadatas {
				try metadata.insert(db)
			}
			return .commit
		}
	}

	func getCachedMetadata(for remotePath: String) throws -> ItemMetadata? {
		let itemMetadata: ItemMetadata? = try dbQueue.read { db in
			return try ItemMetadata.fetchOne(db, key: ["remotePath": remotePath])
		}
		return itemMetadata
	}

	func getCachedMetadata(for identifier: Int64) throws -> ItemMetadata? {
		let itemMetadata: ItemMetadata? = try dbQueue.read { db in
			return try ItemMetadata.fetchOne(db, key: identifier)
		}
		return itemMetadata
	}

	func getPlaceholderMetadata(for parentId: Int64) throws -> [ItemMetadata] {
		let itemMetadata: [ItemMetadata] = try dbQueue.read { db in
			return try ItemMetadata
				.filter(Column("parentId") == parentId && Column("isPlaceholderItem"))
				.fetchAll(db)
		}
		return itemMetadata
	}
}
