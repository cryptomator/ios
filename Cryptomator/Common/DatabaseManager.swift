//
//  DatabaseManager.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 07.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Foundation
import GRDB

class DatabaseManager {
	public static var shared: DatabaseManager!

	let dbPool: DatabasePool

	init(dbPool: DatabasePool) throws {
		self.dbPool = dbPool
	}

	func getAllVaults() throws -> [VaultInfo] {
		try dbPool.read { db in
			let request = VaultAccount.including(required: VaultAccount.delegateAccount).including(required: VaultAccount.vaultListPosition)
			return try VaultInfo.fetchAll(db, request)
		}
	}

	/**
	 Since SQLite does not allow deferred unique constraints, we temporarily disable the `NOT NULL` check, change all positions to `NULL` and then save the correct positions.
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
	 Since SQLite does not allow deferred unique constraints, we temporarily disable the `NOT NULL` check, change all positions to `NULL` and then save the correct positions.
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
