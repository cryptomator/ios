//
//  CryptomatorDatabase.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 07.11.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation
import GRDB

public enum CryptomatorDatabaseError: Error {
	case dbDoesNotExist
	case incompleteMigration
}

public class CryptomatorDatabase {
	public static var shared: CryptomatorDatabase!
	public static var sharedDBURL: URL? {
		let sharedContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: CryptomatorConstants.appGroupName)
		return sharedContainer?.appendingPathComponent("main.sqlite")
	}

	public let dbPool: DatabasePool

	public init(_ dbPool: DatabasePool) throws {
		self.dbPool = dbPool
		try CryptomatorDatabase.migrator.migrate(dbPool)
	}

	static var migrator: DatabaseMigrator {
		var migrator = DatabaseMigrator()

		// Speed up development by nuking the database when migrations change
		// See https://github.com/groue/GRDB.swift/blob/master/Documentation/Migrations.md#the-erasedatabaseonschemachange-option
		migrator.eraseDatabaseOnSchemaChange = true

		migrator.registerMigration("v1") { db in
			try v1Migration(db)
		}
		return migrator
	}

	// swiftlint:disable:next function_body_length
	public class func v1Migration(_ db: Database) throws {
		// Common
		try db.create(table: "cloudProviderAccounts") { table in
			table.column("accountUID", .text).primaryKey()
			table.column("cloudProviderType", .text).notNull()
		}
		try db.create(table: "vaultAccounts") { table in
			table.column("vaultUID", .text).primaryKey()
			table.column("delegateAccountUID", .text).notNull().references("cloudProviderAccounts", onDelete: .cascade)
			table.column("vaultPath", .text).notNull()
			table.column("vaultName", .text).notNull()
			table.uniqueKey(["delegateAccountUID", "vaultPath"])
		}
		try db.create(table: "cachedVaults") { table in
			table.column("vaultUID", .text).primaryKey().references("vaultAccounts", onDelete: .cascade)
			table.column("masterkeyFileData", .text).notNull()
			table.column("vaultConfigToken", .text)
			table.column("lastUpToDateCheck", .date).notNull()
		}
		// Main App
		try db.create(table: "vaultListPosition") { table in
			table.column("position", .integer).unique()
			table.column("vaultUID", .text).unique().notNull().references("vaultAccounts", onDelete: .cascade)
			table.check(Column("position") != nil)
		}
		try db.execute(sql: """
		CREATE TRIGGER position_creation
		AFTER INSERT
		ON vaultAccounts
		BEGIN
			INSERT INTO vaultListPosition (position, vaultUID)
			VALUES (IFNULL((SELECT MAX(position) FROM vaultListPosition), -1)+1, NEW.vaultUID);
		END;
		""")

		try db.execute(sql: """
		CREATE TRIGGER position_update
		AFTER DELETE
		ON vaultListPosition
		BEGIN
			UPDATE vaultListPosition
			SET position = position - 1
			WHERE position > OLD.position;
		END;
		""")

		try db.create(table: "accountListPosition") { table in
			table.column("position", .integer)
			table.column("cloudProviderType", .text)
			table.column("accountUID", .text).unique().notNull().references("cloudProviderAccounts", onDelete: .cascade)
			table.uniqueKey(["position", "cloudProviderType"])
			table.check(Column("position") != nil && Column("cloudProviderType") != nil)
		}
		try db.execute(sql: """
		CREATE TRIGGER accountList_position_creation
		AFTER INSERT
		ON cloudProviderAccounts
		BEGIN
			INSERT INTO accountListPosition (position, cloudProviderType, accountUID)
			VALUES (IFNULL((SELECT MAX(position) FROM accountListPosition WHERE cloudProviderType = NEW.cloudProviderType), -1)+1, NEW.cloudProviderType, NEW.accountUID);
		END;
		""")

		try db.execute(sql: """
		CREATE TRIGGER accountList_position_update
		AFTER DELETE
		ON accountListPosition
		BEGIN
			UPDATE accountListPosition
			SET position = position - 1
			WHERE position > OLD.position AND cloudProviderType = OLD.cloudProviderType;
		END;
		""")
	}

	public static func openSharedDatabase(at databaseURL: URL) throws -> DatabasePool {
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

	public static func openSharedReadOnlyDatabase(at databaseURL: URL) throws -> DatabasePool {
		let coordinator = NSFileCoordinator(filePresenter: nil)
		var coordinatorError: NSError?
		var dbPool: DatabasePool?
		var dbError: Error?
		coordinator.coordinate(readingItemAt: databaseURL, options: .withoutChanges, error: &coordinatorError, byAccessor: { url in
			do {
				dbPool = try openReadOnlyDatabase(at: url)
			} catch {
				dbError = error
			}
		})
		if let error = dbError ?? coordinatorError {
			throw error
		}
		return dbPool!
	}

	private static func openReadOnlyDatabase(at databaseURL: URL) throws -> DatabasePool {
		do {
			var configuration = Configuration()
			configuration.readonly = true
			let dbPool = try DatabasePool(path: databaseURL.path, configuration: configuration)

			if try dbPool.read(migrator.hasCompletedMigrations) {
				return dbPool
			} else {
				throw CryptomatorDatabaseError.incompleteMigration
			}
		} catch {
			if FileManager.default.fileExists(atPath: databaseURL.path) {
				throw error
			} else {
				throw CryptomatorDatabaseError.dbDoesNotExist
			}
		}
	}
}
