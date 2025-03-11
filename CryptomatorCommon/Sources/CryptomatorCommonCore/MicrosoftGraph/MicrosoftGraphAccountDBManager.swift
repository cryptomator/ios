//
//  MicrosoftGraphAccountDBManager.swift
//  CryptomatorCommonCore
//
//  Created by Tobias Hagemann on 10.03.25.
//  Copyright © 2025 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Dependencies
import Foundation
import GRDB

public struct MicrosoftGraphAccount: Codable, FetchableRecord, TableRecord, Equatable {
	public static let databaseTableName = "microsoftGraphAccounts"
	static let accountUIDKey = "accountUID"
	static let credentialIDKey = "credentialID"
	static let driveIDKey = "driveID"
	static let typeKey = "type"

	public let accountUID: String
	public let credentialID: String
	public let driveID: String?
	public let type: MicrosoftGraphType

	public init(accountUID: String, credentialID: String, driveID: String? = nil, type: MicrosoftGraphType) {
		self.accountUID = accountUID
		self.credentialID = credentialID
		self.driveID = driveID
		self.type = type
	}
}

extension MicrosoftGraphAccount: PersistableRecord {
	public func encode(to container: inout PersistenceContainer) {
		container[MicrosoftGraphAccount.accountUIDKey] = accountUID
		container[MicrosoftGraphAccount.credentialIDKey] = credentialID
		container[MicrosoftGraphAccount.driveIDKey] = driveID
		container[MicrosoftGraphAccount.typeKey] = type
	}
}

public enum MicrosoftGraphAccountError: Error {
	case accountNotFoundError
}

public protocol MicrosoftGraphAccountManager {
	func getAccount(for accountUID: String) throws -> MicrosoftGraphAccount
	func multipleAccountsExist(for credentialID: String) throws -> Bool
	func saveNewAccount(_ account: MicrosoftGraphAccount) throws
}

public class MicrosoftGraphAccountDBManager: MicrosoftGraphAccountManager {
	@Dependency(\.database) var database
	public static let shared = MicrosoftGraphAccountDBManager()

	public func getAccount(for accountUID: String) throws -> MicrosoftGraphAccount {
		let account = try database.read { db in
			try MicrosoftGraphAccount.fetchOne(db, key: accountUID)
		}
		guard let account = account else {
			throw MicrosoftGraphAccountError.accountNotFoundError
		}
		return account
	}

	public func multipleAccountsExist(for credentialID: String) throws -> Bool {
		let count = try database.read { db in
			try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM \(MicrosoftGraphAccount.databaseTableName) WHERE \(MicrosoftGraphAccount.credentialIDKey) = ?", arguments: [credentialID]) ?? 0
		}
		return count > 1
	}

	public func saveNewAccount(_ account: MicrosoftGraphAccount) throws {
		try database.write { db in
			try account.save(db)
		}
	}
}
