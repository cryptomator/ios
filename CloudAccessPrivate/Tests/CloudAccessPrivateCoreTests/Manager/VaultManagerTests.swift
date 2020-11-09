//
//  VaultManagerTests.swift
//  CloudAccessPrivateCoreTests
//
//  Created by Philipp Schmid on 02.11.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import Foundation
import GRDB
import XCTest
@testable import CloudAccessPrivateCore
@testable import CryptomatorCryptoLib

class VaultManagerMock: VaultManager {
	var savedMasterkeys = [String: Masterkey]()
	var savedPasswords = [String: String]()
	override func saveFileProviderConformMasterkeyToKeychain(_ masterkey: Masterkey, forVaultUID vaultUID: String, password: String, storePasswordInKeychain: Bool) throws {
		savedMasterkeys[vaultUID] = masterkey
		if storePasswordInKeychain {
			savedPasswords[vaultUID] = password
		}
		return
	}

	override func exportMasterkey(_ masterkey: Masterkey, password: String) throws -> Data {
		return try masterkey.exportEncrypted(password: password, scryptCostParam: 2)
	}
}

class CloudProviderManagerMock: CloudProviderManager {
	let provider = CloudProviderMock()
	override func getProvider(with accountUID: String) throws -> CloudProvider {
		return provider
	}
}

class VaultManagerTests: XCTestCase {
	var manager: VaultManager!
	var accountManager: VaultAccountManager!
	var providerManager: CloudProviderManagerMock!
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
		providerManager = CloudProviderManagerMock(accountManager: providerAccountManager)
		accountManager = VaultAccountManager(dbPool: dbPool)
		manager = VaultManagerMock(providerManager: providerManager, vaultAccountManager: accountManager)
	}

	override func tearDownWithError() throws {
		providerAccountManager = nil
		accountManager = nil
		try FileManager.default.removeItem(at: tmpDir)
	}

	func testCreateNewVault() throws {
		let expectation = XCTestExpectation()
		let delegateAccountUID = UUID().uuidString
		let account = CloudProviderAccount(accountUID: delegateAccountUID, cloudProviderType: .dropbox)
		try providerAccountManager.saveNewAccount(account)
		let cloudProviderMock = providerManager.provider
		let vaultUID = UUID().uuidString
		let vaultPath = CloudPath("/Vault/")
		manager.createNewVault(withVaultID: vaultUID, delegateAccountUID: account.accountUID, vaultPath: vaultPath, password: "pw", storePasswordInKeychain: false).then { [self] in
			XCTAssertEqual(vaultPath.path, self.providerManager.provider.createdFolders[0])
			XCTAssertEqual(CloudPath("/Vault/d").path, self.providerManager.provider.createdFolders[1])
			XCTAssertTrue(cloudProviderMock.createdFolders[2].hasPrefix(CloudPath("/Vault/d/").path) && cloudProviderMock.createdFolders[2].count == 11)
			XCTAssertTrue(cloudProviderMock.createdFolders[3].hasPrefix(cloudProviderMock.createdFolders[2] + "/") && cloudProviderMock.createdFolders[3].count == 42)
			guard let masterkeyData = cloudProviderMock.createdFiles["/Vault/masterkey.cryptomator"] else {
				XCTFail("Masterkey not uploaded")
				return
			}
			let masterkey = try Masterkey.createFromMasterkeyFile(jsonData: masterkeyData, password: "pw")

			XCTAssertNotNil(VaultManager.cachedDecorators[vaultUID])
			let vaultAccount = try accountManager.getAccount(with: vaultUID)
			XCTAssertEqual(vaultUID, vaultAccount.vaultUID)
			XCTAssertEqual(delegateAccountUID, vaultAccount.delegateAccountUID)
			XCTAssertEqual(vaultPath, vaultAccount.vaultPath)
			guard let managerMock = manager as? VaultManagerMock else {
				XCTFail("Could not convert manager to VaultManagerMock")
				return
			}
			XCTAssertEqual(managerMock.savedMasterkeys[vaultUID], masterkey)
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testCreateFromExisting() throws {
		let expectation = XCTestExpectation()
		let delegateAccountUID = UUID().uuidString
		let account = CloudProviderAccount(accountUID: delegateAccountUID, cloudProviderType: .dropbox)
		try providerAccountManager.saveNewAccount(account)
		let cloudProviderMock = providerManager.provider
		let vaultPath = CloudPath("/ExistingVault/")
		guard let managerMock = manager as? VaultManagerMock else {
			XCTFail("Could not convert manager to VaultManagerMock")
			return
		}
		let masterkey = Masterkey.createFromRaw(aesMasterKey: [UInt8](repeating: 0x55, count: 32), macMasterKey: [UInt8](repeating: 0x77, count: 32), version: 7)
		cloudProviderMock.filesToDownload[vaultPath.path] = try managerMock.exportMasterkey(masterkey, password: "pw")
		let vaultUID = UUID().uuidString
		manager.createFromExisting(withVaultID: vaultUID, delegateAccountUID: delegateAccountUID, vaultPath: vaultPath, password: "pw", storePasswordInKeychain: true).then { [self] in
			XCTAssertNotNil(VaultManager.cachedDecorators[vaultUID])
			let vaultAccount = try accountManager.getAccount(with: vaultUID)
			XCTAssertEqual(vaultUID, vaultAccount.vaultUID)
			XCTAssertEqual(delegateAccountUID, vaultAccount.delegateAccountUID)
			XCTAssertEqual(vaultPath, vaultAccount.vaultPath)
			guard let managerMock = manager as? VaultManagerMock else {
				XCTFail("Could not convert manager to VaultManagerMock")
				return
			}
			XCTAssertEqual(managerMock.savedMasterkeys[vaultUID], masterkey)
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testCreateVaultDecoratorV7() throws {
		let delegateAccountUID = UUID().uuidString
		let account = CloudProviderAccount(accountUID: delegateAccountUID, cloudProviderType: .dropbox)
		try providerAccountManager.saveNewAccount(account)
		let vaultUID = UUID().uuidString
		let vaultPath = CloudPath("/VaultV7/")
		let vaultAccount = VaultAccount(vaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultPath: vaultPath, lastUpToDateCheck: Date())
		try accountManager.saveNewAccount(vaultAccount)
		let masterkey = Masterkey.createFromRaw(aesMasterKey: [UInt8](repeating: 0x55, count: 32), macMasterKey: [UInt8](repeating: 0x77, count: 32), version: 7)
		let decorator = try manager.createVaultDecorator(from: masterkey, vaultUID: vaultUID)
		guard decorator is VaultFormat7ShorteningProviderDecorator else {
			XCTFail("Decorator is not a VaultFormat7ShorteningProviderDecorator")
			return
		}
		XCTAssertNotNil(VaultManager.cachedDecorators[vaultUID])
	}

	func testCreateVaultDecoratorV6() throws {
		let delegateAccountUID = UUID().uuidString
		let account = CloudProviderAccount(accountUID: delegateAccountUID, cloudProviderType: .dropbox)
		try providerAccountManager.saveNewAccount(account)
		let vaultUID = UUID().uuidString
		let vaultPath = CloudPath("/VaultV6/")
		let vaultAccount = VaultAccount(vaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultPath: vaultPath, lastUpToDateCheck: Date())
		try accountManager.saveNewAccount(vaultAccount)
		let masterkey = Masterkey.createFromRaw(aesMasterKey: [UInt8](repeating: 0x55, count: 32), macMasterKey: [UInt8](repeating: 0x77, count: 32), version: 6)
		let decorator = try manager.createVaultDecorator(from: masterkey, vaultUID: vaultUID)
		guard decorator is VaultFormat6ShorteningProviderDecorator else {
			XCTFail("Decorator is not a VaultFormat6ShorteningProviderDecorator")
			return
		}
		XCTAssertNotNil(VaultManager.cachedDecorators[vaultUID])
	}

	func testCreateVaultDecoratorThrowsForNonSupportedVaultVersion() throws {
		let delegateAccountUID = UUID().uuidString
		let account = CloudProviderAccount(accountUID: delegateAccountUID, cloudProviderType: .dropbox)
		try providerAccountManager.saveNewAccount(account)
		let vaultUID = UUID().uuidString
		let vaultPath = CloudPath("/VaultV1/")
		let vaultAccount = VaultAccount(vaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultPath: vaultPath, lastUpToDateCheck: Date())
		try accountManager.saveNewAccount(vaultAccount)
		let masterkey = Masterkey.createFromRaw(aesMasterKey: [UInt8](repeating: 0x55, count: 32), macMasterKey: [UInt8](repeating: 0x77, count: 32), version: 1)
		XCTAssertThrowsError(try manager.createVaultDecorator(from: masterkey, vaultUID: vaultUID)) { error in
			guard case VaultManagerError.vaultVersionNotSupported = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}
	}
}

extension Masterkey: Equatable {
	public static func == (lhs: Masterkey, rhs: Masterkey) -> Bool {
		return lhs.aesMasterKey == rhs.aesMasterKey && lhs.macMasterKey == rhs.macMasterKey && lhs.version == rhs.version
	}
}
