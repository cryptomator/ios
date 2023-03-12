//
//  MasterkeyCacheManager.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 11.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCryptoLib
import Foundation

public protocol MasterkeyCacheManager {
	func cacheMasterkey(_ masterkey: Masterkey, forVaultUID vaultUID: String) throws
	func getMasterkey(forVaultUID vaultUID: String) throws -> Masterkey?
	func removeCachedMasterkey(forVaultUID vaultUID: String) throws
}

protocol MasterkeyCacheHelper {
	func shouldCacheMasterkey(forVaultUID vaultUID: String) -> Bool
}

public class MasterkeyCacheKeychainManager: MasterkeyCacheManager {
	public static let shared = MasterkeyCacheKeychainManager(keychain: CryptomatorKeychain(service: "masterkeyCache"))
	private let keychain: CryptomatorKeychainType

	init(keychain: CryptomatorKeychainType) {
		self.keychain = keychain
	}

	public func cacheMasterkey(_ masterkey: Masterkey, forVaultUID vaultUID: String) throws {
		let cachedMasterkey = CachedMasterkey(rawKey: masterkey.rawKey)
		let jsonEncoder = JSONEncoder()
		try keychain.set(vaultUID, value: jsonEncoder.encode(cachedMasterkey))
	}

	public func getMasterkey(forVaultUID vaultUID: String) throws -> Masterkey? {
		guard let data = keychain.getAsData(vaultUID) else {
			return nil
		}
		let jsonDecoder = JSONDecoder()
		let cachedMasterkey = try jsonDecoder.decode(CachedMasterkey.self, from: data)
		return Masterkey.createFromRaw(rawKey: cachedMasterkey.rawKey)
	}

	public func removeCachedMasterkey(forVaultUID vaultUID: String) throws {
		do {
			try keychain.delete(vaultUID)
		} catch let CryptomatorKeychainError.unhandledError(statuscode) where statuscode == errSecItemNotFound {}
	}
}

struct CachedMasterkey: Codable {
	let rawKey: [UInt8]
}
