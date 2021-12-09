//
//  CloudProviderAccountDBManager.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 20.10.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation
import GRDB

public struct CloudProviderAccount: Decodable, FetchableRecord, TableRecord {
	public static let databaseTableName = "cloudProviderAccounts"
	static let accountUIDKey = "accountUID"
	static let cloudProviderTypeKey = "cloudProviderType"
	public let accountUID: String
	public let cloudProviderType: CloudProviderType

	public init(accountUID: String, cloudProviderType: CloudProviderType) {
		self.accountUID = accountUID
		self.cloudProviderType = cloudProviderType
	}
}

extension CloudProviderAccount: PersistableRecord {
	public func encode(to container: inout PersistenceContainer) {
		container[CloudProviderAccount.accountUIDKey] = accountUID
		container[CloudProviderAccount.cloudProviderTypeKey] = cloudProviderType
	}
}

public enum CloudProviderAccountError: Error {
	case accountNotFoundError
}

public protocol CloudProviderAccountManager {
	func getCloudProviderType(for accountUID: String) throws -> CloudProviderType
	func getAllAccountUIDs(for type: CloudProviderType) throws -> [String]
	func saveNewAccount(_ account: CloudProviderAccount) throws
	func removeAccount(with accountUID: String) throws
}

public class CloudProviderAccountDBManager: CloudProviderAccountManager {
	public static let shared = CloudProviderAccountDBManager(dbPool: CryptomatorDatabase.shared.dbPool)
	private let dbPool: DatabasePool

	init(dbPool: DatabasePool) {
		self.dbPool = dbPool
	}

	public func getCloudProviderType(for accountUID: String) throws -> CloudProviderType {
		let cloudAccount = try dbPool.read { db in
			return try CloudProviderAccount.fetchOne(db, key: accountUID)
		}
		guard let providerType = cloudAccount?.cloudProviderType else {
			throw CloudProviderAccountError.accountNotFoundError
		}
		return providerType
	}

	public func getAllAccountUIDs(for type: CloudProviderType) throws -> [String] {
		let accounts: [CloudProviderAccount] = try dbPool.read { db in
			return try CloudProviderAccount
				.filter(Column("cloudProviderType") == type)
				.fetchAll(db)
		}
		return accounts.map { $0.accountUID }
	}

	public func saveNewAccount(_ account: CloudProviderAccount) throws {
		try dbPool.write { db in
			try account.save(db)
		}
	}

	public func removeAccount(with accountUID: String) throws {
		try dbPool.write { db in
			guard try CloudProviderAccount.deleteOne(db, key: accountUID) else {
				throw CloudProviderAccountError.accountNotFoundError
			}
		}
	}
}
