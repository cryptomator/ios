//
//  DatabaseManager.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 07.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import CryptomatorCommonCore
import Dependencies
import Foundation
import GRDB

class DatabaseManager {
	public static var shared: DatabaseManager!

	@Dependency(\.database) private var database

	func getAllVaults() throws -> [VaultInfo] {
		try database.read { db in
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
		try database.write { db in
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

	func observeVaultAccounts(onError: @escaping (Error) -> Void, onChange: @escaping ([VaultAccount]) -> Void) -> DatabaseCancellable {
		let observation = ValueObservation
			.tracking { try VaultAccount.fetchAll($0) }
			.removeDuplicates()
		return observation.start(in: database, scheduling: .immediate, onError: onError, onChange: onChange)
	}

	func observeVaultAccount(withVaultUID vaultUID: String, onError: @escaping (Error) -> Void, onChange: @escaping (VaultAccount?) -> Void) -> DatabaseCancellable {
		let observation = ValueObservation.tracking { db in
			try VaultAccount.fetchOne(db, key: vaultUID)
		}
		return observation.start(in: database, scheduling: .immediate, onError: onError, onChange: onChange)
	}

	func getAllAccounts(for cloudProviderType: CloudProviderType) throws -> [AccountInfo] {
		try database.read { db in
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
		try database.write { db in
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

	/**
	 Observes changes to the `cloudProviderAccounts` table.

	 At the beginning all entries of the `cloudProviderAccounts` table are returned immediately.
	 Note: additionally the table `s3DisplayNames` is monitored, so that onChange is triggered also in case of changes within this table.
	 */
	func observeCloudProviderAccounts(onError: @escaping (Error) -> Void, onChange: @escaping ([CloudProviderAccount]) -> Void) -> DatabaseCancellable {
		let request = CloudProviderAccount.including(optional: CloudProviderAccount.s3DisplayName)
		let observation = ValueObservation
			.tracking { db in try Row.fetchAll(db, request) }
			.removeDuplicates()
			.map { rows in rows.map(AccountWithDisplayName.init(row:)) }
			.map { annotatedAccounts in annotatedAccounts.map(\.account) }
		return observation.start(in: database, scheduling: .immediate, onError: onError, onChange: onChange)
	}
}

extension VaultAccount {
	static let vaultListPosition = hasOne(VaultListPosition.self)
}

private struct AccountWithDisplayName: Equatable, Decodable, FetchableRecord {
	let account: CloudProviderAccount
	let displayName: String?
}
