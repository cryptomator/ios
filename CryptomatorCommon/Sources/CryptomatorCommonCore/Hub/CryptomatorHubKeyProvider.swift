//
//  CryptomatorHubKeyProvider.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 20.07.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptoKit
import Foundation

public struct CryptomatorHubKeyProvider {
	public static let shared: CryptomatorHubKeyProvider = .init(keychain: CryptomatorKeychain.hub)
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
