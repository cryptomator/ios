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
				table.autoIncrementedPrimaryKey("id")
				table.column("name", .text).notNull()
				table.column("type", .text).notNull()
				table.column("size", .integer)
				table.column("parentId", .integer).notNull()
				table.column("lastModifiedDate", .date)
				table.column("statusCode", .integer).notNull()
				table.column("remotePath", .text).unique()
				table.column("isPlaceholderItem", .boolean).notNull().defaults(to: false)
			}
			let rootURL = URL(fileURLWithPath: "/", isDirectory: true)
			let rootFolderMetadata = ItemMetadata(name: "Home", type: .folder, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: rootURL.relativePath, isPlaceholderItem: false)
			try rootFolderMetadata.save(db)
		}
	}

	func cacheMetadata(_ metadata: ItemMetadata) throws {
		if let cachedMetadata = try getCachedMetadata(for: metadata.remotePath) {
			metadata.id = cachedMetadata.id
			try updateMetadata(metadata)
		} else {
			try dbQueue.write { db in
				try metadata.save(db)
			}
		}
	}

	func updateMetadata(_ metadata: ItemMetadata) throws {
		try dbQueue.write { db in
			try metadata.update(db)
		}
	}

	// TODO: Optimize Code and/or DB Scheme
	func cacheMetadatas(_ metadatas: [ItemMetadata]) throws {
		try dbQueue.inTransaction { db in
			for metadata in metadatas {
				if let cachedMetadata = try ItemMetadata.fetchOne(db, key: ["remotePath": metadata.remotePath]) {
					metadata.id = cachedMetadata.id
					try metadata.update(db)
				} else {
					try metadata.insert(db)
				}
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

	func removeItemMetadata(with identifier: Int64) throws {
		_ = try dbQueue.write { db in
			try ItemMetadata.deleteOne(db, key: identifier)
		}
	}

	func cachePlaceholderMetadata(_ metadata: ItemMetadata) throws {
		_ = try dbQueue.write { _ in
		}
	}

	func resolveLocalNameCollision(for metadata: ItemMetadata) throws {
		let remoteURL = URL(fileURLWithPath: metadata.remotePath, isDirectory: metadata.type == .folder)
	}
}
