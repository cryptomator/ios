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

	func observeVaultAccounts(onError: @escaping (Error) -> Void, onChange: @escaping ([VaultAccount]) -> Void) -> TransactionObserver {
		let observation = ValueObservation.tracking { db in
			try VaultAccount.fetchAll(db)
		}
		return observation.start(in: dbPool, onError: onError, onChange: onChange)
	}

	func getAllAccounts(for cloudProviderType: CloudProviderType) throws -> [AccountInfo] {
		try dbPool.read { db in
			let accountWithCloudProviderType = AccountListPosition.account.filter(Column("cloudProviderType") == cloudProviderType)
			let request = AccountListPosition.including(required: accountWithCloudProviderType).order(Column("position"))
			return try AccountInfo.fetchAll(db, request)
		}
	}

	/**
	 Since sqlite does not allow deferred unique constraints, we temporarily disable the not NULL check and change all positions to NULL and then save the correct positions.
	 */
	func updateAccountListPositions(_ positions: [AccountListPosition]) throws {
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

	func observeCloudProviderAccounts(onError: @escaping (Error) -> Void, onChange: @escaping ([CloudProviderAccount]) -> Void) -> TransactionObserver {
		let observation = ValueObservation.tracking { db in
			try CloudProviderAccount.fetchAll(db)
		}
		return observation.start(in: dbPool, onError: onError, onChange: onChange)
	}
}

extension VaultAccount {
	static let vaultListPosition = hasOne(VaultListPosition.self)
}
