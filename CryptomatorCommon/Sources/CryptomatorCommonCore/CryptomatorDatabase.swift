//
//  CryptomatorDatabase.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 07.11.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCloudAccessCore
import Dependencies
import Foundation
import GRDB

private enum CryptomatorDatabaseKey: DependencyKey {
	static let liveValue: DatabaseWriter = CryptomatorDatabase.live

	static var testValue: DatabaseWriter {
		do {
			let inMemoryDB = try DatabaseQueue(configuration: .defaultCryptomatorConfiguration)
			try CryptomatorDatabase.migrator.migrate(inMemoryDB)
			return inMemoryDB
		} catch {
			DDLogError("Failed to initialize in-memory database: \(error)")
			fatalError("Failed to initialize in-memory database")
		}
	}
}

public extension DependencyValues {
	var database: DatabaseWriter {
		get { self[CryptomatorDatabaseKey.self] }
		set { self[CryptomatorDatabaseKey.self] = newValue }
	}
}

private enum CryptomatorDatabaseLocationKey: DependencyKey {
	static var liveValue: URL? { CryptomatorDatabase.sharedDBURL }
	static var testValue: URL? { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: false) }
}

public extension DependencyValues {
	var databaseLocation: URL? {
		get { self[CryptomatorDatabaseLocationKey.self] }
		set { self[CryptomatorDatabaseLocationKey.self] = newValue }
	}
}

public enum CryptomatorDatabaseError: Error {
	case dbDoesNotExist
	case incompleteMigration
}

public class CryptomatorDatabase {
	static var live: DatabaseWriter {
		@Dependency(\.databaseLocation) var databaseURL

		guard let dbURL = databaseURL else {
			fatalError("Could not get URL for shared database")
		}
		let database: DatabaseWriter
		do {
			database = try CryptomatorDatabase.openSharedDatabase(at: dbURL)
		} catch {
			DDLogError("Failed to open shared database: \(error)")
			fatalError("Could not open shared database")
		}
		do {
			try CryptomatorDatabase.migrator.migrate(database)
		} catch {
			DDLogError("Failed to migrate database: \(error)")
		}
		return database
	}

	static var sharedDBURL: URL? {
		let sharedContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: CryptomatorConstants.appGroupName)
		return sharedContainer?.appendingPathComponent("db.sqlite")
	}

	static var migrator: DatabaseMigrator {
		var migrator = DatabaseMigrator()
		migrator.registerMigration("v1") { db in
			try v1Migration(db)
		}
		migrator.registerMigration("v2") { db in
			try v2Migration(db)
		}
		migrator.registerMigration("s3DisplayNameMigration") { db in
			try s3DisplayNameMigration(db)
		}
		migrator.registerMigration("initialHubSupport") { db in
			try initialHubSupportMigration(db)
		}
		migrator.registerMigration("microsoftGraphAccountMigration") { db in
			try microsoftGraphAccountMigration(db)
		}
		return migrator
	}

	// swiftlint:disable:next function_body_length
	class func v1Migration(_ db: Database) throws {
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

	class func v2Migration(_ db: Database) throws {
		try db.alter(table: "cachedVaults", body: { table in
			table.add(column: "masterkeyFileLastModifiedDate", .date)
			table.add(column: "vaultConfigLastModifiedDate", .date).check(sql: "NOT (vaultConfigLastModifiedDate IS NOT NULL AND vaultConfigToken IS NULL)")
		})
	}

	/**
	 Migrates the database to support S3 display names.

	 Since a `CloudProviderAccount` gets saved in the database after the display name has been saved, it is not possible to use a simple foreign key constraint.
	 Therefore, an `ON DELETE CASCADE` is implemented via the trigger `s3_display_name_deletion`.
	 */
	class func s3DisplayNameMigration(_ db: Database) throws {
		try db.create(table: "s3DisplayNames", body: { table in
			table.column("id", .text).primaryKey()
			table.column("displayName", .text).notNull()
		})
		try db.execute(sql: """
		CREATE TRIGGER s3_display_name_deletion
		AFTER DELETE
		ON cloudProviderAccounts
		BEGIN
		    DELETE FROM s3DisplayNames
		    WHERE id = OLD.accountUID;
		END;
		""")
	}

	class func initialHubSupportMigration(_ db: Database) throws {
		try db.create(table: "hubVaultAccount", body: { table in
			table.column("vaultUID", .text).primaryKey().references("vaultAccounts", onDelete: .cascade)
			table.column("subscriptionState", .text).notNull()
		})
	}

	class func microsoftGraphAccountMigration(_ db: Database) throws {
		try db.create(table: "microsoftGraphAccounts") { table in
			table.column("accountUID", .text).primaryKey().references("cloudProviderAccounts", onDelete: .cascade)
			table.column("credentialID", .text).notNull()
			table.column("driveID", .text)
			table.column("siteURL", .text)
			table.column("type", .text).notNull()
			table.uniqueKey(["credentialID", "driveID", "type"])
		}
		try db.execute(sql: """
		CREATE UNIQUE INDEX uq_microsoftGraphAccounts_nullDriveID
		ON microsoftGraphAccounts (credentialID, type)
		WHERE driveID IS NULL
		""")
		enum LegacyCloudProviderType: Codable, DatabaseValueConvertible { case oneDrive }
		let rows = try Row.fetchAll(db, sql: "SELECT accountUID FROM cloudProviderAccounts WHERE cloudProviderType = ?", arguments: [LegacyCloudProviderType.oneDrive.databaseValue])
		for row in rows {
			let oldAccountUID: String = row["accountUID"] // which is the `credentialID`
			let newAccountUID = UUID().uuidString
			let newCloudProviderType = CloudProviderType.microsoftGraph(type: .oneDrive).databaseValue
			try db.execute(sql: "UPDATE cloudProviderAccounts SET accountUID = ?, cloudProviderType = ? WHERE accountUID = ?", arguments: [newAccountUID, newCloudProviderType, oldAccountUID])
			try db.execute(sql: "UPDATE vaultAccounts SET delegateAccountUID = ? WHERE delegateAccountUID = ?", arguments: [newAccountUID, oldAccountUID])
			try db.execute(sql: "UPDATE accountListPosition SET accountUID = ?, cloudProviderType = ? WHERE accountUID = ?", arguments: [newAccountUID, newCloudProviderType, oldAccountUID])
			let newMicrosoftGraphType = MicrosoftGraphType.oneDrive.databaseValue
			try db.execute(sql: "INSERT INTO microsoftGraphAccounts (accountUID, credentialID, driveID, siteURL, type) VALUES (?, ?, NULL, NULL, ?)", arguments: [newAccountUID, oldAccountUID, newMicrosoftGraphType])
		}
	}

	public static func openSharedDatabase(at databaseURL: URL) throws -> DatabasePool {
		let coordinator = NSFileCoordinator(filePresenter: nil)
		var coordinatorError: NSError?
		var dbPool: DatabasePool?
		var dbError: Error?

		coordinator.coordinate(writingItemAt: databaseURL, options: .forMerging, error: &coordinatorError, byAccessor: { _ in
			do {
				dbPool = try DatabasePool(path: databaseURL.path, configuration: .defaultCryptomatorConfiguration)
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
			var configuration = Configuration.defaultCryptomatorConfiguration
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

extension Configuration {
	static var defaultCryptomatorConfiguration: Configuration {
		var configuration = Configuration()
		// Workaround for a SQLite regression (see https://github.com/groue/GRDB.swift/issues/1171 for more details)
		configuration.acceptsDoubleQuotedStringLiterals = true
		return configuration
	}
}
