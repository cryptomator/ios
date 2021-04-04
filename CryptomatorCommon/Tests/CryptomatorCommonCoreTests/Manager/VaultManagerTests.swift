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
import Promises
import XCTest
@testable import CryptomatorCommonCore
@testable import CryptomatorCryptoLib

class VaultManagerMock: VaultManager {
	var savedMasterkeys = [String: Masterkey]()
	var savedPasswords = [String: String]()
	var removedVaultUIDs = [String]()
	var addedFileProviderDomains = [String: CloudPath]()
	override func saveFileProviderConformMasterkeyToKeychain(_ masterkey: Masterkey, forVaultUID vaultUID: String, vaultVersion: Int, password: String, storePasswordInKeychain: Bool) throws {
		savedMasterkeys[vaultUID] = masterkey
		if storePasswordInKeychain {
			savedPasswords[vaultUID] = password
		}
		return
	}

	override func exportMasterkey(_ masterkey: Masterkey, vaultVersion: Int, password: String) throws -> Data {
		return try MasterkeyFile.lock(masterkey: masterkey, vaultVersion: 7, passphrase: password, pepper: [UInt8](), scryptCostParam: 2)
	}

	override func removeFileProviderDomain(withVaultUID vaultUID: String) -> Promise<Void> {
		removedVaultUIDs.append(vaultUID)
		return Promise(())
	}

	override func addFileProviderDomain(forVaultUID vaultUID: String, vaultPath: CloudPath) -> Promise<Void> {
		addedFileProviderDomains[vaultUID] = vaultPath
		return Promise(())
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
	var dbPool: DatabasePool!
	override func setUpWithError() throws {
		tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true, attributes: nil)
		dbPool = try DatabasePool(path: tmpDir.appendingPathComponent("db.sqlite").path)
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
		// Set all objects related to the sqlite database to nil to avoid warnings about database integrity when deleting the test database.
		manager = nil
		providerAccountManager = nil
		providerManager = nil
		accountManager = nil
		dbPool = nil
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
			let masterkeyFile = try MasterkeyFile.withContentFromData(data: masterkeyData)
			let masterkey = try masterkeyFile.unlock(passphrase: "pw")

			XCTAssertNotNil(VaultManager.cachedDecorators[vaultUID])
			guard VaultManager.cachedDecorators[vaultUID] is VaultFormat7ShorteningProviderDecorator else {
				XCTFail("VaultDecorator has wrong type")
				return
			}
			let vaultAccount = try accountManager.getAccount(with: vaultUID)
			XCTAssertEqual(vaultUID, vaultAccount.vaultUID)
			XCTAssertEqual(delegateAccountUID, vaultAccount.delegateAccountUID)
			XCTAssertEqual(vaultPath, vaultAccount.vaultPath)
			guard let managerMock = manager as? VaultManagerMock else {
				XCTFail("Could not convert manager to VaultManagerMock")
				return
			}
			XCTAssertEqual(managerMock.savedMasterkeys[vaultUID], masterkey)
			XCTAssertEqual(1, managerMock.addedFileProviderDomains.count)
			XCTAssertEqual(vaultPath, managerMock.addedFileProviderDomains[vaultUID])
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
		let masterkeyPath = vaultPath.appendingPathComponent("masterkey.cryptomator")
		guard let managerMock = manager as? VaultManagerMock else {
			XCTFail("Could not convert manager to VaultManagerMock")
			return
		}
		let masterkey = Masterkey.createFromRaw(aesMasterKey: [UInt8](repeating: 0x55, count: 32), macMasterKey: [UInt8](repeating: 0x77, count: 32))
		cloudProviderMock.filesToDownload[masterkeyPath.path] = try managerMock.exportMasterkey(masterkey, vaultVersion: 7, password: "pw")
		let vaultUID = UUID().uuidString
		manager.createFromExisting(withVaultID: vaultUID, delegateAccountUID: delegateAccountUID, masterkeyPath: masterkeyPath, password: "pw", storePasswordInKeychain: true).then { [self] in
			XCTAssertNotNil(VaultManager.cachedDecorators[vaultUID])
			guard VaultManager.cachedDecorators[vaultUID] is VaultFormat7ShorteningProviderDecorator else {
				XCTFail("VaultDecorator has wrong type")
				return
			}
			let vaultAccount = try accountManager.getAccount(with: vaultUID)
			XCTAssertEqual(vaultUID, vaultAccount.vaultUID)
			XCTAssertEqual(delegateAccountUID, vaultAccount.delegateAccountUID)
			XCTAssertEqual(vaultPath, vaultAccount.vaultPath)
			guard let managerMock = manager as? VaultManagerMock else {
				XCTFail("Could not convert manager to VaultManagerMock")
				return
			}
			XCTAssertEqual(managerMock.savedMasterkeys[vaultUID], masterkey)
			XCTAssertEqual(1, managerMock.addedFileProviderDomains.count)
			XCTAssertEqual(vaultPath, managerMock.addedFileProviderDomains[vaultUID])
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
		let masterkey = Masterkey.createFromRaw(aesMasterKey: [UInt8](repeating: 0x55, count: 32), macMasterKey: [UInt8](repeating: 0x77, count: 32))
		let decorator = try manager.createVaultDecorator(from: masterkey, vaultUID: vaultUID, vaultVersion: 7)
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
		let masterkey = Masterkey.createFromRaw(aesMasterKey: [UInt8](repeating: 0x55, count: 32), macMasterKey: [UInt8](repeating: 0x77, count: 32))
		let decorator = try manager.createVaultDecorator(from: masterkey, vaultUID: vaultUID, vaultVersion: 6)
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
		let masterkey = Masterkey.createFromRaw(aesMasterKey: [UInt8](repeating: 0x55, count: 32), macMasterKey: [UInt8](repeating: 0x77, count: 32))
		XCTAssertThrowsError(try manager.createVaultDecorator(from: masterkey, vaultUID: vaultUID, vaultVersion: 1)) { error in
			guard case VaultManagerError.vaultVersionNotSupported = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}
	}
}

extension Masterkey: Equatable {
	public static func == (lhs: Masterkey, rhs: Masterkey) -> Bool {
		return lhs.aesMasterKey == rhs.aesMasterKey && lhs.macMasterKey == rhs.macMasterKey
	}
}
