//
//  VaultManagerTests.swift
//  CryptomatorCommonCoreTests
//
//  Created by Philipp Schmid on 02.11.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation
import GRDB
import Promises
import XCTest
@testable import CryptomatorCloudAccessCore
@testable import CryptomatorCommonCore
@testable import CryptomatorCryptoLib

class VaultManagerMock: VaultDBManager {
	var removedVaultUIDs = [String]()
	var addedFileProviderDomainDisplayName = [String: String]()

	override func exportMasterkey(_ masterkey: Masterkey, vaultVersion: Int, password: String) throws -> Data {
		return try MasterkeyFile.lock(masterkey: masterkey, vaultVersion: vaultVersion, passphrase: password, pepper: [UInt8](), scryptCostParam: 2)
	}

	override func removeFileProviderDomain(withVaultUID vaultUID: String) -> Promise<Void> {
		removedVaultUIDs.append(vaultUID)
		return Promise(())
	}

	override func addFileProviderDomain(forVaultUID vaultUID: String, displayName: String) -> Promise<Void> {
		addedFileProviderDomainDisplayName[vaultUID] = displayName
		return Promise(())
	}
}

class CloudProviderManagerMock: CloudProviderDBManager {
	let provider = CloudProviderMock()
	override func getProvider(with accountUID: String) throws -> CloudProvider {
		return provider
	}
}

class VaultManagerTests: XCTestCase {
	var manager: VaultDBManager!
	var accountManager: VaultAccountManager!
	var providerManager: CloudProviderManagerMock!
	var providerAccountManager: CloudProviderAccountDBManager!
	var vaultCacheMock: VaultCacheMock!
	var passwordManagerMock: VaultPasswordManagerMock!
	var tmpDir: URL!
	var dbPool: DatabasePool!
	override func setUpWithError() throws {
		tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true, attributes: nil)
		dbPool = try DatabasePool(path: tmpDir.appendingPathComponent("db.sqlite").path)
		try CryptomatorDatabase.migrator.migrate(dbPool)

		providerAccountManager = CloudProviderAccountDBManager(dbPool: dbPool)
		providerManager = CloudProviderManagerMock(accountManager: providerAccountManager)
		accountManager = VaultAccountDBManager(dbPool: dbPool)
		vaultCacheMock = VaultCacheMock()
		passwordManagerMock = VaultPasswordManagerMock()
		manager = VaultManagerMock(providerManager: providerManager, vaultAccountManager: accountManager, vaultCache: vaultCacheMock, passwordManager: passwordManagerMock)
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

	// swiftlint:disable:next function_body_length
	func testCreateNewVault() throws {
		let expectation = XCTestExpectation()
		let delegateAccountUID = UUID().uuidString
		let account = CloudProviderAccount(accountUID: delegateAccountUID, cloudProviderType: .dropbox)
		try providerAccountManager.saveNewAccount(account)
		let cloudProviderMock = providerManager.provider
		let vaultUID = UUID().uuidString
		let vaultPath = CloudPath("/Vault/")
		manager.createNewVault(withVaultUID: vaultUID, delegateAccountUID: account.accountUID, vaultPath: vaultPath, password: "pw", storePasswordInKeychain: false).then { [self] in
			XCTAssertEqual(vaultPath.path, self.providerManager.provider.createdFolders[0])
			XCTAssertEqual(CloudPath("/Vault/d").path, self.providerManager.provider.createdFolders[1])
			XCTAssertTrue(cloudProviderMock.createdFolders[2].hasPrefix(CloudPath("/Vault/d/").path) && cloudProviderMock.createdFolders[2].count == 11)
			XCTAssertTrue(cloudProviderMock.createdFolders[3].hasPrefix(cloudProviderMock.createdFolders[2] + "/") && cloudProviderMock.createdFolders[3].count == 42)

			guard let masterkeyData = cloudProviderMock.createdFiles["/Vault/masterkey.cryptomator"] else {
				XCTFail("Masterkey not uploaded")
				return
			}
			let uploadedMasterkeyFile = try MasterkeyFile.withContentFromData(data: masterkeyData)
			XCTAssertEqual(999, uploadedMasterkeyFile.version)

			let uploadedMasterkey = try uploadedMasterkeyFile.unlock(passphrase: "pw")

			XCTAssertNotNil(VaultDBManager.cachedDecorators[vaultUID])
			guard VaultDBManager.cachedDecorators[vaultUID] is VaultFormat8ProviderDecorator else {
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

			XCTAssertEqual(1, managerMock.addedFileProviderDomainDisplayName.count)
			XCTAssertEqual(vaultPath.lastPathComponent, managerMock.addedFileProviderDomainDisplayName[vaultUID])

			guard let cachedVault = vaultCacheMock.cachedVaults[vaultUID] else {
				XCTFail("Vault not cached for \(vaultUID)")
				return
			}
			let cachedMasterkeyFile = try MasterkeyFile.withContentFromData(data: cachedVault.masterkeyFileData)
			let cachedMasterkey = try cachedMasterkeyFile.unlock(passphrase: "pw")
			XCTAssertEqual(uploadedMasterkey, cachedMasterkey)

			// Vault config checks
			let vaultConfigPath = vaultPath.appendingPathComponent("vault.cryptomator")
			guard let uploadedVaultConfigData = cloudProviderMock.createdFiles[vaultConfigPath.path] else {
				XCTFail("Vault config not uploaded")
				return
			}
			let uploadedVaultConfigToken = String(data: uploadedVaultConfigData, encoding: .utf8)

			guard let savedVaultConfigToken = cachedVault.vaultConfigToken else {
				XCTFail("savedVaultConfigToken is nil")
				return
			}
			XCTAssertEqual(uploadedVaultConfigToken, savedVaultConfigToken)
			let vaultConfig = try UnverifiedVaultConfig(token: savedVaultConfigToken)
			XCTAssertEqual(.sivCTRMAC, vaultConfig.allegedCipherCombo)
			XCTAssertEqual(8, vaultConfig.allegedFormat)
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	// swiftlint:disable:next function_body_length
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
		cloudProviderMock.filesToDownload[masterkeyPath.path] = try managerMock.exportMasterkey(masterkey, vaultVersion: 999, password: "pw")

		let vaultConfigPath = vaultPath.appendingPathComponent("vault.cryptomator")
		let vaultConfigID = "ABB9F673-F3E8-41A7-A43B-D29F5DA65068"
		let vaultConfig = VaultConfig(id: vaultConfigID, format: 8, cipherCombo: .sivCTRMAC, shorteningThreshold: 220)
		let token = try vaultConfig.toToken(keyId: "masterkeyfile:masterkey.cryptomator", rawKey: masterkey.rawKey)
		cloudProviderMock.filesToDownload[vaultConfigPath.path] = token.data(using: .utf8)

		let vaultUID = UUID().uuidString
		let vaultDetails = VaultDetails(name: "ExistingVault", vaultPath: vaultPath)
		manager.createFromExisting(withVaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultItem: vaultDetails, password: "pw", storePasswordInKeychain: true).then { [self] in
			XCTAssertNotNil(VaultDBManager.cachedDecorators[vaultUID])
			guard VaultDBManager.cachedDecorators[vaultUID] is VaultFormat8ProviderDecorator else {
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
			guard let cachedVault = vaultCacheMock.cachedVaults[vaultUID] else {
				XCTFail("Vault not cached for \(vaultUID)")
				return
			}

			XCTAssertEqual(1, managerMock.addedFileProviderDomainDisplayName.count)
			XCTAssertEqual(vaultPath.lastPathComponent, managerMock.addedFileProviderDomainDisplayName[vaultUID])

			guard let savedVaultConfigToken = cachedVault.vaultConfigToken else {
				XCTFail("savedVaultConfigToken is nil")
				return
			}
			XCTAssertEqual(token, savedVaultConfigToken)
			let savedVaultConfig = try VaultConfig.load(token: savedVaultConfigToken, rawKey: masterkey.rawKey)
			XCTAssertEqual(vaultConfigID, savedVaultConfig.id)
			XCTAssertEqual(220, savedVaultConfig.shorteningThreshold)
			XCTAssertEqual(.sivCTRMAC, savedVaultConfig.cipherCombo)
			XCTAssertEqual(8, savedVaultConfig.format)
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testCreateLegacyFromExisting() throws {
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
		let legacyVaultDetails = VaultDetails(name: "ExistingVault", vaultPath: vaultPath)
		manager.createLegacyFromExisting(withVaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultItem: legacyVaultDetails, password: "pw", storePasswordInKeychain: true).then { [self] in
			XCTAssertNotNil(VaultDBManager.cachedDecorators[vaultUID])
			guard VaultDBManager.cachedDecorators[vaultUID] is VaultFormat7ProviderDecorator else {
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
			guard let cachedVault = vaultCacheMock.cachedVaults[vaultUID] else {
				XCTFail("Vault not cached for \(vaultUID)")
				return
			}
			let masterkeyFile = try MasterkeyFile.withContentFromData(data: cachedVault.masterkeyFileData)
			XCTAssertEqual(7, masterkeyFile.version)
			let savedMasterkey = try masterkeyFile.unlock(passphrase: "pw")
			XCTAssertEqual(masterkey, savedMasterkey)
			XCTAssertEqual(1, managerMock.addedFileProviderDomainDisplayName.count)
			XCTAssertEqual(vaultPath.lastPathComponent, managerMock.addedFileProviderDomainDisplayName[vaultUID])
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testManualUnlockVaultV8() throws {
		let delegateAccountUID = UUID().uuidString
		let account = CloudProviderAccount(accountUID: delegateAccountUID, cloudProviderType: .dropbox)
		try providerAccountManager.saveNewAccount(account)
		let vaultUID = UUID().uuidString
		let vaultPath = CloudPath("/VaultV8/")
		let vaultAccount = VaultAccount(vaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultPath: vaultPath, vaultName: "VaultV8")
		try accountManager.saveNewAccount(vaultAccount)
		let masterkey = Masterkey.createFromRaw(aesMasterKey: [UInt8](repeating: 0x55, count: 32), macMasterKey: [UInt8](repeating: 0x77, count: 32))
		let masterkeyFileData = try MasterkeyFile.lock(masterkey: masterkey, vaultVersion: 999, passphrase: "asd", pepper: [UInt8](), scryptCostParam: 2)
		let vaultConfig = VaultConfig(id: "ABB9F673-F3E8-41A7-A43B-D29F5DA65068", format: 8, cipherCombo: .sivCTRMAC, shorteningThreshold: 220)
		let vaultConfigToken = try vaultConfig.toToken(keyId: "masterkeyfile:masterkey.cryptomator", rawKey: masterkey.rawKey)
		let cachedVault = CachedVault(vaultUID: vaultUID, masterkeyFileData: masterkeyFileData, vaultConfigToken: vaultConfigToken, lastUpToDateCheck: Date())
		try vaultCacheMock.cache(cachedVault)
		let masterkeyFile = try MasterkeyFile.withContentFromData(data: masterkeyFileData)
		let kek = try masterkeyFile.deriveKey(passphrase: "asd")
		let decorator = try manager.manualUnlockVault(withUID: vaultUID, kek: kek)
		guard decorator is VaultFormat8ProviderDecorator else {
			XCTFail("Decorator is not a VaultFormat8ProviderDecorator")
			return
		}
		XCTAssertNotNil(VaultDBManager.cachedDecorators[vaultUID])
	}

	func testManualUnlockVaultV7() throws {
		let delegateAccountUID = UUID().uuidString
		let account = CloudProviderAccount(accountUID: delegateAccountUID, cloudProviderType: .dropbox)
		try providerAccountManager.saveNewAccount(account)
		let vaultUID = UUID().uuidString
		let vaultPath = CloudPath("/VaultV7/")
		let vaultAccount = VaultAccount(vaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultPath: vaultPath, vaultName: "VaultV7")
		try accountManager.saveNewAccount(vaultAccount)
		let masterkey = Masterkey.createFromRaw(aesMasterKey: [UInt8](repeating: 0x55, count: 32), macMasterKey: [UInt8](repeating: 0x77, count: 32))
		let masterkeyFileData = try MasterkeyFile.lock(masterkey: masterkey, vaultVersion: 7, passphrase: "asd", pepper: [UInt8](), scryptCostParam: 2)
		let cachedVault = CachedVault(vaultUID: vaultUID, masterkeyFileData: masterkeyFileData, vaultConfigToken: nil, lastUpToDateCheck: Date())
		try vaultCacheMock.cache(cachedVault)
		let masterkeyFile = try MasterkeyFile.withContentFromData(data: masterkeyFileData)
		let kek = try masterkeyFile.deriveKey(passphrase: "asd")
		let decorator = try manager.manualUnlockVault(withUID: vaultUID, kek: kek)
		guard decorator is VaultFormat7ProviderDecorator else {
			XCTFail("Decorator is not a VaultFormat7ProviderDecorator")
			return
		}
		XCTAssertNotNil(VaultDBManager.cachedDecorators[vaultUID])
	}

	func testManualUnlockVaultV6() throws {
		let delegateAccountUID = UUID().uuidString
		let account = CloudProviderAccount(accountUID: delegateAccountUID, cloudProviderType: .dropbox)
		try providerAccountManager.saveNewAccount(account)
		let vaultUID = UUID().uuidString
		let vaultPath = CloudPath("/VaultV1/")
		let vaultAccount = VaultAccount(vaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultPath: vaultPath, vaultName: "VaultV1")
		try accountManager.saveNewAccount(vaultAccount)
		let masterkey = Masterkey.createFromRaw(aesMasterKey: [UInt8](repeating: 0x55, count: 32), macMasterKey: [UInt8](repeating: 0x77, count: 32))
		let masterkeyFileData = try MasterkeyFile.lock(masterkey: masterkey, vaultVersion: 6, passphrase: "asd", pepper: [UInt8](), scryptCostParam: 2)
		let cachedVault = CachedVault(vaultUID: vaultUID, masterkeyFileData: masterkeyFileData, vaultConfigToken: nil, lastUpToDateCheck: Date())
		try vaultCacheMock.cache(cachedVault)
		let masterkeyFile = try MasterkeyFile.withContentFromData(data: masterkeyFileData)
		let kek = try masterkeyFile.deriveKey(passphrase: "asd")
		let decorator = try manager.manualUnlockVault(withUID: vaultUID, kek: kek)
		guard decorator is VaultFormat6ProviderDecorator else {
			XCTFail("Decorator is not a VaultFormat6ProviderDecorator")
			return
		}
		XCTAssertNotNil(VaultDBManager.cachedDecorators[vaultUID])
	}

	func testManualUnlockVaultThrowsForNonSupportedVaultVersion() throws {
		let delegateAccountUID = UUID().uuidString
		let account = CloudProviderAccount(accountUID: delegateAccountUID, cloudProviderType: .dropbox)
		try providerAccountManager.saveNewAccount(account)
		let vaultUID = UUID().uuidString
		let vaultPath = CloudPath("/VaultV6/")
		let vaultAccount = VaultAccount(vaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultPath: vaultPath, vaultName: "VaultV6")
		try accountManager.saveNewAccount(vaultAccount)
		let masterkey = Masterkey.createFromRaw(aesMasterKey: [UInt8](repeating: 0x55, count: 32), macMasterKey: [UInt8](repeating: 0x77, count: 32))
		let masterkeyFileData = try MasterkeyFile.lock(masterkey: masterkey, vaultVersion: 1, passphrase: "asd", pepper: [UInt8](), scryptCostParam: 2)
		let cachedVault = CachedVault(vaultUID: vaultUID, masterkeyFileData: masterkeyFileData, vaultConfigToken: nil, lastUpToDateCheck: Date())
		try vaultCacheMock.cache(cachedVault)
		let masterkeyFile = try MasterkeyFile.withContentFromData(data: masterkeyFileData)
		let kek = try masterkeyFile.deriveKey(passphrase: "asd")
		XCTAssertThrowsError(try manager.manualUnlockVault(withUID: vaultUID, kek: kek)) { error in
			guard case VaultProviderFactoryError.unsupportedVaultVersion = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}
		XCTAssertNil(VaultDBManager.cachedDecorators[vaultUID])
	}

	// MARK: - Duplicate Vault prevention

	func testDuplicateCreateNewVault() throws {
		let createNewVaultExpectation = XCTestExpectation()
		let delegateAccountUID = UUID().uuidString
		let account = CloudProviderAccount(accountUID: delegateAccountUID, cloudProviderType: .dropbox)
		try providerAccountManager.saveNewAccount(account)
		let vaultUID = UUID().uuidString
		let vaultPath = CloudPath("/Vault/")
		manager.createNewVault(withVaultUID: vaultUID, delegateAccountUID: account.accountUID, vaultPath: vaultPath, password: "pw", storePasswordInKeychain: false).catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			createNewVaultExpectation.fulfill()
		}
		wait(for: [createNewVaultExpectation], timeout: 1.0)

		let createNewVaultDuplicateExpectation = XCTestExpectation()
		manager.createNewVault(withVaultUID: UUID().uuidString, delegateAccountUID: account.accountUID, vaultPath: vaultPath, password: "pw", storePasswordInKeychain: false).then {
			XCTFail("Promise fulfilled")
		}.catch { error in
			guard case VaultAccountManagerError.vaultAccountAlreadyExists = error else {
				XCTFail("Promise rejected but with the wrong error: \(error)")
				return
			}
		}.always {
			createNewVaultDuplicateExpectation.fulfill()
		}
		wait(for: [createNewVaultDuplicateExpectation], timeout: 1.0)
	}

	func testDuplicateCreateFromExisting() throws {
		let createExistingVaultExpectation = XCTestExpectation()
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
		cloudProviderMock.filesToDownload[masterkeyPath.path] = try managerMock.exportMasterkey(masterkey, vaultVersion: 999, password: "pw")

		let vaultConfigPath = vaultPath.appendingPathComponent("vault.cryptomator")
		let vaultConfigID = "ABB9F673-F3E8-41A7-A43B-D29F5DA65068"
		let vaultConfig = VaultConfig(id: vaultConfigID, format: 8, cipherCombo: .sivCTRMAC, shorteningThreshold: 220)
		let token = try vaultConfig.toToken(keyId: "masterkeyfile:masterkey.cryptomator", rawKey: masterkey.rawKey)
		cloudProviderMock.filesToDownload[vaultConfigPath.path] = token.data(using: .utf8)

		let vaultUID = UUID().uuidString
		let vaultDetails = VaultDetails(name: "ExistingVault", vaultPath: vaultPath)
		manager.createFromExisting(withVaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultItem: vaultDetails, password: "pw", storePasswordInKeychain: true).catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			createExistingVaultExpectation.fulfill()
		}
		wait(for: [createExistingVaultExpectation], timeout: 1.0)

		let createExistingVaultDuplicateExpectation = XCTestExpectation()

		manager.createFromExisting(withVaultUID: UUID().uuidString, delegateAccountUID: delegateAccountUID, vaultItem: vaultDetails, password: "pw", storePasswordInKeychain: true).then {
			XCTFail("Promise fulfilled")
		}.catch { error in
			guard case VaultAccountManagerError.vaultAccountAlreadyExists = error else {
				XCTFail("Promise rejected but with the wrong error: \(error)")
				return
			}
		}.always {
			createExistingVaultDuplicateExpectation.fulfill()
		}
		wait(for: [createExistingVaultDuplicateExpectation], timeout: 1.0)
	}

	// MARK: - Move Vault

	func testMoveVault() throws {
		let expectation = XCTestExpectation()
		let delegateAccountUID = UUID().uuidString
		let account = CloudProviderAccount(accountUID: delegateAccountUID, cloudProviderType: .dropbox)
		let cloudProviderMock = providerManager.provider
		let vaultUID = UUID().uuidString
		let vaultPath = CloudPath("/Vault/")
		try providerAccountManager.saveNewAccount(account)
		let vaultAccount = VaultAccount(vaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultPath: vaultPath, vaultName: "Vault")
		try accountManager.saveNewAccount(vaultAccount)
		let newVaultPath = CloudPath("/Foo/MovedVault")

		manager.moveVault(account: vaultAccount, to: newVaultPath).then {
			XCTAssertEqual(1, cloudProviderMock.movedFolder.count)
			XCTAssertEqual(newVaultPath.path, cloudProviderMock.movedFolder[vaultPath.path])

			let updatedAccount = try self.accountManager.getAccount(with: vaultUID)
			XCTAssertEqual(newVaultPath, updatedAccount.vaultPath)
			XCTAssertEqual("MovedVault", updatedAccount.vaultName)
			XCTAssertEqual(vaultAccount.delegateAccountUID, updatedAccount.delegateAccountUID)
			XCTAssertEqual(delegateAccountUID, updatedAccount.delegateAccountUID)

			guard let managerMock = self.manager as? VaultManagerMock else {
				XCTFail("Could not convert manager to VaultManagerMock")
				return
			}

			XCTAssertEqual(1, managerMock.addedFileProviderDomainDisplayName.count)
			XCTAssertEqual("MovedVault", managerMock.addedFileProviderDomainDisplayName[vaultUID])
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testMoveVaultClouderProviderFails() throws {
		let expectation = XCTestExpectation()
		let delegateAccountUID = UUID().uuidString
		let account = CloudProviderAccount(accountUID: delegateAccountUID, cloudProviderType: .dropbox)
		let cloudProviderMock = providerManager.provider
		let vaultUID = UUID().uuidString
		let vaultPath = CloudPath("/Vault/")
		try providerAccountManager.saveNewAccount(account)
		let vaultAccount = VaultAccount(vaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultPath: vaultPath, vaultName: "Vault")
		try accountManager.saveNewAccount(vaultAccount)
		let newVaultPath = CloudPath("/Foo/MovedVault")

		// Simulate cloud provider error for moveFolder
		cloudProviderMock.error = CloudProviderError.itemAlreadyExists

		manager.moveVault(account: vaultAccount, to: newVaultPath).then {
			XCTFail("Promise fulfilled")
		}.catch { error in
			guard case LocalizedCloudProviderError.itemAlreadyExists = error else {
				XCTFail("Promise rejected with wrong error: \(error)")
				return
			}
			XCTAssert(cloudProviderMock.movedFolder.isEmpty)
			let fetchedVaultAccount: VaultAccount
			do {
				fetchedVaultAccount = try self.accountManager.getAccount(with: vaultUID)
			} catch {
				XCTFail("get vault account failed with error: \(error)")
				return
			}

			guard let managerMock = self.manager as? VaultManagerMock else {
				XCTFail("Could not convert manager to VaultManagerMock")
				return
			}

			XCTAssert(managerMock.addedFileProviderDomainDisplayName.isEmpty)

			// Check VaultAccount did not change
			XCTAssertEqual(vaultUID, fetchedVaultAccount.vaultUID)
			XCTAssertEqual(delegateAccountUID, fetchedVaultAccount.delegateAccountUID)
			XCTAssertEqual(vaultPath, fetchedVaultAccount.vaultPath)
			XCTAssertEqual("Vault", fetchedVaultAccount.vaultName)
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testMoveVaultInsideItself() throws {
		let expectation = XCTestExpectation()
		let delegateAccountUID = UUID().uuidString
		let account = CloudProviderAccount(accountUID: delegateAccountUID, cloudProviderType: .dropbox)
		let cloudProviderMock = providerManager.provider
		let vaultUID = UUID().uuidString
		let vaultPath = CloudPath("/Vault/")
		try providerAccountManager.saveNewAccount(account)
		let vaultAccount = VaultAccount(vaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultPath: vaultPath, vaultName: "Vault")
		try accountManager.saveNewAccount(vaultAccount)
		let newVaultPath = CloudPath("/Vault/Foo")

		manager.moveVault(account: vaultAccount, to: newVaultPath).then {
			XCTFail("Promise fulfilled")
		}.catch { error in
			guard case VaultManagerError.moveVaultInsideItself = error else {
				XCTFail("Promise rejected with wrong error: \(error)")
				return
			}
			XCTAssert(cloudProviderMock.movedFolder.isEmpty)
			let fetchedVaultAccount: VaultAccount
			do {
				fetchedVaultAccount = try self.accountManager.getAccount(with: vaultUID)
			} catch {
				XCTFail("get vault account failed with error: \(error)")
				return
			}

			guard let managerMock = self.manager as? VaultManagerMock else {
				XCTFail("Could not convert manager to VaultManagerMock")
				return
			}

			XCTAssert(managerMock.addedFileProviderDomainDisplayName.isEmpty)

			// Check VaultAccount did not change
			XCTAssertEqual(vaultUID, fetchedVaultAccount.vaultUID)
			XCTAssertEqual(delegateAccountUID, fetchedVaultAccount.delegateAccountUID)
			XCTAssertEqual(vaultPath, fetchedVaultAccount.vaultPath)
			XCTAssertEqual("Vault", fetchedVaultAccount.vaultName)
		}.always {
			expectation.fulfill()
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}
}

struct VaultDetails: VaultItem {
	let name: String
	let vaultPath: CloudPath
}

extension Masterkey: Equatable {
	public static func == (lhs: Masterkey, rhs: Masterkey) -> Bool {
		return lhs.aesMasterKey == rhs.aesMasterKey && lhs.macMasterKey == rhs.macMasterKey
	}
}

class VaultPasswordManagerMock: VaultPasswordManager {
	var savedPasswords = [String: String]()
	var removedPasswords = [String]()

	func setPassword(_ password: String, forVaultUID vaultUID: String) throws {
		savedPasswords[vaultUID] = password
	}

	func getPassword(forVaultUID vaultUID: String) throws -> String {
		guard let password = savedPasswords[vaultUID] else {
			throw VaultPasswordManagerError.passwordNotFound
		}
		return password
	}

	func removePassword(forVaultUID vaultUID: String) throws {
		removedPasswords.append(vaultUID)
	}

	func hasPassword(forVaultUID vaultUID: String) throws -> Bool {
		return false
	}
}

class VaultCacheMock: VaultCache {
	var cachedVaults = [String: CachedVault]()
	var invalidatedVaults = [String]()

	func cache(_ entry: CachedVault) throws {
		cachedVaults[entry.vaultUID] = entry
	}

	func getCachedVault(withVaultUID vaultUID: String) throws -> CachedVault {
		guard let vault = cachedVaults[vaultUID] else {
			throw VaultCacheError.vaultNotFound
		}
		return vault
	}

	func invalidate(vaultUID: String) throws {
		invalidatedVaults.append(vaultUID)
	}
}
