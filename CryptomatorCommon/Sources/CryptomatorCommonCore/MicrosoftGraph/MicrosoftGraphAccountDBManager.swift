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
	static let uidKey = "uid"
	static let accountUIDKey = "accountUID"
	static let driveIDKey = "driveID"
	static let typeKey = "type"

	public let uid: String
	public let accountUID: String
	public let driveID: String?
	public let type: MicrosoftGraphType

	public init(uid: String, accountUID: String, driveID: String? = nil, type: MicrosoftGraphType) {
		self.uid = uid
		self.accountUID = accountUID
		self.driveID = driveID
		self.type = type
	}
}

extension MicrosoftGraphAccount: PersistableRecord {
	public func encode(to container: inout PersistenceContainer) {
		container[MicrosoftGraphAccount.uidKey] = uid
		container[MicrosoftGraphAccount.accountUIDKey] = accountUID
		container[MicrosoftGraphAccount.driveIDKey] = driveID
		container[MicrosoftGraphAccount.typeKey] = type
	}
}

public enum MicrosoftGraphAccountError: Error {
	case accountNotFoundError
}

public protocol MicrosoftGraphAccountManager {
	func getAccount(for uid: String) throws -> MicrosoftGraphAccount
	func multipleAccountsExist(for accountUID: String) throws -> Bool
	func saveNewAccount(_ account: MicrosoftGraphAccount) throws
	func updateDriveID(for uid: String, driveID: String?) throws
	func removeAccount(with uid: String) throws
}

public class MicrosoftGraphAccountDBManager: MicrosoftGraphAccountManager {
	@Dependency(\.database) var database
	public static let shared = MicrosoftGraphAccountDBManager()

	public func getAccount(for uid: String) throws -> MicrosoftGraphAccount {
		let account = try database.read { db in
			try MicrosoftGraphAccount.fetchOne(db, key: uid)
		}
		guard let account = account else {
			throw MicrosoftGraphAccountError.accountNotFoundError
		}
		return account
	}

	public func multipleAccountsExist(for accountUID: String) throws -> Bool {
		let count = try database.read { db in
			try Int.fetchOne(db,
			                 sql: "SELECT COUNT(*) FROM \(MicrosoftGraphAccount.databaseTableName) WHERE \(MicrosoftGraphAccount.accountUIDKey) = ?",
			                 arguments: [accountUID]) ?? 0
		}
		return count > 1
	}

	public func saveNewAccount(_ account: MicrosoftGraphAccount) throws {
		try database.write { db in
			try account.save(db)
		}
	}

	public func updateDriveID(for uid: String, driveID: String?) throws {
		try database.write { db in
			guard var account = try MicrosoftGraphAccount.fetchOne(db, key: uid) else {
				throw MicrosoftGraphAccountError.accountNotFoundError
			}
			account = MicrosoftGraphAccount(uid: account.uid, accountUID: account.accountUID, driveID: driveID, type: account.type)
			try account.update(db)
		}
	}

	public func removeAccount(with uid: String) throws {
		try database.write { db in
			guard try MicrosoftGraphAccount.deleteOne(db, key: uid) else {
				throw MicrosoftGraphAccountError.accountNotFoundError
			}
		}
	}
}
