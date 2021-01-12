//
//  DatabaseManager.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 07.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CloudAccessPrivateCore
import Foundation
import GRDB

class DatabaseManager {
	private let dbPool: DatabasePool
	public static var shared: DatabaseManager!

	init(dbPool: DatabasePool) throws {
		self.dbPool = dbPool
		try DatabaseManager.migrator.migrate(dbPool)
	}

	private static var migrator: DatabaseMigrator {
		var migrator = DatabaseMigrator()
		migrator.registerMigration("main-v1") { db in
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
		}
		return migrator
	}

	func getAllVaults() throws -> [VaultInfo] {
		try dbPool.read { db in
			let request = VaultAccount.including(required: VaultAccount.delegateAccount).including(required: VaultAccount.vaultListPosition)
			return try VaultInfo.fetchAll(db, request)
		}
	}

	/**
	 Since sqlite does not allow deferred unique constraints, we temporarily disable the not NULL check and change all positions to NULL and then save the correct positions.
	 */
	func updateVaultListPositions(_ positions: [VaultListPosition]) throws {
		var tempPositions = positions
		for i in tempPositions.indices {
			tempPositions[i].position = nil
		}
		try dbPool.write { db in
			try db.execute(sql: "PRAGMA ignore_check_constraints=YES")
			for position in tempPositions {
				try position.update(db)
			}
			try db.execute(sql: "PRAGMA ignore_check_constraints=NO")
			for position in positions {
				try position.update(db)
			}
		}
	}
}

extension VaultAccount {
	static let vaultListPosition = hasOne(VaultListPosition.self)
}
