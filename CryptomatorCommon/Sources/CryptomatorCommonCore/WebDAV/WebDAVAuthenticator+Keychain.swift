//
//  WebDAVAuthenticator+Keychain.swift
//	CryptomatorCommonCore
//
//  Created by Philipp Schmid on 21.10.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Combine
import CryptomatorCloudAccessCore
import Foundation

public enum WebDAVAuthenticatorKeychainError: Error {
	case credentialDuplicate(existingIdentifier: String)
}

public protocol WebDAVCredentialManaging {
	var didUpdate: AnyPublisher<Void, Never> { get }

	func getCredentialFromKeychain(with accountUID: String) -> WebDAVCredential?
	/**
	 Saves a WebDAV credential to the keychain.

	 Checks for duplicates before saving the passed credential.
	 A duplicate is defined as any other WebDAV credential with the same `baseURL` and `username`.
	 - Throws: An WebDAVAuthenticatorKeychainError.credentialDuplicate if a WebDAVCredential already exists with the same `baseURL` and `username` but a different identifier.
	 The error includes the identifier (`existingIdentifier`) of the WebDAVCredentials item, which is already stored and caused the error.
	 */
	func saveCredentialToKeychain(_ credential: WebDAVCredential) throws

	func removeCredentialFromKeychain(with accountUID: String) throws

	func removeUnusedWebDAVCredentials(existingAccountUIDs: [String]) throws
}

public struct WebDAVCredentialManager: WebDAVCredentialManaging {
	public static let shared = WebDAVCredentialManager(keychain: CryptomatorKeychain.webDAV)

	public var didUpdate: AnyPublisher<Void, Never> {
		didUpdatePublisher.eraseToAnyPublisher()
	}

	let keychain: CryptomatorKeychainType
	private let didUpdatePublisher = PassthroughSubject<Void, Never>()

	public func getCredentialFromKeychain(with accountUID: String) -> WebDAVCredential? {
		return keychain.get(accountUID)
	}

	public func saveCredentialToKeychain(_ credential: WebDAVCredential) throws {
		let existingCredentials = try keychain.getAllWebDAVCredentials()
		if let existingCredential = existingCredentials.first(where: { $0 == credential && $0.identifier != credential.identifier }) {
			throw WebDAVAuthenticatorKeychainError.credentialDuplicate(existingIdentifier: existingCredential.identifier)
		}

		let jsonEnccoder = JSONEncoder()
		let encodedCredential = try jsonEnccoder.encode(credential)
		try keychain.set(credential.identifier, value: encodedCredential)
		didUpdatePublisher.send(())
	}

	public func removeCredentialFromKeychain(with accountUID: String) throws {
		try keychain.delete(accountUID)
		didUpdatePublisher.send(())
	}

	public func removeUnusedWebDAVCredentials(existingAccountUIDs: [String]) throws {
		let existingCredentials = try keychain.getAllWebDAVCredentials()
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

extension CryptomatorKeychainType {
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
