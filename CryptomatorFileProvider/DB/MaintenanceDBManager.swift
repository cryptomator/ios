//
//  MaintenanceDBManager.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 18.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Foundation
import GRDB

public protocol MaintenanceManager {
	/**
	 Enables the maintenance mode for the FileProviderAdapter.

	 Maintenance Mode prevents the creation of new `CloudTasks` so that vault-level operations (e.g. moving the entire vault) can be performed and consistency can be guaranteed.
	 Maintenance Mode is only successfully activated if there are no running / waiting `CloudTasks`, failed `CloudTasks` are ignored.

	 - Throws: An `MaintenanceModeError.runningCloudTask` if there is at least one running / pending `CloudTask`
	 */
	func enableMaintenanceMode() throws

	/**
	 Disables the maintenance mode for the FileProviderAdapter.
	 */
	func disableMaintenanceMode() throws
}

public class MaintenanceDBManager: MaintenanceManager {
	private let database: DatabaseWriter

	public init(database: DatabaseWriter) {
		self.database = database
	}

	public func enableMaintenanceMode() throws {
		try updateMaintenanceMode(enabled: true)
	}

	public func disableMaintenanceMode() throws {
		try updateMaintenanceMode(enabled: false)
	}

	private func updateMaintenanceMode(enabled: Bool) throws {
		let entry = MaintenanceModeEntry(id: 1, flag: enabled)
		do {
			try database.write { db in
				if enabled {
					guard try assertNoMultiEnabling(db: db) else {
						throw MaintenanceModeError.runningCloudTask
					}
				}
				try entry.save(db)
			}
		} catch let error as DatabaseError where error.message == "Running Task" {
			throw MaintenanceModeError.runningCloudTask
		}
	}

	private func assertNoMultiEnabling(db: Database) throws -> Bool {
		if let existingEntry = try MaintenanceModeEntry.fetchOne(db) {
			return !existingEntry.flag
		} else {
			return true
		}
	}
}

private struct MaintenanceModeEntry: Decodable, FetchableRecord, TableRecord, PersistableRecord {
	static let databaseTableName = "maintenanceMode"
	let id: Int64
	let flag: Bool

	enum Columns: String, ColumnExpression {
		case id, flag
	}

	func encode(to container: inout PersistenceContainer) {
		container[Columns.id] = id
		container[Columns.flag] = flag
	}
}
