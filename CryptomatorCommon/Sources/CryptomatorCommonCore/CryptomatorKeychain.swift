//
//  CryptomatorKeychain.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 22.10.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation
import LocalAuthentication

enum CryptomatorKeychainError: Error {
	case unhandledError(status: OSStatus)
}

class CryptomatorKeychain {
	let service: String
	static let bundleId = CryptomatorConstants.mainAppBundleId
	static let webDAV = CryptomatorKeychain(service: "webDAV.auth")
	static let localFileSystem = CryptomatorKeychain(service: "localFileSystem.auth")
	static let upgrade = CryptomatorKeychain(service: "upgrade")
	static let vault = CryptomatorKeychain(service: "cryptomatorVault") // TODO: deprecated?

	init(service: String) {
		self.service = service
	}

	func queryWithDict(_ query: [String: AnyObject]) -> [String: Any] {
		var queryDict = query

		queryDict[kSecClass as String] = kSecClassGenericPassword
		queryDict[kSecAttrService as String] = "\(CryptomatorKeychain.bundleId).\(service)" as AnyObject?
		queryDict[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

		return queryDict
	}

	func set(_ key: String, value: Data) throws {
		let query = setQuery(key: key, value: value) as CFDictionary
		SecItemDelete(query)
		let status = SecItemAdd(query, nil)
		guard status == noErr else {
			throw CryptomatorKeychainError.unhandledError(status: status)
		}
	}

	func getAsData(_ key: String) -> Data? {
		let query = getQuery(key: key) as CFDictionary
		return getAsDataMaskedError(query: query)
	}

	func delete(_ key: String) throws {
		let query = deleteQuery(key: key) as CFDictionary
		let status = SecItemDelete(query)
		guard status == noErr else {
			throw CryptomatorKeychainError.unhandledError(status: status)
		}
	}

	// MARK: Internal

	func getQuery(key: String) -> [String: Any] {
		return queryWithDict([
			kSecAttrAccount as String: key as AnyObject,
			kSecReturnData as String: kCFBooleanTrue,
			kSecMatchLimit as String: kSecMatchLimitOne
		])
	}

	func setQuery(key: String, value: Data) -> [String: Any] {
		return queryWithDict([
			kSecAttrAccount as String: key as AnyObject,
			kSecValueData as String: value as AnyObject
		])
	}

	func deleteQuery(key: String) -> [String: Any] {
		return queryWithDict([
			kSecAttrAccount as String: key as AnyObject
		])
	}

	func getAsDataMaskedError(query: CFDictionary) -> Data? {
		return try? getAsData(query: query)
	}

	func getAsData(query: CFDictionary) throws -> Data? {
		var dataResult: AnyObject?
		let status = SecItemCopyMatching(query, &dataResult)

		guard status == noErr else {
			throw CryptomatorKeychainError.unhandledError(status: status)
		}
		return dataResult as? Data
	}
}

class CryptomatorUserPresenceKeychain: CryptomatorKeychain {
	static let vaultPassword = CryptomatorUserPresenceKeychain(service: "cryptomatorVaultPassword")
	private static var access = SecAccessControlCreateWithFlags(nil, // Use the default allocator.
	                                                            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
	                                                            .biometryCurrentSet,
	                                                            nil) // Ignore any error.

	override func setQuery(key: String, value: Data) -> [String: Any] {
		var query = super.setQuery(key: key, value: value)
		query[kSecAttrAccessControl as String] = CryptomatorUserPresenceKeychain.access as Any
		return query
	}

	override func queryWithDict(_ query: [String: AnyObject]) -> [String: Any] {
		var query = super.queryWithDict(query)
		query[kSecAttrAccessible as String] = nil
		return query
	}

	func getAsDataWithoutAuthentication(_ key: String) throws -> Data? {
		var query = getQuery(key: key)
		query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUIFail
		return try getAsData(query: query as CFDictionary)
	}

	func getAsData(_ key: String, context: LAContext) -> Data? {
		var query = getQuery(key: key)
		query[kSecUseAuthenticationContext as String] = context
		return getAsDataMaskedError(query: query as CFDictionary)
	}
}
