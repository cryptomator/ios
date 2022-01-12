//
//  MasterkeyCacheManager.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 11.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CommonCrypto
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
		let aesMasterkey = Array(masterkey.rawKey[0 ..< kCCKeySizeAES256])
		let macMasterKey = Array(masterkey.rawKey[kCCKeySizeAES256 ..< (2 * kCCKeySizeAES256)])
		let cachedMasterkey = CachedMasterkey(aesMasterKey: aesMasterkey, macMasterKey: macMasterKey)
		let jsonEncoder = JSONEncoder()
		try keychain.set(vaultUID, value: try jsonEncoder.encode(cachedMasterkey))
	}

	public func getMasterkey(forVaultUID vaultUID: String) throws -> Masterkey? {
		guard let data = keychain.getAsData(vaultUID) else {
			return nil
		}
		let jsonDecoder = JSONDecoder()
		let cachedMasterkey = try jsonDecoder.decode(CachedMasterkey.self, from: data)
		return Masterkey.createFromRaw(aesMasterKey: cachedMasterkey.aesMasterKey, macMasterKey: cachedMasterkey.macMasterKey)
	}

	public func removeCachedMasterkey(forVaultUID vaultUID: String) throws {
		do {
			try keychain.delete(vaultUID)
		} catch let CryptomatorKeychainError.unhandledError(statuscode) where statuscode == errSecItemNotFound {}
	}
}

struct CachedMasterkey: Codable {
	let aesMasterKey: [UInt8]
	let macMasterKey: [UInt8]
}
