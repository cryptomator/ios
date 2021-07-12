//
//  CryptomatorKeychain.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 22.10.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation

enum CryptomatorKeychainError: Error {
	case unhandledError(status: OSStatus)
}

class CryptomatorKeychain {
	let service: String
	static let bundleId = CryptomatorConstants.mainAppBundleId
	static let webDAV = CryptomatorKeychain(service: "webDAV.auth")
	static let localFileSystem = CryptomatorKeychain(service: "localFileSystem.auth")
	static let vault = CryptomatorKeychain(service: "cryptomatorVault")
	static let vaultPassword = CryptomatorKeychain(service: "cryptomatorVaultPassword")

	init(service: String) {
		self.service = service
	}

	func queryWithDict(_ query: [String: AnyObject]) -> CFDictionary {
		var queryDict = query

		queryDict[kSecClass as String] = kSecClassGenericPassword
		queryDict[kSecAttrService as String] = "\(CryptomatorKeychain.bundleId).\(service)" as AnyObject?
		queryDict[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

		return queryDict as CFDictionary
	}

	func set(_ key: String, value: Data) throws {
		let query = queryWithDict([
			kSecAttrAccount as String: key as AnyObject,
			kSecValueData as String: value as AnyObject
		])
		SecItemDelete(query)
		let status = SecItemAdd(query, nil)
		guard status == noErr else {
			throw CryptomatorKeychainError.unhandledError(status: status)
		}
	}

	func getAsData(_ key: String) -> Data? {
		let query = queryWithDict([
			kSecAttrAccount as String: key as AnyObject,
			kSecReturnData as String: kCFBooleanTrue,
			kSecMatchLimit as String: kSecMatchLimitOne
		])

		var dataResult: AnyObject?
		let status = SecItemCopyMatching(query as CFDictionary, &dataResult)

		if status == noErr {
			return dataResult as? Data
		}

		return nil
	}

	func delete(_ key: String) throws {
		let query = queryWithDict([
			kSecAttrAccount as String: key as AnyObject
		])
		let status = SecItemDelete(query)
		guard status == noErr else {
			throw CryptomatorKeychainError.unhandledError(status: status)
		}
	}
}
