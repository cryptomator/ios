//
//  VaultDBCacheTests.swift
//  CryptomatorCommonCoreTests
//
//  Created by Philipp Schmid on 10.07.21.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//
import CryptomatorCryptoLib
import Foundation
import GRDB
import XCTest
@testable import CryptomatorCloudAccessCore
@testable import CryptomatorCommonCore

class VaultDBCacheTests: XCTestCase {
	private var vaultCache: VaultDBCache!
	private let vaultUID = UUID().uuidString
	private lazy var account: CloudProviderAccount = {
		CloudProviderAccount(accountUID: UUID().uuidString, cloudProviderType: .dropbox)
	}()

	private lazy var vaultAccount: VaultAccount = {
		VaultAccount(vaultUID: vaultUID, delegateAccountUID: account.accountUID, vaultPath: CloudPath("/Vault"), vaultName: "Vault")
	}()

	private var inMemoryDB: DatabaseQueue!

	override func setUpWithError() throws {
		inMemoryDB = DatabaseQueue()
		vaultCache = VaultDBCache(dbWriter: inMemoryDB)
		try CryptomatorDatabase.migrator.migrate(inMemoryDB)
		try inMemoryDB.write { db in
			try account.save(db)
			try vaultAccount.save(db)
		}
	}

	func testCacheVault() throws {
		let cachedVault = try defaultCachedVault()
		try vaultCache.cache(cachedVault)
		let fetchedCachedVault = try vaultCache.getCachedVault(withVaultUID: vaultUID)

		XCTAssertEqual(cachedVault, fetchedCachedVault)
	}

	func testInvalidCachedVault() throws {
		let cachedVault = try defaultCachedVault()
		try vaultCache.cache(cachedVault)

		try vaultCache.invalidate(vaultUID: vaultUID)
		XCTAssertThrowsError(try vaultCache.getCachedVault(withVaultUID: vaultUID)) { error in
			guard case VaultCacheError.vaultNotFound = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}
	}

	func testCascadeOnVaultAccountDeletion() throws {
		let cachedVault = try defaultCachedVault()
		try vaultCache.cache(cachedVault)

		_ = try inMemoryDB.write { db in
			try vaultAccount.delete(db)
		}
		XCTAssertThrowsError(try vaultCache.getCachedVault(withVaultUID: vaultUID)) { error in
			guard case VaultCacheError.vaultNotFound = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}
	}

	func defaultCachedVault() throws -> CachedVault {
		let masterkey = Masterkey.createFromRaw(aesMasterKey: [UInt8](repeating: 0x55, count: 32), macMasterKey: [UInt8](repeating: 0x77, count: 32))
		let password = "PW"
		let masterkeyFileData = try MasterkeyFile.lock(masterkey: masterkey, vaultVersion: 999, passphrase: password)
		let vaultConfig = VaultConfig(id: "ABB9F673-F3E8-41A7-A43B-D29F5DA65068", format: 8, cipherCombo: .sivCTRMAC, shorteningThreshold: 220)
		let token = try vaultConfig.toToken(keyId: "masterkeyfile:masterkey.cryptomator", rawKey: masterkey.rawKey)
		return CachedVault(vaultUID: vaultUID, masterkeyFileData: masterkeyFileData, vaultConfigToken: token, lastUpToDateCheck: Date())
	}
}

extension CachedVault: Equatable {
	public static func == (lhs: CachedVault, rhs: CachedVault) -> Bool {
		return lhs.vaultUID == rhs.vaultUID && lhs.masterkeyFileData == rhs.masterkeyFileData && lhs.vaultConfigToken == rhs.vaultConfigToken
	}
}
