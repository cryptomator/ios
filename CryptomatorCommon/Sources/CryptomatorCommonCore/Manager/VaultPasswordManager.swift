//
//  VaultPasswordKeychainManager.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 09.07.21.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation
protocol VaultPasswordManager {
	func setPassword(_ password: String, forVaultUID vaultUID: String) throws
	func getPassword(forVaultUID vaultUID: String) throws -> String
	func removePassword(forVaultUID vaultUID: String) throws
}

public enum VaultPasswordManagerError: Error {
	case encodingError
	case passwordNotFound
}

class VaultPasswordKeychainManager: VaultPasswordManager {
	func setPassword(_ password: String, forVaultUID vaultUID: String) throws {
		guard let data = password.data(using: .utf8) else {
			throw VaultPasswordManagerError.encodingError
		}
		try CryptomatorKeychain.vaultPassword.set(vaultUID, value: data)
	}

	func getPassword(forVaultUID vaultUID: String) throws -> String {
		guard let data = CryptomatorKeychain.vaultPassword.getAsData(vaultUID) else {
			throw VaultPasswordManagerError.passwordNotFound
		}
		guard let password = String(data: data, encoding: .utf8) else {
			throw VaultPasswordManagerError.encodingError
		}
		return password
	}

	func removePassword(forVaultUID vaultUID: String) throws {
		do {
			try CryptomatorKeychain.vaultPassword.delete(vaultUID)
		} catch let CryptomatorKeychainError.unhandledError(statuscode) where statuscode == errSecItemNotFound {}
	}
}
