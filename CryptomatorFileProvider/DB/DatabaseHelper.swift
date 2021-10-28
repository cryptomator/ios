//
//  DatabaseHelper.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 21.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import FileProvider
import Foundation
import GRDB

public enum DatabaseHelper {
	public static func getDatabaseURL(for domain: NSFileProviderDomain) -> URL {
		let documentStorageURL = NSFileProviderManager.default.documentStorageURL
		let domainRootURL = documentStorageURL.appendingPathComponent(domain.pathRelativeToDocumentStorage)
		return domainRootURL.appendingPathComponent("db.sqlite")
	}

	public static func getMigratedDB(at databaseURL: URL) throws -> DatabasePool {
		let dbPool = try openSharedDatabase(at: databaseURL)
		try migrate(dbPool)
		return dbPool
	}

	// swiftlint:disable:next function_body_length
	static func migrate(_ dbWriter: DatabaseWriter) throws {
		var migrator = DatabaseMigrator()
		#if DEBUG
		// Speed up development by nuking the database when migrations change
		// See https://github.com/groue/GRDB.swift/blob/master/Documentation/Migrations.md#the-erasedatabaseonschemachange-option
		migrator.eraseDatabaseOnSchemaChange = true
		#endif
		migrator.registerMigration("v1") { db in
			try db.create(table: "itemMetadata") { table in
				table.autoIncrementedPrimaryKey("id")
				table.column("name", .text).notNull()
				table.column("type", .text).notNull()
				table.column("size", .integer)
				table.column("parentID", .integer).references("itemMetadata", onDelete: .cascade)
				table.column("lastModifiedDate", .date)
				table.column("statusCode", .text).notNull()
				table.column("cloudPath", .text).unique()
				table.column("isPlaceholderItem", .boolean).notNull().defaults(to: false)
				table.column("isMaybeOutdated", .boolean).notNull().defaults(to: false)
			}

			let rootCloudPath = CloudPath("/")
			let rootFolderMetadata = ItemMetadata(name: "Home", type: .folder, size: nil, parentID: 1, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: rootCloudPath, isPlaceholderItem: true)
			try rootFolderMetadata.save(db)
			try db.create(table: "cachedFiles") { table in
				table.column("correspondingItem", .integer).primaryKey(onConflict: .replace).references("itemMetadata")
				table.column("lastModifiedDate", .text)
				table.column("localLastModifiedDate", .date).notNull()
				table.column("localURL", .text).unique()
			}
			try db.create(table: "uploadTasks") { table in
				table.column("correspondingItem", .integer).primaryKey().references("itemMetadata", onDelete: .cascade)
				table.column(
					"lastFailedUploadDate", .date
				)
				table.column("uploadErrorCode", .integer)
				table.column("uploadErrorDomain", .text)
				table.check(sql: "(lastFailedUploadDate is NULL and uploadErrorCode is NULL and uploadErrorDomain is NULL) OR (lastFailedUploadDate is NOT NULL and uploadErrorCode is NOT NULL and uploadErrorDomain is NOT NULL)")
			}
			try db.create(table: "reparentTasks") { table in
				table.column("correspondingItem", .integer).primaryKey(onConflict: .replace).references("itemMetadata", onDelete: .cascade)
				table.column("sourceCloudPath", .text).notNull()
				table.column("targetCloudPath", .text).notNull()
				table.column("oldParentId", .integer).notNull()
				table.column("newParentId", .integer).notNull()
			}
			try db.create(table: "deletionTasks") { table in
				table.column("correspondingItem", .integer).primaryKey(onConflict: .replace).references("itemMetadata", onDelete: .cascade)
				table.column("cloudPath", .text).notNull()
				table.column("parentID", .integer).notNull()
				table.column("itemType", .text).notNull()
			}
			try db.create(table: "itemEnumerationTasks") { table in
				table.column("correspondingItem", .integer).primaryKey(onConflict: .replace).references("itemMetadata", onDelete: .cascade)
				table.column("pageToken", .text)
			}
			try db.create(table: "downloadTasks") { table in
				table.column("correspondingItem", .integer).primaryKey(onConflict: .replace).references("itemMetadata", onDelete: .cascade)
				table.column("replaceExisting", .boolean).notNull()
				table.column("localURL", .text).notNull()
			}

			// Single-Row Table (see: https://github.com/groue/GRDB.swift/blob/32b2923e890df320906e64cbd0faca22a8bfda14/Documentation/SingleRowTables.md)
			try db.create(table: "maintenanceMode") { table in
				table.column("id", .integer).primaryKey(onConflict: .replace).check { $0 == 1 }
				table.column("flag", .boolean).notNull()
			}

			try db.execute(sql: """
			CREATE TRIGGER uploadTasks_prevent_insert_on_maintenance_mode
			BEFORE INSERT
			ON uploadTasks
			BEGIN
				SELECT RAISE(ABORT, 'Maintenance Mode')
				WHERE EXISTS (SELECT 1 FROM maintenanceMode WHERE flag = 1);
			END;
			""")

			try db.execute(sql: """
			CREATE TRIGGER reparentTasks_prevent_insert_on_maintenance_mode
			BEFORE INSERT
			ON reparentTasks
			BEGIN
				SELECT RAISE(ABORT, 'Maintenance Mode')
				WHERE EXISTS (SELECT 1 FROM maintenanceMode WHERE flag = 1);
			END;
			""")

			try db.execute(sql: """
			CREATE TRIGGER deletionTasks_prevent_insert_on_maintenance_mode
			BEFORE INSERT
			ON deletionTasks
			BEGIN
				SELECT RAISE(ABORT, 'Maintenance Mode')
				WHERE EXISTS (SELECT 1 FROM maintenanceMode WHERE flag = 1);
			END;
			""")

			try db.execute(sql: """
			CREATE TRIGGER itemEnumerationTasks_prevent_insert_on_maintenance_mode
			BEFORE INSERT
			ON itemEnumerationTasks
			BEGIN
				SELECT RAISE(ABORT, 'Maintenance Mode')
				WHERE EXISTS (SELECT 1 FROM maintenanceMode WHERE flag = 1);
			END;
			""")

			try db.execute(sql: """
			CREATE TRIGGER downloadTasks_prevent_insert_on_maintenance_mode
			BEFORE INSERT
			ON downloadTasks
			BEGIN
				SELECT RAISE(ABORT, 'Maintenance Mode')
				WHERE EXISTS (SELECT 1 FROM maintenanceMode WHERE flag = 1);
			END;
			""")

			try db.execute(sql: """
			CREATE TRIGGER maintenanceMode_prevent_insert_true_on_running_task
			BEFORE INSERT
			ON maintenanceMode
			FOR EACH ROW
			WHEN NEW.flag = 1
			BEGIN
				SELECT RAISE(ABORT, 'Running Task')
				WHERE EXISTS (SELECT 1 FROM uploadTasks WHERE uploadErrorCode IS NULL)
				OR EXISTS (SELECT 1 FROM reparentTasks)
				OR EXISTS (SELECT 1 FROM deletionTasks)
				OR EXISTS (SELECT 1 FROM itemEnumerationTasks)
				OR EXISTS (SELECT 1 FROM downloadTasks);
			END;
			""")

			try db.execute(sql: """
			CREATE TRIGGER maintenanceMode_prevent_update_to_true_on_running_task
			BEFORE UPDATE
			ON maintenanceMode
			FOR EACH ROW
			WHEN NEW.flag = 1
			BEGIN
				SELECT RAISE(ABORT, 'Running Task')
				WHERE EXISTS (SELECT 1 FROM uploadTasks WHERE uploadErrorCode IS NULL)
				OR EXISTS (SELECT 1 FROM reparentTasks)
				OR EXISTS (SELECT 1 FROM deletionTasks)
				OR EXISTS (SELECT 1 FROM itemEnumerationTasks)
				OR EXISTS (SELECT 1 FROM downloadTasks);
			END;
			""")
		}
		try migrator.migrate(dbWriter)
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
}
