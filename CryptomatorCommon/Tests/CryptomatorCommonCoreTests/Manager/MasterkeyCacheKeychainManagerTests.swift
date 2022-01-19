//
//  MasterkeyCacheKeychainManagerTests.swift
//
//
//  Created by Philipp Schmid on 11.01.22.
//

import XCTest
@testable import CryptomatorCommonCore
@testable import CryptomatorCryptoLib

class MasterkeyCacheKeychainManagerTests: XCTestCase {
	var cryptomatorKeychainMock: CryptomatorKeychainMock!
	var masterkeyCacheManager: MasterkeyCacheManager!
	let vaultUID = "VaultUID-12345"

	override func setUpWithError() throws {
		cryptomatorKeychainMock = CryptomatorKeychainMock()
		masterkeyCacheManager = MasterkeyCacheKeychainManager(keychain: cryptomatorKeychainMock)
	}

	// MARK: Cache Masterkey

	func testCacheMasterkey() throws {
		let aesMasterkey = [UInt8](repeating: 0x55, count: 32)
		let macMasterkey = [UInt8](repeating: 0x77, count: 32)
		let masterkey = Masterkey.createFromRaw(aesMasterKey: aesMasterkey, macMasterKey: macMasterkey)

		try masterkeyCacheManager.cacheMasterkey(masterkey, forVaultUID: vaultUID)

		XCTAssertEqual(1, cryptomatorKeychainMock.setValueCallsCount)
		let passedValue = try XCTUnwrap(cryptomatorKeychainMock.setValueReceivedArguments?.value)
		let cachedMasterkey = try JSONDecoder().decode(CachedMasterkey.self, from: passedValue)
		XCTAssertEqual(aesMasterkey + macMasterkey, cachedMasterkey.rawKey)
		XCTAssertEqual(vaultUID, cryptomatorKeychainMock.setValueReceivedArguments?.key)
	}

	// MARK: Remove Cached Masterkey

	func testRemoveCachedMasterkey() throws {
		try masterkeyCacheManager.removeCachedMasterkey(forVaultUID: vaultUID)
		XCTAssertEqual([vaultUID], cryptomatorKeychainMock.deleteReceivedInvocations)
	}

	func testRemoveCachedMasterkeyNoEntryInKeychain() throws {
		cryptomatorKeychainMock.deleteThrowableError = CryptomatorKeychainError.unhandledError(status: errSecItemNotFound)
		try masterkeyCacheManager.removeCachedMasterkey(forVaultUID: vaultUID)
	}

	// MARK: Get Cached Masterkey

	func testGetCachedMasterkey() throws {
		let aesMasterkey = [UInt8](repeating: 0x55, count: 32)
		let macMasterkey = [UInt8](repeating: 0x77, count: 32)
		let masterkey = Masterkey.createFromRaw(aesMasterKey: aesMasterkey, macMasterKey: macMasterkey)
		let cachedMasterkey = CachedMasterkey(rawKey: masterkey.rawKey)
		let encodedCachedMasterkey = try JSONEncoder().encode(cachedMasterkey)

		cryptomatorKeychainMock.getAsDataClosure = { _ in
			return encodedCachedMasterkey
		}

		let retrievedCachedMasterkey = try masterkeyCacheManager.getMasterkey(forVaultUID: vaultUID)
		XCTAssertEqual(masterkey.aesMasterKey, retrievedCachedMasterkey?.aesMasterKey)
		XCTAssertEqual(masterkey.macMasterKey, retrievedCachedMasterkey?.macMasterKey)
	}

	func testGetCachedMasterkeyNoEntryInKeychain() throws {
		cryptomatorKeychainMock.getAsDataClosure = { _ in
			return nil
		}

		let retrievedCachedMasterkey = try masterkeyCacheManager.getMasterkey(forVaultUID: vaultUID)
		XCTAssertNil(retrievedCachedMasterkey)
	}
}
