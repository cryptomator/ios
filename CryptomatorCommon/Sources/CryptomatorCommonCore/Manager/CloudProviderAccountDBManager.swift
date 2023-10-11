//
//  CloudProviderAccountDBManager.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 20.10.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Dependencies
import Foundation
import GRDB

public struct CloudProviderAccount: Decodable, FetchableRecord, TableRecord, Equatable {
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
	@Dependency(\.database) var database
	public static let shared = CloudProviderAccountDBManager()

	public func getCloudProviderType(for accountUID: String) throws -> CloudProviderType {
		let cloudAccount = try database.read { db in
			return try CloudProviderAccount.fetchOne(db, key: accountUID)
		}
		guard let providerType = cloudAccount?.cloudProviderType else {
			throw CloudProviderAccountError.accountNotFoundError
		}
		return providerType
	}

	public func getAllAccountUIDs(for type: CloudProviderType) throws -> [String] {
		let accounts: [CloudProviderAccount] = try database.read { db in
			return try CloudProviderAccount
				.filter(Column("cloudProviderType") == type)
				.fetchAll(db)
		}
		return accounts.map { $0.accountUID }
	}

	public func saveNewAccount(_ account: CloudProviderAccount) throws {
		try database.write { db in
			try account.save(db)
		}
	}

	public func removeAccount(with accountUID: String) throws {
		try database.write { db in
			guard try CloudProviderAccount.deleteOne(db, key: accountUID) else {
				throw CloudProviderAccountError.accountNotFoundError
			}
		}
	}
}
