//
//  VaultManagerTests.swift
//  CryptomatorCommonCoreTests
//
//  Created by Philipp Schmid on 02.11.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation
import GRDB
import LocalAuthentication
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

	override func changePassphrase(masterkeyFileData: Data, oldPassphrase: String, newPassphrase: String) throws -> Data {
		return try MasterkeyFile.changePassphrase(masterkeyFileData: masterkeyFileData, oldPassphrase: oldPassphrase, newPassphrase: newPassphrase, pepper: [UInt8](), scryptCostParam: 2)
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
	var masterkeyCacheManagerMock: MasterkeyCacheManagerMock!
	var masterkeyCacheHelperMock: MasterkeyCacheHelperMock!
	var tmpDir: URL!
	var dbPool: DatabasePool!
	let vaultUID = "VaultUID-12345"
	let passphrase = "PW"
	let delegateAccountUID = UUID().uuidString
	let vaultPath = CloudPath("/Vault/")
	lazy var vaultAccount = VaultAccount(vaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultPath: vaultPath, vaultName: "Vault")
	let masterkey = Masterkey.createFromRaw(aesMasterKey: [UInt8](repeating: 0x55, count: 32), macMasterKey: [UInt8](repeating: 0x77, count: 32))
	let masterkeyFileLastModifiedDate = Date(timeIntervalSince1970: 100)
	let vaultConfigLastModifiedDate = Date(timeIntervalSince1970: 200)

	override func setUpWithError() throws {
		tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true, attributes: nil)
		dbPool = try DatabasePool(path: tmpDir.appendingPathComponent("db.sqlite").path)
		try CryptomatorDatabase.migrator.migrate(dbPool)

		providerAccountManager = CloudProviderAccountDBManager(dbPool: dbPool)
		providerManager = CloudProviderManagerMock(accountManager: providerAccountManager)
		accountManager = VaultAccountDBManager(dbPool: dbPool)
		vaultCacheMock = VaultCacheMock()
		vaultCacheMock.refreshVaultCacheForWithReturnValue = Promise(())
		passwordManagerMock = VaultPasswordManagerMock()
		masterkeyCacheManagerMock = MasterkeyCacheManagerMock()
		masterkeyCacheHelperMock = MasterkeyCacheHelperMock()
		masterkeyCacheHelperMock.shouldCacheMasterkeyForVaultUIDReturnValue = false
		manager = VaultManagerMock(providerManager: providerManager, vaultAccountManager: accountManager, vaultCache: vaultCacheMock, passwordManager: passwordManagerMock, masterkeyCacheManager: masterkeyCacheManagerMock, masterkeyCacheHelper: masterkeyCacheHelperMock)
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

			let cachedVault = try getCachedVaultFromMock(withVaultUID: vaultUID)

			let cachedMasterkeyFile = try MasterkeyFile.withContentFromData(data: cachedVault.masterkeyFileData)
			let cachedMasterkey = try cachedMasterkeyFile.unlock(passphrase: "pw")
			XCTAssertEqual(uploadedMasterkey, cachedMasterkey)

			// Vault config checks
			let vaultConfigPath = vaultPath.appendingPathComponent("vault.cryptomator")
			guard let uploadedVaultConfigToken = cloudProviderMock.createdFiles[vaultConfigPath.path] else {
				XCTFail("Vault config not uploaded")
				return
			}

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

		cloudProviderMock.filesToDownload[masterkeyPath.path] = try managerMock.exportMasterkey(masterkey, vaultVersion: 999, password: "pw")
		cloudProviderMock.cloudMetadata[masterkeyPath.path] = CloudItemMetadata(name: masterkeyPath.lastPathComponent, cloudPath: masterkeyPath, itemType: .file, lastModifiedDate: masterkeyFileLastModifiedDate, size: nil)

		let vaultConfigPath = vaultPath.appendingPathComponent("vault.cryptomator")
		let vaultConfigID = "ABB9F673-F3E8-41A7-A43B-D29F5DA65068"
		let vaultConfig = VaultConfig(id: vaultConfigID, format: 8, cipherCombo: .sivCTRMAC, shorteningThreshold: 220)
		let token = try vaultConfig.toToken(keyId: "masterkeyfile:masterkey.cryptomator", rawKey: masterkey.rawKey)
		cloudProviderMock.filesToDownload[vaultConfigPath.path] = token
		cloudProviderMock.cloudMetadata[vaultConfigPath.path] = CloudItemMetadata(name: vaultConfigPath.lastPathComponent, cloudPath: vaultConfigPath, itemType: .file, lastModifiedDate: vaultConfigLastModifiedDate, size: nil)

		let vaultUID = UUID().uuidString
		let vaultDetails = VaultDetails(name: "ExistingVault", vaultPath: vaultPath)
		manager.createFromExisting(withVaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultItem: vaultDetails, password: "pw", storePasswordInKeychain: true).then { [self] in
			let vaultAccount = try accountManager.getAccount(with: vaultUID)
			XCTAssertEqual(vaultUID, vaultAccount.vaultUID)
			XCTAssertEqual(delegateAccountUID, vaultAccount.delegateAccountUID)
			XCTAssertEqual(vaultPath, vaultAccount.vaultPath)
			guard let managerMock = manager as? VaultManagerMock else {
				XCTFail("Could not convert manager to VaultManagerMock")
				return
			}
			let cachedVault = try getCachedVaultFromMock(withVaultUID: vaultUID)
			XCTAssertEqual(masterkeyFileLastModifiedDate, cachedVault.masterkeyFileLastModifiedDate)
			XCTAssertEqual(vaultConfigLastModifiedDate, cachedVault.vaultConfigLastModifiedDate)

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

		cloudProviderMock.filesToDownload[masterkeyPath.path] = try managerMock.exportMasterkey(masterkey, vaultVersion: 7, password: "pw")
		cloudProviderMock.cloudMetadata[masterkeyPath.path] = CloudItemMetadata(name: masterkeyPath.lastPathComponent, cloudPath: masterkeyPath, itemType: .file, lastModifiedDate: masterkeyFileLastModifiedDate, size: nil)

		let vaultUID = UUID().uuidString
		let legacyVaultDetails = VaultDetails(name: "ExistingVault", vaultPath: vaultPath)
		manager.createLegacyFromExisting(withVaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultItem: legacyVaultDetails, password: "pw", storePasswordInKeychain: true).then { [self] in
			let vaultAccount = try accountManager.getAccount(with: vaultUID)
			XCTAssertEqual(vaultUID, vaultAccount.vaultUID)
			XCTAssertEqual(delegateAccountUID, vaultAccount.delegateAccountUID)
			XCTAssertEqual(vaultPath, vaultAccount.vaultPath)
			guard let managerMock = manager as? VaultManagerMock else {
				XCTFail("Could not convert manager to VaultManagerMock")
				return
			}
			let cachedVault = try getCachedVaultFromMock(withVaultUID: vaultUID)
			XCTAssertEqual(masterkeyFileLastModifiedDate, cachedVault.masterkeyFileLastModifiedDate)
			XCTAssertNil(cachedVault.vaultConfigLastModifiedDate)
			XCTAssertNil(cachedVault.vaultConfigToken)

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

	// MARK: Manual Unlock

	func testManualUnlockVaultV8() throws {
		try manualUnlockVaultV8()
		assertRefreshedVaultCache()
		XCTAssertFalse(masterkeyCacheManagerMock.cacheMasterkeyForVaultUIDCalled)
	}

	func testManualUnlockVaultV7() throws {
		let expectation = XCTestExpectation()
		let kek = try setupManualUnlockTest(vaultVersion: 7)
		manager.manualUnlockVault(withUID: vaultUID, kek: kek).then { decorator in
			XCTAssert(decorator is VaultFormat7ProviderDecorator, "Decorator is not a VaultFormat7ProviderDecorator")
		}.catch { error in
			XCTFail("Promise rejected with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
		XCTAssertFalse(masterkeyCacheManagerMock.cacheMasterkeyForVaultUIDCalled)
		assertRefreshedVaultCache()
	}

	func testManualUnlockVaultV6() throws {
		let expectation = XCTestExpectation()
		let kek = try setupManualUnlockTest(vaultVersion: 6)
		manager.manualUnlockVault(withUID: vaultUID, kek: kek).then { decorator in
			XCTAssert(decorator is VaultFormat6ProviderDecorator, "Decorator is not a VaultFormat6ProviderDecorator")
		}.catch { error in
			XCTFail("Promise rejected with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
		XCTAssertFalse(masterkeyCacheManagerMock.cacheMasterkeyForVaultUIDCalled)
		assertRefreshedVaultCache()
	}

	func testManualUnlockVaultThrowsForNonSupportedVaultVersion() throws {
		masterkeyCacheHelperMock.shouldCacheMasterkeyForVaultUIDReturnValue = true
		let expectation = XCTestExpectation()
		let kek = try setupManualUnlockTest(vaultVersion: 5)
		manager.manualUnlockVault(withUID: vaultUID, kek: kek).then { _ in
			XCTFail("Promise fulfilled")
		}.catch { error in
			XCTAssertEqual(.unsupportedVaultVersion, error as? VaultProviderFactoryError)
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
		XCTAssertFalse(masterkeyCacheManagerMock.cacheMasterkeyForVaultUIDCalled)
	}

	func testManualUnlockVaultCachesMasterkey() throws {
		masterkeyCacheHelperMock.shouldCacheMasterkeyForVaultUIDReturnValue = true

		try manualUnlockVaultV8()
		assertRefreshedVaultCache()
		XCTAssertEqual(1, masterkeyCacheManagerMock.cacheMasterkeyForVaultUIDCallsCount)
		XCTAssertEqual(vaultUID, masterkeyCacheManagerMock.cacheMasterkeyForVaultUIDReceivedArguments?.vaultUID)
		let passedMasterkey = try XCTUnwrap(masterkeyCacheManagerMock.cacheMasterkeyForVaultUIDReceivedArguments?.masterkey)
		XCTAssertEqual(masterkey.rawKey, passedMasterkey.rawKey)
	}

	func testManualUnlockRefreshVaultErrorHandling() throws {
		// Manual Unlock succeeds if refreshVaultCache fails due to a missing internet connection
		vaultCacheMock.refreshVaultCacheForWithThrowableError = CloudProviderError.noInternetConnection
		try manualUnlockVaultV8()

		// Manual Unlock propagates refreshVaultCache error
		let expectedError = CloudProviderError.itemNotFound
		vaultCacheMock.refreshVaultCacheForWithThrowableError = expectedError
		XCTAssertThrowsError(try manualUnlockVaultV8()) { error in
			XCTAssertEqual(expectedError, error as? CloudProviderError)
		}
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

		cloudProviderMock.filesToDownload[masterkeyPath.path] = try managerMock.exportMasterkey(masterkey, vaultVersion: 999, password: "pw")
		cloudProviderMock.cloudMetadata[masterkeyPath.path] = CloudItemMetadata(name: masterkeyPath.lastPathComponent, cloudPath: masterkeyPath, itemType: .file, lastModifiedDate: masterkeyFileLastModifiedDate, size: nil)

		let vaultConfigPath = vaultPath.appendingPathComponent("vault.cryptomator")
		let vaultConfigID = "ABB9F673-F3E8-41A7-A43B-D29F5DA65068"
		let vaultConfig = VaultConfig(id: vaultConfigID, format: 8, cipherCombo: .sivCTRMAC, shorteningThreshold: 220)
		let token = try vaultConfig.toToken(keyId: "masterkeyfile:masterkey.cryptomator", rawKey: masterkey.rawKey)
		cloudProviderMock.filesToDownload[vaultConfigPath.path] = token
		cloudProviderMock.cloudMetadata[vaultConfigPath.path] = CloudItemMetadata(name: vaultConfigPath.lastPathComponent, cloudPath: vaultConfigPath, itemType: .file, lastModifiedDate: vaultConfigLastModifiedDate, size: nil)

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
		}
		wait(for: [expectation], timeout: 1.0)
	}

	// MARK: - Change Passphrase

	func testChangePassphrase() throws {
		let expectation = XCTestExpectation()
		let delegateAccountUID = UUID().uuidString
		let account = CloudProviderAccount(accountUID: delegateAccountUID, cloudProviderType: .dropbox)
		let cloudProviderMock = providerManager.provider
		let vaultPath = CloudPath("/Vault/")
		try providerAccountManager.saveNewAccount(account)
		let vaultAccount = VaultAccount(vaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultPath: vaultPath, vaultName: "Vault")
		try accountManager.saveNewAccount(vaultAccount)

		let oldPassphrase = "Password"

		let masterkeyFileData = try MasterkeyFile.lock(masterkey: masterkey, vaultVersion: 999, passphrase: oldPassphrase, pepper: [UInt8](), scryptCostParam: 2)

		let vaultConfigID = "ABB9F673-F3E8-41A7-A43B-D29F5DA65068"
		let vaultConfig = VaultConfig(id: vaultConfigID, format: 8, cipherCombo: .sivCTRMAC, shorteningThreshold: 220)
		let token = try vaultConfig.toToken(keyId: "masterkeyfile:masterkey.cryptomator", rawKey: masterkey.rawKey)

		let oldLastUpToDateCheck = Date(timeIntervalSince1970: 0)
		vaultCacheMock.getCachedVaultWithVaultUIDReturnValue = CachedVault(vaultUID: vaultUID, masterkeyFileData: masterkeyFileData, vaultConfigToken: token, lastUpToDateCheck: oldLastUpToDateCheck, masterkeyFileLastModifiedDate: nil, vaultConfigLastModifiedDate: nil)
		cloudProviderMock.createdFilesLastModifiedDate["/Vault/masterkey.cryptomator"] = masterkeyFileLastModifiedDate
		let newPassphrase = "NewPassword"

		manager.changePassphrase(oldPassphrase: oldPassphrase, newPassphrase: newPassphrase, forVaultUID: vaultUID).then {
			XCTAssertEqual(1, cloudProviderMock.createdFiles.count)
			guard let uploadedMasterkeyFileData = cloudProviderMock.createdFiles["/Vault/masterkey.cryptomator"] else {
				XCTFail("Masterkey file not uploaded")
				return
			}
			let uploadedMasterkeyFile = try MasterkeyFile.withContentFromData(data: uploadedMasterkeyFileData)
			let uploadedMasterkey = try uploadedMasterkeyFile.unlock(passphrase: newPassphrase)
			XCTAssertThrowsError(try uploadedMasterkeyFile.unlock(passphrase: oldPassphrase)) { error in
				XCTAssertEqual(.invalidPassphrase, error as? MasterkeyFileError)
			}
			XCTAssertEqual(self.masterkey.aesMasterKey, uploadedMasterkey.aesMasterKey)
			XCTAssertEqual(self.masterkey.macMasterKey, uploadedMasterkey.macMasterKey)

			try self.assertUpdatedVaultCache(with: uploadedMasterkeyFileData)
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testChangePassphraseWithSavedPassword() throws {
		let expectation = XCTestExpectation()
		let delegateAccountUID = UUID().uuidString
		let account = CloudProviderAccount(accountUID: delegateAccountUID, cloudProviderType: .dropbox)
		let cloudProviderMock = providerManager.provider
		let vaultPath = CloudPath("/Vault/")
		try providerAccountManager.saveNewAccount(account)
		let vaultAccount = VaultAccount(vaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultPath: vaultPath, vaultName: "Vault")
		try accountManager.saveNewAccount(vaultAccount)

		let oldPassphrase = "Password"

		let masterkeyFileData = try MasterkeyFile.lock(masterkey: masterkey, vaultVersion: 999, passphrase: oldPassphrase, pepper: [UInt8](), scryptCostParam: 2)

		passwordManagerMock.savedPasswords[vaultUID] = oldPassphrase

		let vaultConfigID = "ABB9F673-F3E8-41A7-A43B-D29F5DA65068"
		let vaultConfig = VaultConfig(id: vaultConfigID, format: 8, cipherCombo: .sivCTRMAC, shorteningThreshold: 220)
		let token = try vaultConfig.toToken(keyId: "masterkeyfile:masterkey.cryptomator", rawKey: masterkey.rawKey)

		let oldLastUpToDateCheck = Date(timeIntervalSince1970: 0)
		vaultCacheMock.getCachedVaultWithVaultUIDReturnValue = CachedVault(vaultUID: vaultUID, masterkeyFileData: masterkeyFileData, vaultConfigToken: token, lastUpToDateCheck: oldLastUpToDateCheck, masterkeyFileLastModifiedDate: nil, vaultConfigLastModifiedDate: nil)
		cloudProviderMock.createdFilesLastModifiedDate["/Vault/masterkey.cryptomator"] = masterkeyFileLastModifiedDate
		let newPassphrase = "NewPassword"

		manager.changePassphrase(oldPassphrase: oldPassphrase, newPassphrase: newPassphrase, forVaultUID: vaultUID).then {
			XCTAssertEqual(1, cloudProviderMock.createdFiles.count)
			guard let uploadedMasterkeyFileData = cloudProviderMock.createdFiles["/Vault/masterkey.cryptomator"] else {
				XCTFail("Masterkey file not uploaded")
				return
			}
			let uploadedMasterkeyFile = try MasterkeyFile.withContentFromData(data: uploadedMasterkeyFileData)
			let uploadedMasterkey = try uploadedMasterkeyFile.unlock(passphrase: newPassphrase)
			XCTAssertThrowsError(try uploadedMasterkeyFile.unlock(passphrase: oldPassphrase)) { error in
				XCTAssertEqual(.invalidPassphrase, error as? MasterkeyFileError)
			}
			XCTAssertEqual(self.masterkey.aesMasterKey, uploadedMasterkey.aesMasterKey)
			XCTAssertEqual(self.masterkey.macMasterKey, uploadedMasterkey.macMasterKey)

			try self.assertUpdatedVaultCache(with: uploadedMasterkeyFileData)

			XCTAssertEqual(1, self.passwordManagerMock.savedPasswords.count)
			XCTAssertEqual(newPassphrase, self.passwordManagerMock.savedPasswords[self.vaultUID])
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	// MARK: Helper

	private func manualUnlockVaultV8() throws {
		let expectation = XCTestExpectation()
		var unlockError: Error?
		let kek = try setupManualUnlockTest(vaultVersion: 8)
		manager.manualUnlockVault(withUID: vaultUID, kek: kek).then { decorator in
			guard decorator is VaultFormat8ProviderDecorator else {
				XCTFail("Decorator is not a VaultFormat8ProviderDecorator")
				return
			}
		}.catch { error in
			unlockError = error
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
		if let unlockError = unlockError {
			throw unlockError
		}
	}

	private func assertRefreshedVaultCache() {
		XCTAssertEqual(1, vaultCacheMock.refreshVaultCacheForWithCallsCount)
		XCTAssertEqual(vaultAccount, vaultCacheMock.refreshVaultCacheForWithReceivedArguments?.vault)
		XCTAssert(providerManager.provider === vaultCacheMock.refreshVaultCacheForWithReceivedArguments?.provider as AnyObject)
	}

	/**
	 Helper method to setup for manual unlock tests.

	 - returns the derived KEK from the masterkey file with the default passphrase
	 */
	private func setupManualUnlockTest(vaultVersion: Int) throws -> [UInt8] {
		let account = CloudProviderAccount(accountUID: delegateAccountUID, cloudProviderType: .dropbox)
		try providerAccountManager.saveNewAccount(account)
		try accountManager.saveNewAccount(vaultAccount)

		var vaultConfigToken: Data?
		var masterkeyFileVaultVersion = vaultVersion
		if !isLegacyVault(vaultVersion: vaultVersion) {
			let vaultConfig = VaultConfig(id: "ABB9F673-F3E8-41A7-A43B-D29F5DA65068", format: vaultVersion, cipherCombo: .sivCTRMAC, shorteningThreshold: 220)
			vaultConfigToken = try vaultConfig.toToken(keyId: "masterkeyfile:masterkey.cryptomator", rawKey: masterkey.rawKey)
			masterkeyFileVaultVersion = 999
		}
		let masterkeyFileData = try MasterkeyFile.lock(masterkey: masterkey, vaultVersion: masterkeyFileVaultVersion, passphrase: passphrase, pepper: [UInt8](), scryptCostParam: 2)
		vaultCacheMock.getCachedVaultWithVaultUIDReturnValue = CachedVault(vaultUID: vaultUID, masterkeyFileData: masterkeyFileData, vaultConfigToken: vaultConfigToken, lastUpToDateCheck: Date(), masterkeyFileLastModifiedDate: nil, vaultConfigLastModifiedDate: nil)
		let masterkeyFile = try MasterkeyFile.withContentFromData(data: masterkeyFileData)
		return try masterkeyFile.deriveKey(passphrase: passphrase)
	}

	private func getCachedVaultFromMock(withVaultUID vaultUID: String) throws -> CachedVault {
		XCTAssertEqual(1, vaultCacheMock.cacheCallsCount)
		let cachedVault = try XCTUnwrap(vaultCacheMock.cacheReceivedEntry)
		XCTAssertEqual(vaultUID, cachedVault.vaultUID)
		return cachedVault
	}

	private func isLegacyVault(vaultVersion: Int) -> Bool {
		return vaultVersion < 8
	}

	private func assertUpdatedVaultCache(with expectedMasterkeyFileData: Data) throws {
		let receivedArguments = try XCTUnwrap(vaultCacheMock.setMasterkeyFileDataForVaultUIDLastModifiedDateReceivedArguments)
		XCTAssertEqual(masterkeyFileLastModifiedDate, receivedArguments.lastModifiedDate)
		XCTAssertEqual(expectedMasterkeyFileData, receivedArguments.data)
		XCTAssertEqual(vaultUID, receivedArguments.vaultUID)
		XCTAssertFalse(vaultCacheMock.refreshVaultCacheForWithCalled)
		XCTAssertFalse(vaultCacheMock.cacheCalled)
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

	func getPassword(forVaultUID vaultUID: String, context: LAContext) throws -> String {
		guard let password = savedPasswords[vaultUID] else {
			throw VaultPasswordManagerError.passwordNotFound
		}
		return password
	}

	func removePassword(forVaultUID vaultUID: String) throws {
		removedPasswords.append(vaultUID)
	}

	func hasPassword(forVaultUID vaultUID: String) throws -> Bool {
		return savedPasswords[vaultUID] != nil
	}
}
