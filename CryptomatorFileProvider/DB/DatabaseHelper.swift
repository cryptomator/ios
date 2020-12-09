//
//  DatabaseHelper.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 21.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import Foundation
import GRDB
class DatabaseHelper {
	static func getMigratedDB(at databaseURL: URL) throws -> DatabasePool {
		let dbPool = try openSharedDatabase(at: databaseURL)
		try migrate(dbPool)
		return dbPool
	}

	private static func openSharedDatabase(at databaseURL: URL) throws -> DatabasePool {
		let coordinator = NSFileCoordinator(filePresenter: nil)
		var coordinatorError: NSError?
		var dbPool: DatabasePool?
		var dbError: Error?
		coordinator.coordinate(writingItemAt: databaseURL, options: .forMerging, error: &coordinatorError, byAccessor: { _ in
			do {
				dbPool = try DatabasePool(path: databaseURL.path)
			} catch {
				dbError = error
			}
		})
		if let error = dbError ?? coordinatorError {
			throw error
		}
		return dbPool!
	}

	private static func migrate(_ dbPool: DatabasePool) throws {
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
				table.column("cloudPath", .text).unique()
				table.column("isPlaceholderItem", .boolean).notNull().defaults(to: false)
				table.column("isMaybeOutdated", .boolean).notNull().defaults(to: false)
			}

			let rootCloudPath = CloudPath("/")
			let rootFolderMetadata = ItemMetadata(name: "Home", type: .folder, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: rootCloudPath, isPlaceholderItem: true)
			try rootFolderMetadata.save(db)
			try db.create(table: "cachedFiles") { table in
				table.column("correspondingItem", .integer).primaryKey(onConflict: .replace).references("metadata")
				table.column("lastModifiedDate", .text)
				table.column("localLastModifiedDate", .date).notNull()
				table.column("localURL", .text).unique()
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
				table.column("sourceCloudPath", .text).notNull()
				table.column("targetCloudPath", .text).notNull()
				table.column("oldParentId", .integer).notNull()
				table.column("newParentId", .integer).notNull()
			}
			try db.create(table: "deletionTasks") { table in
				table.column("correspondingItem", .integer).primaryKey(onConflict: .replace)
				table.column("cloudPath", .text).notNull()
				table.column("parentId", .integer).notNull()
				table.column("itemType", .text).notNull()
			}
		}
		try migrator.migrate(dbPool)
	}
}
