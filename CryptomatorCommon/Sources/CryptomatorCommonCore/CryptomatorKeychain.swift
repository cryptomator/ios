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

protocol CryptomatorKeychainType {
	func set(_ key: String, value: Data) throws
	func getAsData(_ key: String) -> Data?
	func delete(_ key: String) throws
	func queryWithDict(_ query: [String: AnyObject]) -> [String: Any]
}

class CryptomatorKeychain: CryptomatorKeychainType {
	let service: String
	static let bundleId = CryptomatorConstants.mainAppBundleId
	static let pCloud = CryptomatorKeychain(service: "pCloud.auth")
	static let s3 = CryptomatorKeychain(service: "s3.auth")
	static let webDAV = CryptomatorKeychain(service: "webDAV.auth")
	static let localFileSystem = CryptomatorKeychain(service: "localFileSystem.auth")
	static let upgrade = CryptomatorKeychain(service: "upgrade")
	static let keepUnlocked = CryptomatorKeychain(service: "keepUnlocked")
	static let hub = CryptomatorKeychain(service: "hub")

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
		let setQuery = setQuery(key: key, value: value) as CFDictionary
		var defaultGetQuery = getQuery(key: key)
		defaultGetQuery[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUIFail
		let getQuery = defaultGetQuery as CFDictionary
		let currentData: Data?
		do {
			currentData = try getAsData(query: getQuery)
		} catch let CryptomatorKeychainError.unhandledError(status: statusCode) where statusCode == errSecItemNotFound {
			let status = SecItemAdd(setQuery, nil)
			guard status == noErr else {
				throw CryptomatorKeychainError.unhandledError(status: status)
			}
			return
		} catch let CryptomatorKeychainError.unhandledError(statuscode) where statuscode == errSecInteractionNotAllowed {
			try updateRestrictedAccessEntry(key: key, value: value)
			return
		}
		if currentData != value {
			try update(data: value, query: setQuery)
		}
	}

	func getAsData(_ key: String) -> Data? {
		let query = getQuery(key: key) as CFDictionary
		return getAsDataMaskedError(query: query)
	}

	func delete(_ key: String) throws {
		let query = deleteQuery(key: key) as CFDictionary
		let status = SecItemDelete(query)
		if status != noErr, status != errSecItemNotFound {
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

	private func update(data: Data, query: CFDictionary) throws {
		let status = SecItemUpdate(query, [kSecValueData: data as AnyObject] as NSDictionary)
		guard status == noErr else {
			throw CryptomatorKeychainError.unhandledError(status: status)
		}
	}

	/**
	 Updates a restricted access item in the keychain without a biometric authentication prompt.

	 As calling `SecItemUpdate(_:_:)` prompts the user for biometric authentication, the existing item
	 is removed first and then recreated with the new data.
	 */
	private func updateRestrictedAccessEntry(key: String, value: Data) throws {
		try delete(key)
		try set(key, value: value)
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
