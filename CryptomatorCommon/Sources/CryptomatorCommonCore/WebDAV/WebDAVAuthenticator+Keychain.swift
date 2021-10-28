//
//  WebDAVAuthenticator+Keychain.swift
//	CryptomatorCommonCore
//
//  Created by Philipp Schmid on 21.10.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation

public enum WebDAVAuthenticatorKeychainError: Error {
	case credentialDuplicate(existingIdentifier: String)
}

public extension WebDAVAuthenticator {
	static func getCredentialFromKeychain(with accountUID: String) -> WebDAVCredential? {
		return CryptomatorKeychain.webDAV.get(accountUID)
	}

	/**
	 Saves a WebDAV credential to the keychain.

	 Checks for duplicates before saving the passed credential to the keychain.
	 A duplicate is defined as any other WebDAV credential with the same `baseURL` and `username`.
	 - Throws: An WebDAVAuthenticatorKeychainError.credentialDuplicate if a WebDAVCredential already exists in the keychain with the same `baseURL` and `username` but a different identifier.
	 The error includes the identifier (`existingIdentifier`) of the WebDAVCredentials item, which is already stored in the keychain and caused the error.
	 */
	static func saveCredentialToKeychain(_ credential: WebDAVCredential) throws {
		let existingCredentials = try CryptomatorKeychain.webDAV.getAllWebDAVCredentials()
		if let existingCredential = existingCredentials.first(where: { $0 == credential && $0.identifier != credential.identifier }) {
			throw WebDAVAuthenticatorKeychainError.credentialDuplicate(existingIdentifier: existingCredential.identifier)
		}

		let jsonEnccoder = JSONEncoder()
		let encodedCredential = try jsonEnccoder.encode(credential)
		try CryptomatorKeychain.webDAV.set(credential.identifier, value: encodedCredential)
	}

	static func removeCredentialFromKeychain(with accountUID: String) throws {
		try CryptomatorKeychain.webDAV.delete(accountUID)
	}

	static func removeUnusedWebDAVCredentials(existingAccountUIDs: [String]) throws {
		let existingCredentials = try CryptomatorKeychain.webDAV.getAllWebDAVCredentials()
		let unusedCredentials = existingCredentials.filter { !existingAccountUIDs.contains($0.identifier) }
		for unusedCredential in unusedCredentials {
			try removeCredentialFromKeychain(with: unusedCredential.identifier)
		}
	}
}

extension WebDAVCredential: Equatable {
	public static func == (lhs: WebDAVCredential, rhs: WebDAVCredential) -> Bool {
		return lhs.baseURL == rhs.baseURL && lhs.username == rhs.username
	}
}

extension CryptomatorKeychain {
	func get(_ key: String) -> WebDAVCredential? {
		guard let data = getAsData(key) else {
			return nil
		}
		do {
			let jsonDecoder = JSONDecoder()
			return try jsonDecoder.decode(WebDAVCredential.self, from: data)
		} catch {
			return nil
		}
	}

	func getAllWebDAVCredentials() throws -> [WebDAVCredential] {
		let query = queryWithDict([
			kSecReturnData as String: kCFBooleanTrue,
			kSecMatchLimit as String: kSecMatchLimitAll
		])
		var dataResult: AnyObject?
		let status = SecItemCopyMatching(query as CFDictionary, &dataResult)
		if status == errSecItemNotFound {
			return []
		}
		guard status == noErr else {
			throw CryptomatorKeychainError.unhandledError(status: status)
		}
		let results = dataResult as? [Data] ?? []
		let jsonDecoder = JSONDecoder()
		return try results.map { try jsonDecoder.decode(WebDAVCredential.self, from: $0) }
	}
}
