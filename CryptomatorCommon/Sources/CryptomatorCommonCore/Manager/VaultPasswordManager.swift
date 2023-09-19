//
//  VaultPasswordManager.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 09.07.21.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation
import LocalAuthentication

public protocol VaultPasswordManager {
	func setPassword(_ password: String, forVaultUID vaultUID: String) throws
	func getPassword(forVaultUID vaultUID: String, context: LAContext) throws -> String
	func removePassword(forVaultUID vaultUID: String) throws
	func hasPassword(forVaultUID vaultUID: String) throws -> Bool
}

public enum VaultPasswordManagerError: Error {
	case encodingError
	case passwordNotFound
}

public class VaultPasswordKeychainManager: VaultPasswordManager {
	public init() {}
	public func setPassword(_ password: String, forVaultUID vaultUID: String) throws {
		guard let data = password.data(using: .utf8) else {
			throw VaultPasswordManagerError.encodingError
		}
		try CryptomatorUserPresenceKeychain.vaultPassword.set(vaultUID, value: data)
	}

	public func removePassword(forVaultUID vaultUID: String) throws {
		do {
			try CryptomatorUserPresenceKeychain.vaultPassword.delete(vaultUID)
		} catch let CryptomatorKeychainError.unhandledError(statuscode) where statuscode == errSecItemNotFound {}
	}

	public func hasPassword(forVaultUID vaultUID: String) throws -> Bool {
		let data: Data?
		do {
			data = try CryptomatorUserPresenceKeychain.vaultPassword.getAsDataWithoutAuthentication(vaultUID)
		} catch let CryptomatorKeychainError.unhandledError(statuscode) where statuscode == errSecInteractionNotAllowed {
			return true
		} catch let CryptomatorKeychainError.unhandledError(statuscode) where statuscode == errSecItemNotFound {
			return false
		}
		if data != nil {
			return true
		} else {
			return false
		}
	}

	public func getPassword(forVaultUID vaultUID: String, context: LAContext) throws -> String {
		guard let data = CryptomatorUserPresenceKeychain.vaultPassword.getAsData(vaultUID, context: context) else {
			throw VaultPasswordManagerError.passwordNotFound
		}
		guard let password = String(data: data, encoding: .utf8) else {
			throw VaultPasswordManagerError.encodingError
		}
		return password
	}
}
