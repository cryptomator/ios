//
//  VaultAccountDBManager.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 30.10.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation
import GRDB

public struct VaultAccount: Decodable, FetchableRecord, TableRecord, Equatable {
	public static let databaseTableName = "vaultAccounts"
	static let vaultUIDKey = "vaultUID"
	static let delegateAccountUIDKey = "delegateAccountUID"
	static let vaultPathKey = "vaultPath"
	static let lastUpToDateCheckKey = "lastUpToDateCheck"
	static let vaultNameKey = "vaultName"

	public let vaultUID: String
	public let delegateAccountUID: String
	public let vaultPath: CloudPath
	public let vaultName: String

	public static let delegateAccount = belongsTo(CloudProviderAccount.self)

	public init(vaultUID: String, delegateAccountUID: String, vaultPath: CloudPath, vaultName: String) {
		self.vaultUID = vaultUID
		self.delegateAccountUID = delegateAccountUID
		self.vaultPath = vaultPath
		self.vaultName = vaultName
	}
}

extension VaultAccount: PersistableRecord {
	public func encode(to container: inout PersistenceContainer) {
		container[VaultAccount.vaultUIDKey] = vaultUID
		container[VaultAccount.delegateAccountUIDKey] = delegateAccountUID
		container[VaultAccount.vaultPathKey] = vaultPath
		container[VaultAccount.vaultNameKey] = vaultName
	}
}

public protocol VaultAccountManager {
	func saveNewAccount(_ account: VaultAccount) throws
	func removeAccount(with vaultUID: String) throws
	func getAccount(with vaultUID: String) throws -> VaultAccount
	func getAllAccounts() throws -> [VaultAccount]
	func updateAccount(_ account: VaultAccount) throws
}

public enum VaultAccountManagerError: Error {
	case vaultAccountAlreadyExists
}

public class VaultAccountDBManager: VaultAccountManager {
	public static let shared = VaultAccountDBManager(dbPool: CryptomatorDatabase.shared.dbPool)
	private let dbPool: DatabasePool

	public init(dbPool: DatabasePool) {
		self.dbPool = dbPool
	}

	public func saveNewAccount(_ account: VaultAccount) throws {
		do {
			try dbPool.write { db in
				try account.save(db)
			}
		} catch let error as DatabaseError where error.resultCode == .SQLITE_CONSTRAINT {
			throw VaultAccountManagerError.vaultAccountAlreadyExists
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

	public func getAllAccounts() throws -> [VaultAccount] {
		try dbPool.read { db in
			try VaultAccount.fetchAll(db)
		}
	}

	public func updateAccount(_ account: VaultAccount) throws {
		try dbPool.write { db in
			try account.update(db)
		}
	}
}
