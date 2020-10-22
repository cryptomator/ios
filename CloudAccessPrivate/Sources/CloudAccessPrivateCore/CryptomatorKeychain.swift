//
//  CryptomatorKeychain.swift
//  CloudAccessPrivateCore
//
//  Created by Philipp Schmid on 22.10.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation
protocol CryptomatorKeychain {
	static var service: String { get }
}

extension CryptomatorKeychain {
	static func queryWithDict(_ query: [String: AnyObject]) -> CFDictionary {
		let bundleId = Bundle.main.bundleIdentifier ?? ""
		var queryDict = query

		queryDict[kSecClass as String] = kSecClassGenericPassword
		queryDict[kSecAttrService as String] = "\(bundleId).\(Self.service)" as AnyObject?
		queryDict[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
//		queryDict[kSecAttrAccessGroup as String] = "<TEAMID>.de.skymatic.Cryptomator" as AnyObject

		return queryDict as CFDictionary
	}

	static func set(_ key: String, value: Data) -> Bool {
		let query = Self.queryWithDict([
			kSecAttrAccount as String: key as AnyObject,
			kSecValueData as String: value as AnyObject
		])

		SecItemDelete(query)
		return SecItemAdd(query, nil) == noErr
	}

	static func getAsData(_ key: String) -> Data? {
		let query = Self.queryWithDict([
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

	static func delete(_ key: String) -> Bool {
		let query = Self.queryWithDict([
			kSecAttrAccount as String: key as AnyObject
		])

		return SecItemDelete(query) == noErr
	}
}
