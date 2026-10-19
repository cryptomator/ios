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
import XCTest
@testable import CryptomatorCloudAccessCore
@testable import CryptomatorCommonCore
@testable import CryptomatorCryptoLib

/// @unchecked Sendable: test double, never touched concurrently
private final class VaultManagerMock: VaultDBManager, @unchecked Sendable {
	var removedVaultUIDs = [String]()
	var addedFileProviderDomainDisplayName = [String: String]()

	override func exportMasterkey(_ masterkey: Masterkey, vaultVersion: Int, password: String) throws -> Data {
		return try MasterkeyFile.lock(masterkey: masterkey, vaultVersion: vaultVersion, passphrase: password, pepper: [UInt8](), scryptCostParam: 2)
	}

	override func changePassphrase(masterkeyFileData: Data, oldPassphrase: String, newPassphrase: String) throws -> Data {
		return try MasterkeyFile.changePassphrase(masterkeyFileData: masterkeyFileData, oldPassphrase: oldPassphrase, newPassphrase: newPassphrase, pepper: [UInt8](), scryptCostParam: 2)
	}

	override func removeFileProviderDomain(withVaultUID vaultUID: String) async throws {
		removedVaultUIDs.append(vaultUID)
	}

	override func addFileProviderDomain(forVaultUID vaultUID: String, displayName: String) async throws {
		addedFileProviderDomainDisplayName[vaultUID] = displayName
	}
}

/// @unchecked Sendable: test double, never touched concurrently
class CloudProviderManagerMock: CloudProviderDBManager, @unchecked Sendable {
	private let provider: CloudProvider

	init(provider: CloudProvider, accountManager: CloudProviderAccountDBManager) {
		self.provider = provider
		super.init(accountManager: accountManager)
	}

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
	var cloudProviderMock: CloudProviderMock!
	let vaultUID = "VaultUID-12345"
	let passphrase = "PW"
	let delegateAccountUID = UUID().uuidString
	let vaultPath = CloudPath("/Vault/")
	lazy var vaultAccount = VaultAccount(vaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultPath: vaultPath, vaultName: "Vault")
	var masterkey: Masterkey!
	let masterkeyFileLastModifiedDate = Date(timeIntervalSince1970: 100)
	let vaultConfigLastModifiedDate = Date(timeIntervalSince1970: 200)

	override func setUpWithError() throws {
		masterkey = try Masterkey.createFromRaw(rawKey: [UInt8](repeating: 0x55, count: 32) + [UInt8](repeating: 0x77, count: 32))
		cloudProviderMock = CloudProviderMock()

		providerAccountManager = CloudProviderAccountDBManager()
		providerManager = CloudProviderManagerMock(provider: cloudProviderMock, accountManager: providerAccountManager)
		accountManager = VaultAccountDBManager()
		vaultCacheMock = VaultCacheMock()
		passwordManagerMock = VaultPasswordManagerMock()
		masterkeyCacheManagerMock = MasterkeyCacheManagerMock()
		masterkeyCacheHelperMock = MasterkeyCacheHelperMock()
		masterkeyCacheHelperMock.shouldCacheMasterkeyForVaultUIDReturnValue = false
		manager = VaultManagerMock(providerManager: providerManager, vaultAccountManager: accountManager, vaultCache: vaultCacheMock, passwordManager: passwordManagerMock, masterkeyCacheManager: masterkeyCacheManagerMock, masterkeyCacheHelper: masterkeyCacheHelperMock)
	}

	func testCreateNewVault() async throws {
		let delegateAccountUID = UUID().uuidString
		let account = CloudProviderAccount(accountUID: delegateAccountUID, cloudProviderType: .dropbox)
		try providerAccountManager.saveNewAccount(account)

		try await manager.createNewVault(withVaultUID: vaultUID, delegateAccountUID: account.accountUID, vaultPath: vaultPath, password: "pw", storePasswordInKeychain: false)
		XCTAssertEqual(vaultPath.path, cloudProviderMock.createdFolders[0])
		XCTAssertEqual(CloudPath("/Vault/d").path, cloudProviderMock.createdFolders[1])
		XCTAssertTrue(cloudProviderMock.createdFolders[2].hasPrefix(CloudPath("/Vault/d/").path) && cloudProviderMock.createdFolders[2].count == 11)
		XCTAssertTrue(cloudProviderMock.createdFolders[3].hasPrefix(cloudProviderMock.createdFolders[2] + "/") && cloudProviderMock.createdFolders[3].count == 42)

		let uploadedMasterkeyFile = try MasterkeyFile.withContentFromData(data: getUploadedMasterkeyFileData())
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

		let uploadedVaultConfigToken = try getUploadedVaultConfigData()
		guard let savedVaultConfigToken = cachedVault.vaultConfigToken else {
			XCTFail("savedVaultConfigToken is nil")
			return
		}
		XCTAssertEqual(uploadedVaultConfigToken, savedVaultConfigToken)
		let vaultConfig = try UnverifiedVaultConfig(token: savedVaultConfigToken)
		XCTAssertEqual("SIV_GCM", vaultConfig.allegedCipherCombo)
		XCTAssertEqual(8, vaultConfig.allegedFormat)

		let uploadedRootDirIdFile = try getUploadedData(at: CloudPath(cloudProviderMock.createdFolders[3]).appendingPathComponent("dirid.c9r"))
		XCTAssertEqual(68, uploadedRootDirIdFile.count)
	}

	func testCreateFromExisting() async throws {
		let delegateAccountUID = UUID().uuidString
		let account = CloudProviderAccount(accountUID: delegateAccountUID, cloudProviderType: .dropbox)
		try providerAccountManager.saveNewAccount(account)
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
		let vaultConfig = VaultConfig(id: vaultConfigID, format: 8, cipherCombo: .sivCtrMac, shorteningThreshold: 220)
		let token = try vaultConfig.toToken(keyId: "masterkeyfile:masterkey.cryptomator", rawKey: masterkey.rawKey)
		cloudProviderMock.filesToDownload[vaultConfigPath.path] = token
		cloudProviderMock.cloudMetadata[vaultConfigPath.path] = CloudItemMetadata(name: vaultConfigPath.lastPathComponent, cloudPath: vaultConfigPath, itemType: .file, lastModifiedDate: vaultConfigLastModifiedDate, size: nil)

		let vaultDetails = VaultDetails(name: "ExistingVault", vaultPath: vaultPath)
		try await manager.createFromExisting(withVaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultItem: vaultDetails, password: "pw", storePasswordInKeychain: true)
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
		XCTAssertEqual(.sivCtrMac, savedVaultConfig.cipherCombo)
		XCTAssertEqual(8, savedVaultConfig.format)
	}

	func testCreateLegacyFromExisting() async throws {
		let delegateAccountUID = UUID().uuidString
		let account = CloudProviderAccount(accountUID: delegateAccountUID, cloudProviderType: .dropbox)
		try providerAccountManager.saveNewAccount(account)
		let vaultPath = CloudPath("/ExistingVault/")
		let masterkeyPath = vaultPath.appendingPathComponent("masterkey.cryptomator")
		guard let managerMock = manager as? VaultManagerMock else {
			XCTFail("Could not convert manager to VaultManagerMock")
			return
		}

		cloudProviderMock.filesToDownload[masterkeyPath.path] = try managerMock.exportMasterkey(masterkey, vaultVersion: 7, password: "pw")
		cloudProviderMock.cloudMetadata[masterkeyPath.path] = CloudItemMetadata(name: masterkeyPath.lastPathComponent, cloudPath: masterkeyPath, itemType: .file, lastModifiedDate: masterkeyFileLastModifiedDate, size: nil)

		let legacyVaultDetails = VaultDetails(name: "ExistingVault", vaultPath: vaultPath)
		try await manager.createLegacyFromExisting(withVaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultItem: legacyVaultDetails, password: "pw", storePasswordInKeychain: true)
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
	}

	// MARK: Manual Unlock

	func testManualUnlockVaultV8() throws {
		try manualUnlockVaultV8()
		XCTAssertFalse(masterkeyCacheManagerMock.cacheMasterkeyForVaultUIDCalled)
	}

	func testManualUnlockVaultV7() throws {
		let kek = try setupManualUnlockTest(vaultVersion: 7)
		let decorator = try manager.manualUnlockVault(withUID: vaultUID, kek: kek)
		XCTAssert(decorator is VaultFormat7ProviderDecorator, "Decorator is not a VaultFormat7ProviderDecorator")
		XCTAssertFalse(masterkeyCacheManagerMock.cacheMasterkeyForVaultUIDCalled)
	}

	func testManualUnlockVaultV6() throws {
		let kek = try setupManualUnlockTest(vaultVersion: 6)
		let decorator = try manager.manualUnlockVault(withUID: vaultUID, kek: kek)
		XCTAssert(decorator is VaultFormat6ProviderDecorator, "Decorator is not a VaultFormat6ProviderDecorator")
		XCTAssertFalse(masterkeyCacheManagerMock.cacheMasterkeyForVaultUIDCalled)
	}

	func testManualUnlockVaultThrowsForNonSupportedVaultVersion() throws {
		masterkeyCacheHelperMock.shouldCacheMasterkeyForVaultUIDReturnValue = true
		let kek = try setupManualUnlockTest(vaultVersion: 5)
		XCTAssertThrowsError(try manager.manualUnlockVault(withUID: vaultUID, kek: kek)) { error in
			guard case VaultProviderFactoryError.unsupportedVaultVersion(version: 5) = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}
		XCTAssertFalse(masterkeyCacheManagerMock.cacheMasterkeyForVaultUIDCalled)
	}

	func testManualUnlockVaultCachesMasterkey() throws {
		masterkeyCacheHelperMock.shouldCacheMasterkeyForVaultUIDReturnValue = true

		try manualUnlockVaultV8()
		XCTAssertEqual(1, masterkeyCacheManagerMock.cacheMasterkeyForVaultUIDCallsCount)
		XCTAssertEqual(vaultUID, masterkeyCacheManagerMock.cacheMasterkeyForVaultUIDReceivedArguments?.vaultUID)
		let passedMasterkey = try XCTUnwrap(masterkeyCacheManagerMock.cacheMasterkeyForVaultUIDReceivedArguments?.masterkey)
		XCTAssertEqual(masterkey.rawKey, passedMasterkey.rawKey)
	}

	// MARK: - Duplicate Vault prevention

	func testDuplicateCreateNewVault() async throws {
		let delegateAccountUID = UUID().uuidString
		let account = CloudProviderAccount(accountUID: delegateAccountUID, cloudProviderType: .dropbox)
		try providerAccountManager.saveNewAccount(account)

		let vaultPath = CloudPath("/Vault/")
		try await manager.createNewVault(withVaultUID: vaultUID, delegateAccountUID: account.accountUID, vaultPath: vaultPath, password: "pw", storePasswordInKeychain: false)

		await XCTAssertThrowsAsyncError(try await manager.createNewVault(withVaultUID: UUID().uuidString, delegateAccountUID: account.accountUID, vaultPath: vaultPath, password: "pw", storePasswordInKeychain: false)) { error in
			guard case LocalizedCloudProviderError.itemAlreadyExists = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}
	}

	func testDuplicateCreateFromExisting() async throws {
		let delegateAccountUID = UUID().uuidString
		let account = CloudProviderAccount(accountUID: delegateAccountUID, cloudProviderType: .dropbox)
		try providerAccountManager.saveNewAccount(account)
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
		let vaultConfig = VaultConfig(id: vaultConfigID, format: 8, cipherCombo: .sivCtrMac, shorteningThreshold: 220)
		let token = try vaultConfig.toToken(keyId: "masterkeyfile:masterkey.cryptomator", rawKey: masterkey.rawKey)
		cloudProviderMock.filesToDownload[vaultConfigPath.path] = token
		cloudProviderMock.cloudMetadata[vaultConfigPath.path] = CloudItemMetadata(name: vaultConfigPath.lastPathComponent, cloudPath: vaultConfigPath, itemType: .file, lastModifiedDate: vaultConfigLastModifiedDate, size: nil)

		let vaultDetails = VaultDetails(name: "ExistingVault", vaultPath: vaultPath)
		try await manager.createFromExisting(withVaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultItem: vaultDetails, password: "pw", storePasswordInKeychain: true)

		await XCTAssertThrowsAsyncError(try await manager.createFromExisting(withVaultUID: UUID().uuidString, delegateAccountUID: delegateAccountUID, vaultItem: vaultDetails, password: "pw", storePasswordInKeychain: true)) { error in
			guard case VaultAccountManagerError.vaultAccountAlreadyExists = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}
	}

	// MARK: - Move Vault

	func testMoveVault() async throws {
		let delegateAccountUID = UUID().uuidString
		let account = CloudProviderAccount(accountUID: delegateAccountUID, cloudProviderType: .dropbox)

		let vaultPath = CloudPath("/Vault/")
		try providerAccountManager.saveNewAccount(account)
		let vaultAccount = VaultAccount(vaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultPath: vaultPath, vaultName: "Vault")
		try accountManager.saveNewAccount(vaultAccount)
		let newVaultPath = CloudPath("/Foo/MovedVault")

		try await manager.moveVault(account: vaultAccount, to: newVaultPath)
		XCTAssertEqual(1, cloudProviderMock.moveFolderFromToCallsCount)
		XCTAssertEqual(newVaultPath, cloudProviderMock.moveFolderFromToReceivedArguments?.targetCloudPath)
		XCTAssertEqual(vaultPath, cloudProviderMock.moveFolderFromToReceivedArguments?.sourceCloudPath)

		let updatedAccount = try accountManager.getAccount(with: vaultUID)
		XCTAssertEqual(newVaultPath, updatedAccount.vaultPath)
		XCTAssertEqual("MovedVault", updatedAccount.vaultName)
		XCTAssertEqual(vaultAccount.delegateAccountUID, updatedAccount.delegateAccountUID)
		XCTAssertEqual(delegateAccountUID, updatedAccount.delegateAccountUID)

		guard let managerMock = manager as? VaultManagerMock else {
			XCTFail("Could not convert manager to VaultManagerMock")
			return
		}

		XCTAssertEqual(1, managerMock.addedFileProviderDomainDisplayName.count)
		XCTAssertEqual("MovedVault", managerMock.addedFileProviderDomainDisplayName[vaultUID])
	}

	func testMoveVaultClouderProviderFails() async throws {
		let delegateAccountUID = UUID().uuidString
		let account = CloudProviderAccount(accountUID: delegateAccountUID, cloudProviderType: .dropbox)

		let vaultPath = CloudPath("/Vault/")
		try providerAccountManager.saveNewAccount(account)
		let vaultAccount = VaultAccount(vaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultPath: vaultPath, vaultName: "Vault")
		try accountManager.saveNewAccount(vaultAccount)
		let newVaultPath = CloudPath("/Foo/MovedVault")

		// Simulate cloud provider error for moveFolder
		cloudProviderMock.moveFolderFromToThrowableError = CloudProviderError.itemAlreadyExists

		await XCTAssertThrowsAsyncError(try await manager.moveVault(account: vaultAccount, to: newVaultPath)) { error in
			guard case LocalizedCloudProviderError.itemAlreadyExists = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}
		XCTAssertFalse(cloudProviderMock.moveFolderFromToCalled)
		let fetchedVaultAccount: VaultAccount
		do {
			fetchedVaultAccount = try accountManager.getAccount(with: vaultUID)
		} catch {
			XCTFail("get vault account failed with error: \(error)")
			return
		}

		guard let managerMock = manager as? VaultManagerMock else {
			XCTFail("Could not convert manager to VaultManagerMock")
			return
		}

		XCTAssert(managerMock.addedFileProviderDomainDisplayName.isEmpty)

		// Check VaultAccount did not change
		XCTAssertEqual(vaultUID, fetchedVaultAccount.vaultUID)
		XCTAssertEqual(delegateAccountUID, fetchedVaultAccount.delegateAccountUID)
		XCTAssertEqual(vaultPath, fetchedVaultAccount.vaultPath)
		XCTAssertEqual("Vault", fetchedVaultAccount.vaultName)
	}

	func testMoveVaultInsideItself() async throws {
		let delegateAccountUID = UUID().uuidString
		let account = CloudProviderAccount(accountUID: delegateAccountUID, cloudProviderType: .dropbox)

		let vaultPath = CloudPath("/Vault/")
		try providerAccountManager.saveNewAccount(account)
		let vaultAccount = VaultAccount(vaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultPath: vaultPath, vaultName: "Vault")
		try accountManager.saveNewAccount(vaultAccount)
		let newVaultPath = CloudPath("/Vault/Foo")

		await XCTAssertThrowsAsyncError(try await manager.moveVault(account: vaultAccount, to: newVaultPath)) { error in
			guard case VaultManagerError.moveVaultInsideItself = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}
		XCTAssertFalse(cloudProviderMock.moveFolderFromToCalled)
		let fetchedVaultAccount: VaultAccount
		do {
			fetchedVaultAccount = try accountManager.getAccount(with: vaultUID)
		} catch {
			XCTFail("get vault account failed with error: \(error)")
			return
		}

		guard let managerMock = manager as? VaultManagerMock else {
			XCTFail("Could not convert manager to VaultManagerMock")
			return
		}

		XCTAssert(managerMock.addedFileProviderDomainDisplayName.isEmpty)

		// Check VaultAccount did not change
		XCTAssertEqual(vaultUID, fetchedVaultAccount.vaultUID)
		XCTAssertEqual(delegateAccountUID, fetchedVaultAccount.delegateAccountUID)
		XCTAssertEqual(vaultPath, fetchedVaultAccount.vaultPath)
		XCTAssertEqual("Vault", fetchedVaultAccount.vaultName)
	}

	// MARK: - Change Passphrase

	func testChangePassphrase() async throws {
		let delegateAccountUID = UUID().uuidString
		let account = CloudProviderAccount(accountUID: delegateAccountUID, cloudProviderType: .dropbox)
		let vaultPath = CloudPath("/Vault/")
		try providerAccountManager.saveNewAccount(account)
		let vaultAccount = VaultAccount(vaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultPath: vaultPath, vaultName: "Vault")
		try accountManager.saveNewAccount(vaultAccount)

		let oldPassphrase = "Password"

		let masterkeyFileData = try MasterkeyFile.lock(masterkey: masterkey, vaultVersion: 999, passphrase: oldPassphrase, pepper: [UInt8](), scryptCostParam: 2)

		let vaultConfigID = "ABB9F673-F3E8-41A7-A43B-D29F5DA65068"
		let vaultConfig = VaultConfig(id: vaultConfigID, format: 8, cipherCombo: .sivCtrMac, shorteningThreshold: 220)
		let token = try vaultConfig.toToken(keyId: "masterkeyfile:masterkey.cryptomator", rawKey: masterkey.rawKey)

		let oldLastUpToDateCheck = Date(timeIntervalSince1970: 0)
		vaultCacheMock.getCachedVaultWithVaultUIDReturnValue = CachedVault(vaultUID: vaultUID, masterkeyFileData: masterkeyFileData, vaultConfigToken: token, lastUpToDateCheck: oldLastUpToDateCheck, masterkeyFileLastModifiedDate: nil, vaultConfigLastModifiedDate: nil)
		cloudProviderMock.uploadFileLastModifiedDate["/Vault/masterkey.cryptomator"] = masterkeyFileLastModifiedDate
		let newPassphrase = "NewPassword"

		try await manager.changePassphrase(oldPassphrase: oldPassphrase, newPassphrase: newPassphrase, forVaultUID: vaultUID)
		try assertChangedPassphrase(from: oldPassphrase, to: newPassphrase)
	}

	func testChangePassphraseWithSavedPassword() async throws {
		let delegateAccountUID = UUID().uuidString
		let account = CloudProviderAccount(accountUID: delegateAccountUID, cloudProviderType: .dropbox)
		let vaultPath = CloudPath("/Vault/")
		try providerAccountManager.saveNewAccount(account)
		let vaultAccount = VaultAccount(vaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultPath: vaultPath, vaultName: "Vault")
		try accountManager.saveNewAccount(vaultAccount)

		let oldPassphrase = "Password"

		let masterkeyFileData = try MasterkeyFile.lock(masterkey: masterkey, vaultVersion: 999, passphrase: oldPassphrase, pepper: [UInt8](), scryptCostParam: 2)

		passwordManagerMock.savedPasswords[vaultUID] = oldPassphrase

		let vaultConfigID = "ABB9F673-F3E8-41A7-A43B-D29F5DA65068"
		let vaultConfig = VaultConfig(id: vaultConfigID, format: 8, cipherCombo: .sivCtrMac, shorteningThreshold: 220)
		let token = try vaultConfig.toToken(keyId: "masterkeyfile:masterkey.cryptomator", rawKey: masterkey.rawKey)

		let oldLastUpToDateCheck = Date(timeIntervalSince1970: 0)
		vaultCacheMock.getCachedVaultWithVaultUIDReturnValue = CachedVault(vaultUID: vaultUID, masterkeyFileData: masterkeyFileData, vaultConfigToken: token, lastUpToDateCheck: oldLastUpToDateCheck, masterkeyFileLastModifiedDate: nil, vaultConfigLastModifiedDate: nil)
		cloudProviderMock.uploadFileLastModifiedDate["/Vault/masterkey.cryptomator"] = masterkeyFileLastModifiedDate
		let newPassphrase = "NewPassword"

		try await manager.changePassphrase(oldPassphrase: oldPassphrase, newPassphrase: newPassphrase, forVaultUID: vaultUID)
		try assertChangedPassphrase(from: oldPassphrase, to: newPassphrase)
		XCTAssertEqual(1, passwordManagerMock.savedPasswords.count)
		XCTAssertEqual(newPassphrase, passwordManagerMock.savedPasswords[vaultUID])
	}

	// MARK: Helper

	private func manualUnlockVaultV8() throws {
		let kek = try setupManualUnlockTest(vaultVersion: 8)
		let decorator = try manager.manualUnlockVault(withUID: vaultUID, kek: kek)
		XCTAssert(decorator is VaultFormat8ProviderDecorator, "Decorator is not a VaultFormat8ProviderDecorator")
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
			let vaultConfig = VaultConfig(id: "ABB9F673-F3E8-41A7-A43B-D29F5DA65068", format: vaultVersion, cipherCombo: .sivCtrMac, shorteningThreshold: 220)
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

	private func assertChangedPassphrase(from oldPassphrase: String, to newPassphrase: String) throws {
		XCTAssertEqual(1, cloudProviderMock.uploadFileFromToReplaceExistingCallsCount)
		let uploadedMasterkeyFileData = try getUploadedMasterkeyFileData()
		let uploadedMasterkeyFile = try MasterkeyFile.withContentFromData(data: uploadedMasterkeyFileData)
		let uploadedMasterkey = try uploadedMasterkeyFile.unlock(passphrase: newPassphrase)
		XCTAssertThrowsError(try uploadedMasterkeyFile.unlock(passphrase: oldPassphrase)) { error in
			XCTAssertEqual(.invalidPassphrase, error as? MasterkeyFileError)
		}
		XCTAssertEqual(masterkey.rawKey, uploadedMasterkey.rawKey)
		try assertUpdatedVaultCache(with: uploadedMasterkeyFileData)
	}

	private func getUploadedMasterkeyFileData() throws -> Data {
		return try getUploadedData(at: vaultPath.appendingPathComponent("masterkey.cryptomator"))
	}

	private func getUploadedVaultConfigData() throws -> Data {
		return try getUploadedData(at: vaultPath.appendingPathComponent("vault.cryptomator"))
	}

	private func getUploadedData(at cloudPath: CloudPath) throws -> Data {
		let uploadedFileURL = cloudProviderMock.uploadFileFromToReplaceExistingReceivedInvocations
			.filter { $0.cloudPath == cloudPath }
			.map { cloudProviderMock.tmpDir.appendingPathComponent($0.cloudPath) }
			.first
		return try Data(contentsOf: XCTUnwrap(uploadedFileURL))
	}
}

struct VaultDetails: VaultItem {
	let name: String
	let vaultPath: CloudPath
}

extension Masterkey: Equatable {
	public static func == (lhs: Masterkey, rhs: Masterkey) -> Bool {
		return lhs.rawKey == rhs.rawKey
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
