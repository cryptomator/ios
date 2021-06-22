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

	let dbPool: DatabasePool

	public init(_ dbPool: DatabasePool) throws {
		self.dbPool = dbPool
		try CryptomatorDatabase.migrator.migrate(dbPool)
	}

	private static var migrator: DatabaseMigrator {
		var migrator = DatabaseMigrator()

		migrator.registerMigration("v1") { db in
			try db.create(table: "cloudProviderAccounts") { table in
				table.column("accountUID", .text).primaryKey()
				table.column("cloudProviderType", .text).notNull()
			}
			try db.create(table: "vaultAccounts") { table in
				table.column("vaultUID", .text).primaryKey()
				table.column("delegateAccountUID", .text).notNull().references("cloudProviderAccounts")
				table.column("vaultPath", .text).notNull()
				table.column("lastUpToDateCheck", .date).notNull()
			}
		}
		return migrator
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
