//
//  CryptomatorHubKeyProvider.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 20.07.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptoKit
import Dependencies
import Foundation

protocol CryptomatorHubKeyProvider {
	func getPublicKey() throws -> P384.KeyAgreement.PublicKey

	func getPrivateKey() throws -> P384.KeyAgreement.PrivateKey
}

private enum CryptomatorHubKeyProviderKey: DependencyKey {
	static let liveValue: CryptomatorHubKeyProvider = CryptomatorHubKeyProviderImpl(keychain: CryptomatorKeychain.hub)
	#if DEBUG
	static let testValue: CryptomatorHubKeyProvider = CryptomatorHubKeyProviderMock()
	#endif
}

extension DependencyValues {
	var cryptomatorHubKeyProvider: CryptomatorHubKeyProvider {
		get { self[CryptomatorHubKeyProviderKey.self] }
		set { self[CryptomatorHubKeyProviderKey.self] = newValue }
	}
}

public struct CryptomatorHubKeyProviderImpl: CryptomatorHubKeyProvider {
	public static let shared: CryptomatorHubKeyProviderImpl = .init(keychain: CryptomatorKeychain.hub)
	let keychain: CryptomatorKeychainType
	private let keychainKey = "privateKey"

	public func getPublicKey() throws -> P384.KeyAgreement.PublicKey {
		let privateKey = try getPrivateKey()
		return privateKey.publicKey
	}

	public func getPrivateKey() throws -> P384.KeyAgreement.PrivateKey {
		let privateKey: P384.KeyAgreement.PrivateKey
		if let existingKeyData = keychain.getAsData(keychainKey) {
			privateKey = try P384.KeyAgreement.PrivateKey(rawRepresentation: existingKeyData)
		} else {
			privateKey = P384.KeyAgreement.PrivateKey(compactRepresentable: false)
			try saveKey(privateKey)
		}
		return privateKey
	}

	private func saveKey(_ privateKey: P384.KeyAgreement.PrivateKey) throws {
		try keychain.set(keychainKey, value: privateKey.rawRepresentation)
	}

	public func delete() {
		try? keychain.delete(keychainKey)
	}
}

#if DEBUG

// MARK: - CryptomatorHubKeyProviderMock -

// swiftlint: disable all
final class CryptomatorHubKeyProviderMock: CryptomatorHubKeyProvider {
	// MARK: - getPublicKey

	var getPublicKeyThrowableError: Error?
	var getPublicKeyCallsCount = 0
	var getPublicKeyCalled: Bool {
		getPublicKeyCallsCount > 0
	}

	var getPublicKeyReturnValue: P384.KeyAgreement.PublicKey!
	var getPublicKeyClosure: (() throws -> P384.KeyAgreement.PublicKey)?

	func getPublicKey() throws -> P384.KeyAgreement.PublicKey {
		if let error = getPublicKeyThrowableError {
			throw error
		}
		getPublicKeyCallsCount += 1
		return try getPublicKeyClosure.map({ try $0() }) ?? getPublicKeyReturnValue
	}

	// MARK: - getPrivateKey

	var getPrivateKeyThrowableError: Error?
	var getPrivateKeyCallsCount = 0
	var getPrivateKeyCalled: Bool {
		getPrivateKeyCallsCount > 0
	}

	var getPrivateKeyReturnValue: P384.KeyAgreement.PrivateKey!
	var getPrivateKeyClosure: (() throws -> P384.KeyAgreement.PrivateKey)?

	func getPrivateKey() throws -> P384.KeyAgreement.PrivateKey {
		if let error = getPrivateKeyThrowableError {
			throw error
		}
		getPrivateKeyCallsCount += 1
		return try getPrivateKeyClosure.map({ try $0() }) ?? getPrivateKeyReturnValue
	}
}
// swiftlint: enable all
#endif
