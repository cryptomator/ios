//
//  VaultAccountManager.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 30.10.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation
import GRDB

public struct VaultAccount: Decodable, FetchableRecord, TableRecord {
	public static let databaseTableName = "vaultAccounts"
	static let vaultUIDKey = "vaultUID"
	static let delegateAccountUIDKey = "delegateAccountUID"
	static let vaultPathKey = "vaultPath"
	static let lastUpToDateCheckKey = "lastUpToDateCheck"
	public let vaultUID: String
	let delegateAccountUID: String
	public let vaultPath: CloudPath
	let lastUpToDateCheck: Date

	public static let delegateAccount = belongsTo(CloudProviderAccount.self)

	public init(vaultUID: String, delegateAccountUID: String, vaultPath: CloudPath, lastUpToDateCheck: Date = Date()) {
		self.vaultUID = vaultUID
		self.delegateAccountUID = delegateAccountUID
		self.vaultPath = vaultPath
		self.lastUpToDateCheck = lastUpToDateCheck
	}
}

extension VaultAccount: PersistableRecord {
	public func encode(to container: inout PersistenceContainer) {
		container[VaultAccount.vaultUIDKey] = vaultUID
		container[VaultAccount.delegateAccountUIDKey] = delegateAccountUID
		container[VaultAccount.vaultPathKey] = vaultPath
		container[VaultAccount.lastUpToDateCheckKey] = lastUpToDateCheck
	}
}

public class VaultAccountManager {
	public static let shared = VaultAccountManager(dbPool: CryptomatorDatabase.shared.dbPool)
	private let dbPool: DatabasePool

	public init(dbPool: DatabasePool) {
		self.dbPool = dbPool
	}

	public func saveNewAccount(_ account: VaultAccount) throws {
		try dbPool.write { db in
			try account.save(db)
		}
	}

	public func removeAccount(with vaultUID: String) throws {
		try dbPool.write { db in
			guard try VaultAccount.deleteOne(db, key: vaultUID) else {
				throw CloudProviderAccountError.accountNotFoundError
			}
		}
	}

	public func getAccount(with vaultUID: String) throws -> VaultAccount {
		let fetchedAccount = try dbPool.read { db in
			return try VaultAccount.fetchOne(db, key: vaultUID)
		}
		guard let account = fetchedAccount else {
			throw CloudProviderAccountError.accountNotFoundError
		}
		return account
	}

	func getAllAccounts() throws -> [VaultAccount] {
		try dbPool.read { db in
			try VaultAccount.fetchAll(db)
		}
	}

	// only for prototype
	public func getAllVaultUIDs(with delegateAccountUID: String) throws -> [String] {
		let accounts: [VaultAccount] = try dbPool.read { db in
			return try VaultAccount
				.filter(Column(VaultAccount.delegateAccountUIDKey) == delegateAccountUID)
				.fetchAll(db)
		}
		return accounts.map { $0.vaultUID }
	}
}
