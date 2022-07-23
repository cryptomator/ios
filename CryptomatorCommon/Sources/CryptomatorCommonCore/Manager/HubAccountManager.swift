//
//  HubAccountManager.swift
//
//
//  Created by Philipp Schmid on 22.07.22.
//

import AppAuthCore
import Foundation
import GRDB

struct HubAccountInfo: Codable {
	let userID: String
}

extension HubAccountInfo: FetchableRecord, MutablePersistableRecord {
	enum Columns: String, ColumnExpression {
		case userID
	}
}

public struct HubAccount {
	public let userID: String
	public let authState: OIDAuthState
}

extension HubAccount {
	init(info: HubAccountInfo, authState: OIDAuthState) {
		self.userID = info.userID
		self.authState = authState
	}
}

extension HubAccount {
	private static let keycloakUserIDKey = "sub"

	public init(authState: OIDAuthState) throws {
//		guard let idToken = authState.lastTokenResponse?.idToken ?? authState.lastAuthorizationResponse.idToken else {
//			throw HubAccountError.missingIDToken
//		}
//		guard let claims = OIDIDToken(idTokenString: idToken)?.claims else {
//			throw HubAccountError.missingClaims
//		}
//		guard let userID = claims[HubAccount.keycloakUserIDKey] as? String else {
//			throw HubAccountError.missingUserID
//		}
		let userID = "DemoUser-ID"
		self.init(userID: userID, authState: authState)
	}
}

enum HubAccountError: Error {
	case missingIDToken
	case missingClaims
	case missingUserID
}

struct HubVaultAccount: Codable {
	var id: Int64?
	let vaultUID: String
	let hubUserID: String
}

extension HubVaultAccount: FetchableRecord, MutablePersistableRecord {
	enum Columns: String, ColumnExpression {
		case id, vaultUID, hubUserID
	}
}

public struct HubAccountManager {
	let dbWriter: DatabaseWriter
	let keychain: CryptomatorKeychainType
	public static let shared = HubAccountManager(dbWriter: CryptomatorDatabase.shared.dbPool, keychain: CryptomatorKeychain.hub)

	public func getHubAccount(withUserID userID: String) throws -> HubAccount? {
		guard let accountInfo = try getHubAccountInfo(withUserID: userID) else {
			return nil
		}
		return getHubAccount(accountInfo: accountInfo)
	}

	public func getHubAccount(forVaultUID vaultUID: String) throws -> HubAccount? {
		try dbWriter.read { db in
			guard let hubVaultAccount = try HubVaultAccount.fetchOne(db, key: [HubVaultAccount.Columns.vaultUID.name: vaultUID]) else {
				return nil
			}
			guard let accountInfo = try HubAccountInfo.fetchOne(db, key: hubVaultAccount.hubUserID) else {
				return nil
			}
			return getHubAccount(accountInfo: accountInfo)
		}
	}

	public func saveHubAccount(_ hubAccount: HubAccount) throws {
		var accountInfo = HubAccountInfo(userID: hubAccount.userID)
		try dbWriter.write { db in
			try accountInfo.save(db)
			try keychain.saveAuthState(hubAccount.authState, for: accountInfo.userID)
		}
	}

	public func removeHubAccount(withUserID userID: String) throws {
		try dbWriter.write { db in
			try HubAccountInfo.deleteOne(db, key: [HubAccountInfo.Columns.userID.name: userID])
			try keychain.delete(userID)
		}
	}

	public func linkVaultToHubAccount(vaultUID: String, hubUserID: String) throws {
		let request = HubAccountInfo.filter(HubAccountInfo.Columns.userID == hubUserID)
		try dbWriter.write { db in
			guard let accountInfo = try HubAccountInfo.fetchOne(db, request) else {
				throw HubAccountManagerError.unknownHubUserID
			}
			guard let vaultAccount = try VaultAccount.fetchOne(db, key: [VaultAccount.vaultUIDKey: vaultUID]) else {
				throw HubAccountManagerError.unknownVaultUID
			}
			var hubVaultAccount = HubVaultAccount(vaultUID: vaultAccount.vaultUID, hubUserID: accountInfo.userID)
			try hubVaultAccount.save(db)
		}
	}

	private func getHubAccountInfo(withUserID userID: String) throws -> HubAccountInfo? {
		let request = HubAccountInfo.filter(HubAccountInfo.Columns.userID == userID)
		return try dbWriter.read { db in
			try HubAccountInfo.fetchOne(db, request)
		}
	}

	private func getHubAccount(accountInfo: HubAccountInfo) -> HubAccount? {
		guard let authState = keychain.getAuthState(accountInfo.userID) else {
			return nil
		}
		return HubAccount(info: accountInfo, authState: authState)
	}
}

enum HubAccountManagerError: Error {
	case unknownHubUserID
	case unknownVaultUID
}

private extension CryptomatorKeychainType {
	func getAuthState(_ identifier: String) -> OIDAuthState? {
		guard let data = getAsData(identifier) else {
			return nil
		}
		return try? NSKeyedUnarchiver.unarchivedObject(ofClass: OIDAuthState.self, from: data)
	}

	func saveAuthState(_ authState: OIDAuthState, for identifier: String) throws {
		let archivedAuthState = try NSKeyedArchiver.archivedData(withRootObject: authState, requiringSecureCoding: true)
		try set(identifier, value: archivedAuthState)
	}
}
