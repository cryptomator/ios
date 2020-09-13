//
//  DataBaseHelper.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 21.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation
import GRDB
class DataBaseHelper {
	static func getDBMigratedQueue(at path: String) throws -> DatabaseQueue {
		let dbQueue = try DatabaseQueue(path: path)
		try migrate(dbQueue)
		return dbQueue
	}

	private static func migrate(_ dbQueue: DatabaseQueue) throws {
		var migrator = DatabaseMigrator()
		migrator.registerMigration("v1") { db in
			try db.create(table: "metadata") { table in
				table.autoIncrementedPrimaryKey("id")
				table.column("name", .text).notNull()
				table.column("type", .text).notNull()
				table.column("size", .integer)
				table.column("parentId", .integer).references("metadata")
				table.column("lastModifiedDate", .date)
				table.column("statusCode", .text).notNull()
				table.column("remotePath", .text).unique()
				table.column("isPlaceholderItem", .boolean).notNull().defaults(to: false)
				table.column("isMaybeOutdated", .boolean).notNull().defaults(to: false)
			}

			let rootURL = URL(fileURLWithPath: "/", isDirectory: true)
			let rootFolderMetadata = ItemMetadata(name: "Home", type: .folder, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: rootURL.relativePath, isPlaceholderItem: true)
			try rootFolderMetadata.save(db)
			try db.create(table: "cachedFiles") { table in
				table.column("correspondingItem", .integer).primaryKey(onConflict: .replace).references("metadata")
				table.column("lastModifiedDate", .text)
			}
			try db.create(table: "uploadTasks") { table in
				table.column("correspondingItem", .integer).primaryKey().references("metadata", onDelete: .cascade) // TODO: Add Reference to ItemMetadata Table in Migrator
				table.column(
					"lastFailedUploadDate", .date
				)
				table.column("uploadErrorCode", .integer)
				table.column("uploadErrorDomain", .text)
				table.check(sql: "(lastFailedUploadDate is NULL and uploadErrorCode is NULL and uploadErrorDomain is NULL) OR (lastFailedUploadDate is NOT NULL and uploadErrorCode is NOT NULL and uploadErrorDomain is NOT NULL)")
			}
			try db.create(table: "reparentTasks") { table in
				table.column("correspondingItem", .integer).primaryKey(onConflict: .replace).references("metadata", onDelete: .cascade)
				table.column("oldRemoteURL", .text).notNull()
				table.column("newRemoteURL", .text).notNull()
				table.column("oldParentId", .integer).notNull()
				table.column("newParentId", .integer).notNull()
			}
			try db.create(table: "deletionTasks") { table in
				table.column("correspondingItem", .integer).primaryKey(onConflict: .replace)
				table.column("remoteURL", .text)
				table.column("parentId", .integer).notNull()
			}

			try db.execute(sql: """
			CREATE TRIGGER synchronizeItemStatusLog
			AFTER UPDATE OF statusCode ON metadata
			WHEN new.lastModifiedDate IS NOT NULL AND new.statusCode != 'isDownloaded' AND new.statusCode != 'isUploading'
			BEGIN
				UPDATE metadata SET statusCode = 'isDownloaded'
				WHERE id in (SELECT correspondingItem
				FROM cachedFiles
				WHERE correspondingItem = new.id
				AND lastModifiedDate IS NOT NULL
				AND lastModifiedDate = new.lastModifiedDate
				);
			END;
			""")
		}
		try migrator.migrate(dbQueue)
	}
}
