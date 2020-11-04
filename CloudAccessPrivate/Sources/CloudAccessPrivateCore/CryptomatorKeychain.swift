//
//  CryptomatorKeychain.swift
//  CloudAccessPrivateCore
//
//  Created by Philipp Schmid on 22.10.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation
class CryptomatorKeychain {
	let service: String
	static let webDAV = CryptomatorKeychain(service: "webDAV.auth")
	static let localFileSystem = CryptomatorKeychain(service: "localFileSystem.auth")
	static let vault = CryptomatorKeychain(service: "cryptomatorVault")

	init(service: String) {
		self.service = service
	}

	func queryWithDict(_ query: [String: AnyObject]) -> CFDictionary {
		let bundleId = Bundle.main.bundleIdentifier ?? ""
		var queryDict = query

		queryDict[kSecClass as String] = kSecClassGenericPassword
		queryDict[kSecAttrService as String] = "\(bundleId).\(service)" as AnyObject?
		queryDict[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
//		queryDict[kSecAttrAccessGroup as String] = "<TEAMID>.de.skymatic.Cryptomator" as AnyObject

		return queryDict as CFDictionary
	}

	func set(_ key: String, value: Data) -> Bool {
		let query = queryWithDict([
			kSecAttrAccount as String: key as AnyObject,
			kSecValueData as String: value as AnyObject
		])

		SecItemDelete(query)
		return SecItemAdd(query, nil) == noErr
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

	func delete(_ key: String) -> Bool {
		let query = queryWithDict([
			kSecAttrAccount as String: key as AnyObject
		])

		return SecItemDelete(query) == noErr
	}
}
