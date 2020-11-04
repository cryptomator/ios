//
//  VaultAccountManager.swift
//  CloudAccessPrivateCore
//
//  Created by Philipp Schmid on 30.10.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import Foundation
import GRDB
public struct VaultAccount: Decodable, FetchableRecord, TableRecord {
	public static let databaseTableName = "vaultAccounts"
	static let vaultUIDKey = "vaultUID"
	static let delegateAccountUIDKey = "delegateAccountUID"
	static let vaultPathKey = "vaultPath"
	static let lastUpToDateCheckKey = "lastUpToDateCheck"
	let vaultUID: String
	let delegateAccountUID: String
	let vaultPath: CloudPath
	let lastUpToDateCheck: Date
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
	private let dbQueue: DatabaseQueue

	public init(dbQueue: DatabaseQueue) {
		self.dbQueue = dbQueue
	}

	public func saveNewAccount(_ account: VaultAccount) throws {
		try dbQueue.write { db in
			try account.save(db)
		}
	}

	public func removeAccount(with accountUID: String) throws {
		try dbQueue.write { db in
			guard try VaultAccount.deleteOne(db, key: accountUID) else {
				throw CloudProviderAccountError.accountNotFoundError
			}
		}
	}

	public func getAccount(with vaultUID: String) throws -> VaultAccount {
		let fetchedAccount = try dbQueue.read { db in
			return try VaultAccount.fetchOne(db, key: vaultUID)
		}
		guard let account = fetchedAccount else {
			throw CloudProviderAccountError.accountNotFoundError
		}
		return account
	}
}
