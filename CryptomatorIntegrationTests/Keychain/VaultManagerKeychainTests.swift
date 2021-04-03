//
//  VaultManagerKeychainTests.swift
//  CryptomatorIntegrationTests
//
//  Created by Philipp Schmid on 07.11.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import GRDB
import XCTest
@testable import CloudAccessPrivateCore
@testable import CryptomatorCryptoLib
class VaultManagerKeychainTests: XCTestCase {
	var manager: VaultManager!
	var accountManager: VaultAccountManager!
	var providerManager: CloudProviderManager!
	var providerAccountManager: CloudProviderAccountManager!
	var tmpDir: URL!
	override func setUpWithError() throws {
		tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true, attributes: nil)
		let dbPool = try DatabasePool(path: tmpDir.appendingPathComponent("db.sqlite").path)
		try dbPool.write { db in
			try db.create(table: CloudProviderAccount.databaseTableName) { table in
				table.column(CloudProviderAccount.accountUIDKey, .text).primaryKey()
				table.column(CloudProviderAccount.cloudProviderTypeKey, .text).notNull()
			}
			try db.create(table: VaultAccount.databaseTableName) { table in
				table.column(VaultAccount.vaultUIDKey, .text).primaryKey()
				table.column(VaultAccount.delegateAccountUIDKey, .text).notNull()
				table.column(VaultAccount.vaultPathKey, .text).notNull()
				table.column(VaultAccount.lastUpToDateCheckKey, .date).notNull()
			}
		}
		providerAccountManager = CloudProviderAccountManager(dbPool: dbPool)
		providerManager = CloudProviderManager(accountManager: providerAccountManager)
		accountManager = VaultAccountManager(dbPool: dbPool)
		manager = VaultManager(providerManager: providerManager, vaultAccountManager: accountManager)
	}

	override func tearDownWithError() throws {
		try FileManager.default.removeItem(at: tmpDir)
	}

	func testSaveFileProviderConformMasterkeyToKeychainNoPWStored() throws {
		let masterkey = Masterkey.createFromRaw(aesMasterKey: [UInt8](repeating: 0x55, count: 32), macMasterKey: [UInt8](repeating: 0x77, count: 32))
		let vaultUID = UUID().uuidString
		let password = "pw"
		try manager.saveFileProviderConformMasterkeyToKeychain(masterkey, forVaultUID: vaultUID, vaultVersion: 7, password: password, storePasswordInKeychain: false)

		let masterkeyKeychainEntry = try manager.getVaultFromKeychain(forVaultUID: vaultUID)
		XCTAssertNil(masterkeyKeychainEntry.password)
		let storedMasterkeyFile = try MasterkeyFile.withContentFromData(data: masterkeyKeychainEntry.masterkeyData)
		let storedMasterkey = try storedMasterkeyFile.unlock(passphrase: password)
		XCTAssertEqual(masterkey.aesMasterKey, storedMasterkey.aesMasterKey)
		XCTAssertEqual(masterkey.macMasterKey, storedMasterkey.macMasterKey)
		XCTAssertEqual(7, storedMasterkeyFile.version)
		try CryptomatorKeychain.vault.delete(vaultUID)
	}

	func testSaveFileProviderConformMasterkeyToKeychainPWStored() throws {
		let masterkey = Masterkey.createFromRaw(aesMasterKey: [UInt8](repeating: 0x55, count: 32), macMasterKey: [UInt8](repeating: 0x77, count: 32))
		let vaultUID = UUID().uuidString
		let password = "pw"
		try manager.saveFileProviderConformMasterkeyToKeychain(masterkey, forVaultUID: vaultUID, vaultVersion: 7, password: password, storePasswordInKeychain: true)

		let masterkeyKeychainEntry = try manager.getVaultFromKeychain(forVaultUID: vaultUID)
		XCTAssertEqual(password, masterkeyKeychainEntry.password)
		let storedMasterkeyFile = try MasterkeyFile.withContentFromData(data: masterkeyKeychainEntry.masterkeyData)
		let storedMasterkey = try storedMasterkeyFile.unlock(passphrase: password)
		XCTAssertEqual(masterkey.aesMasterKey, storedMasterkey.aesMasterKey)
		XCTAssertEqual(masterkey.macMasterKey, storedMasterkey.macMasterKey)
		XCTAssertEqual(7, storedMasterkeyFile.version)
		try CryptomatorKeychain.vault.delete(vaultUID)
	}
}
