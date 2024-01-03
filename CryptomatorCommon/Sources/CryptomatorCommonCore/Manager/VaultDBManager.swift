//
//  VaultDBManager.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 30.10.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptoKit
import CryptomatorCloudAccessCore
import CryptomatorCryptoLib
import FileProvider
import Foundation
import JOSESwift
import os.log
import Promises

public enum VaultManagerError: Error {
	case vaultAlreadyExists
	case vaultVersionNotSupported
	case fileProviderDomainNotFound
	case moveVaultInsideItself
	case missingVaultConfigToken
}

public protocol VaultManager {
	func createNewVault(withVaultUID vaultUID: String, delegateAccountUID: String, vaultPath: CloudPath, password: String, storePasswordInKeychain: Bool) -> Promise<Void>
	func createFromExisting(withVaultUID vaultUID: String, delegateAccountUID: String, vaultItem: VaultItem, password: String, storePasswordInKeychain: Bool) -> Promise<Void>
	func createLegacyFromExisting(withVaultUID vaultUID: String, delegateAccountUID: String, vaultItem: VaultItem, password: String, storePasswordInKeychain: Bool) -> Promise<Void>
	func manualUnlockVault(withUID vaultUID: String, kek: [UInt8]) throws -> CloudProvider
	func createVaultProvider(withUID vaultUID: String, masterkey: Masterkey) throws -> CloudProvider
	func removeVault(withUID vaultUID: String) throws -> Promise<Void>
	func removeAllUnusedFileProviderDomains() -> Promise<Void>
	func moveVault(account: VaultAccount, to targetVaultPath: CloudPath) -> Promise<Void>
	func changePassphrase(oldPassphrase: String, newPassphrase: String, forVaultUID vaultUID: String) -> Promise<Void>
	func addExistingHubVault(_ vault: ExistingHubVault) -> Promise<Void>
	func manualUnlockVault(withUID vaultUID: String, rawKey: [UInt8]) throws -> CloudProvider
}

public class VaultDBManager: VaultManager {
	public static let shared = VaultDBManager(providerManager: CloudProviderDBManager.shared,
	                                          vaultAccountManager: VaultAccountDBManager.shared,
	                                          vaultCache: VaultDBCache(),
	                                          passwordManager: VaultPasswordKeychainManager(),
	                                          masterkeyCacheManager: MasterkeyCacheKeychainManager.shared,
	                                          masterkeyCacheHelper: VaultKeepUnlockedManager.shared)
	let providerManager: CloudProviderDBManager
	let vaultAccountManager: VaultAccountManager
	private static let fakeVaultVersion = 999
	private let vaultCache: VaultCache
	private let passwordManager: VaultPasswordManager
	private let masterkeyCacheManager: MasterkeyCacheManager
	private let masterkeyCacheHelper: MasterkeyCacheHelper

	init(providerManager: CloudProviderDBManager,
	     vaultAccountManager: VaultAccountManager,
	     vaultCache: VaultCache,
	     passwordManager: VaultPasswordManager,
	     masterkeyCacheManager: MasterkeyCacheManager,
	     masterkeyCacheHelper: MasterkeyCacheHelper) {
		self.providerManager = providerManager
		self.vaultAccountManager = vaultAccountManager
		self.vaultCache = vaultCache
		self.passwordManager = passwordManager
		self.masterkeyCacheManager = masterkeyCacheManager
		self.masterkeyCacheHelper = masterkeyCacheHelper
	}

	// MARK: - Create New Vault

	/**
	 - Precondition: There is no `VaultAccount` for the `vaultUID` in the database yet.
	 - Precondition: A `CloudProviderAccount` with the `delegateAccountUID` exists in the database.
	 - Postcondition: The root path was created in the cloud and the masterkey file was uploaded.
	 - Postcondition: The masterkey file and vault config token are cached under the corresponding `vaultUID`.
	 - Postcondition: `storePasswordInKeychain` <=> the password for the masterkey is stored in the keychain.
	 - Postcondition: The passed `vaultUID`, `delegateAccountUID`, and `vaultPath` are stored as `VaultAccount` in the database.
	 */
	public func createNewVault(withVaultUID vaultUID: String, delegateAccountUID: String, vaultPath: CloudPath, password: String, storePasswordInKeychain: Bool) -> Promise<Void> {
		let tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true)
		let cipherCombo = CryptorScheme.sivGcm
		let vaultConfig = VaultConfig.createNew(format: 8, cipherCombo: cipherCombo, shorteningThreshold: 220)
		let masterkey: Masterkey
		let provider: LocalizedCloudProviderDecorator
		let vaultConfigToken: Data
		var cachedVault: CachedVault
		do {
			try FileManager.default.createDirectory(at: tmpDirURL, withIntermediateDirectories: true)
			masterkey = try Masterkey.createNew()
			vaultConfigToken = try vaultConfig.toToken(keyId: "masterkeyfile:masterkey.cryptomator", rawKey: masterkey.rawKey)
			provider = try LocalizedCloudProviderDecorator(delegate: providerManager.getProvider(with: delegateAccountUID))
			let masterkeyFileData = try exportMasterkey(masterkey, vaultVersion: VaultDBManager.fakeVaultVersion, password: password)
			cachedVault = CachedVault(vaultUID: vaultUID, masterkeyFileData: masterkeyFileData, vaultConfigToken: vaultConfigToken, lastUpToDateCheck: Date(), masterkeyFileLastModifiedDate: nil, vaultConfigLastModifiedDate: nil)
		} catch {
			return Promise(error)
		}
		let cryptor = Cryptor(masterkey: masterkey, scheme: cipherCombo)
		return provider.createFolder(at: vaultPath).then { _ -> Promise<CloudItemMetadata> in
			try self.uploadMasterkey(masterkey, password: password, vaultPath: vaultPath, provider: provider, tmpDirURL: tmpDirURL)
		}.then { masterkeyFileMetadata -> Promise<CloudItemMetadata> in
			cachedVault.masterkeyFileLastModifiedDate = masterkeyFileMetadata.lastModifiedDate
			return try self.uploadVaultConfigToken(vaultConfigToken, vaultPath: vaultPath, provider: provider, tmpDirURL: tmpDirURL)
		}.then { vaultConfigMetadata -> Promise<Void> in
			cachedVault.vaultConfigLastModifiedDate = vaultConfigMetadata.lastModifiedDate
			return try self.createVaultFolderStructure(cryptor: cryptor, vaultPath: vaultPath, provider: provider)
		}.then {
			return try self.uploadRootDirIdFile(cryptor: cryptor, vaultPath: vaultPath, provider: provider, tmpDirURL: tmpDirURL)
		}.then { _ -> Promise<Void> in
			let unverifiedVaultConfig = try UnverifiedVaultConfig(token: vaultConfigToken)
			_ = try VaultProviderFactory.createVaultProvider(from: unverifiedVaultConfig, masterkey: masterkey, vaultPath: vaultPath, with: provider.delegate)
			return self.addFileProviderDomain(forVaultUID: vaultUID, displayName: vaultPath.lastPathComponent)
		}.then {
			let account = VaultAccount(vaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultPath: vaultPath, vaultName: vaultPath.lastPathComponent)
			try self.vaultAccountManager.saveNewAccount(account)
			try self.postProcessVaultCreation(cachedVault: cachedVault, password: password, storePasswordInKeychain: storePasswordInKeychain)
			DDLogInfo("Created new vault \"\(vaultPath.lastPathComponent)\" (\(vaultUID))")
		}.catch { error in
			DDLogError("Creating new vault \"\(vaultPath.lastPathComponent)\" (\(vaultUID)) failed with error: \(error)")
		}
	}

	private func uploadMasterkey(_ masterkey: Masterkey, password: String, vaultPath: CloudPath, provider: CloudProvider, tmpDirURL: URL) throws -> Promise<CloudItemMetadata> {
		let masterkeyData = try exportMasterkey(masterkey, vaultVersion: VaultDBManager.fakeVaultVersion, password: password)
		return uploadMasterkeyFileData(masterkeyData, vaultPath: vaultPath, replaceExisting: false, provider: provider, tmpDirURL: tmpDirURL)
	}

	private func uploadMasterkeyFileData(_ data: Data, vaultPath: CloudPath, replaceExisting: Bool, provider: CloudProvider, tmpDirURL: URL) -> Promise<CloudItemMetadata> {
		let localMasterkeyURL = tmpDirURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
		do {
			try data.write(to: localMasterkeyURL)
		} catch {
			return Promise(error)
		}
		let masterkeyCloudPath = vaultPath.appendingPathComponent("masterkey.cryptomator")
		return provider.uploadFile(from: localMasterkeyURL, to: masterkeyCloudPath, replaceExisting: replaceExisting).always {
			try? FileManager.default.removeItem(at: localMasterkeyURL)
		}
	}

	private func uploadVaultConfigToken(_ token: Data, vaultPath: CloudPath, provider: CloudProvider, tmpDirURL: URL) throws -> Promise<CloudItemMetadata> {
		let localVaultConfigURL = tmpDirURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
		try token.write(to: localVaultConfigURL)
		let vaultConfigCloudPath = vaultPath.appendingPathComponent("vault.cryptomator")
		return provider.uploadFile(from: localVaultConfigURL, to: vaultConfigCloudPath, replaceExisting: false).always {
			try? FileManager.default.removeItem(at: localVaultConfigURL)
		}
	}

	private func createVaultFolderStructure(cryptor: Cryptor, vaultPath: CloudPath, provider: CloudProvider) throws -> Promise<Void> {
		let rootDirPath = try VaultDBManager.getRootDirectoryPath(for: cryptor, vaultPath: vaultPath)
		let dPath = vaultPath.appendingPathComponent("d")
		return provider.createFolder(at: dPath).then { _ -> Promise<Void> in
			let twoCharsPath = rootDirPath.deletingLastPathComponent()
			return provider.createFolder(at: twoCharsPath)
		}.then {
			provider.createFolder(at: rootDirPath)
		}
	}

	private func uploadRootDirIdFile(cryptor: Cryptor, vaultPath: CloudPath, provider: CloudProvider, tmpDirURL: URL) throws -> Promise<Void> {
		let cleartextDirIdFileURL = tmpDirURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
		try Data().write(to: cleartextDirIdFileURL)
		let ciphertextDirIdFileURL = tmpDirURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
		try cryptor.encryptContent(from: cleartextDirIdFileURL, to: ciphertextDirIdFileURL)
		try? FileManager.default.removeItem(at: cleartextDirIdFileURL)

		let rootDirPath = try VaultDBManager.getRootDirectoryPath(for: cryptor, vaultPath: vaultPath)
		let ciphertextDirIdFileCloudPath = rootDirPath.appendingPathComponent("dirid.c9r")
		return provider.uploadFile(from: ciphertextDirIdFileURL, to: ciphertextDirIdFileCloudPath, replaceExisting: false).then { _ in
			// ignore result
		}.recover { _ in
			// ignore error
		}.always {
			try? FileManager.default.removeItem(at: ciphertextDirIdFileURL)
		}
	}

	// MARK: - Open Existing Vault

	/**
	 Imports an existing Vault.

	 - Precondition: There is no `VaultAccount` for the `vaultUID` in the database yet.
	 - Precondition: A `CloudProviderAccount` with the `delegateAccountUID` exists in the database.
	 - Precondition: The vault config file at `vaultItem.vaultPath.appendingPathComponent("vault.cryptomator")` exists in the cloud.
	 - Precondition: The masterkey file at `vaultItem.vaultPath.appendingPathComponent("masterkey.cryptomator")` exists in the cloud.
	 - Postcondition: The masterkey file and vault config token are cached under the corresponding `vaultUID`.
	 - Postcondition: `storePasswordInKeychain` <=> the password for the masterkey is stored in the keychain.
	 - Postcondition: The passed `vaultUID`, `delegateAccountUID`, and `vaultItem.vaultPath` are stored as `VaultAccount` in the database.
	 */
	public func createFromExisting(withVaultUID vaultUID: String, delegateAccountUID: String, vaultItem: VaultItem, password: String, storePasswordInKeychain: Bool) -> Promise<Void> {
		let provider: LocalizedCloudProviderDecorator
		do {
			provider = try LocalizedCloudProviderDecorator(delegate: providerManager.getProvider(with: delegateAccountUID))
		} catch {
			return Promise(error)
		}
		let tmpDirURL = FileManager.default.temporaryDirectory
		let localVaultConfigURL = tmpDirURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
		let localMasterkeyURL = tmpDirURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
		let vaultPath = vaultItem.vaultPath
		let vaultConfigPath = vaultPath.appendingPathComponent("vault.cryptomator")
		let masterkeyPath = vaultPath.appendingPathComponent("masterkey.cryptomator")
		return provider.downloadFileWithMetadata(from: vaultConfigPath, to: localVaultConfigURL).then { vaultConfigMetadata in
			all(provider.downloadFileWithMetadata(from: masterkeyPath, to: localMasterkeyURL), Promise(vaultConfigMetadata))
		}.then { masterkeyFileMetadata, vaultConfigMetadata -> CachedVault in
			let vaultConfigToken = try Data(contentsOf: localVaultConfigURL)
			let masterkeyFileData = try Data(contentsOf: localMasterkeyURL)
			let unverifiedVaultConfig = try UnverifiedVaultConfig(token: vaultConfigToken)
			let masterkeyFile = try MasterkeyFile.withContentFromURL(url: localMasterkeyURL)
			let masterkey = try masterkeyFile.unlock(passphrase: password)
			_ = try VaultProviderFactory.createVaultProvider(from: unverifiedVaultConfig, masterkey: masterkey, vaultPath: vaultPath, with: provider.delegate)
			return CachedVault(vaultUID: vaultUID, masterkeyFileData: masterkeyFileData, vaultConfigToken: vaultConfigToken, lastUpToDateCheck: Date(), masterkeyFileLastModifiedDate: masterkeyFileMetadata.lastModifiedDate, vaultConfigLastModifiedDate: vaultConfigMetadata.lastModifiedDate)
		}.then { cachedVault -> Promise<(CachedVault, Void)> in
			all(Promise(cachedVault), self.addFileProviderDomain(forVaultUID: vaultUID, displayName: vaultItem.name))
		}.then { cachedVault, _ -> Void in
			let vaultAccount = VaultAccount(vaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultPath: vaultPath, vaultName: vaultItem.name)
			try self.vaultAccountManager.saveNewAccount(vaultAccount)
			try self.postProcessVaultCreation(cachedVault: cachedVault, password: password, storePasswordInKeychain: storePasswordInKeychain)
			DDLogInfo("Opened existing vault \"\(vaultItem.name)\" (\(vaultUID))")
		}.catch { error in
			DDLogError("Opening existing vault \"\(vaultItem.name)\" (\(vaultUID)) failed with error: \(error)")
		}
	}

	// swiftlint:disable:next function_parameter_count
	public func createFromExisting(withVaultUID vaultUID: String, delegateAccountUID: String, downloadedVaultConfig: DownloadedVaultConfig, downloadedMasterkey: DownloadedMasterkeyFile, vaultItem: VaultItem, password: String) -> Promise<Void> {
		let provider: LocalizedCloudProviderDecorator
		do {
			provider = try LocalizedCloudProviderDecorator(delegate: providerManager.getProvider(with: delegateAccountUID))
		} catch {
			return Promise(error)
		}
		let vaultPath = vaultItem.vaultPath
		let vaultConfigMetadata = downloadedVaultConfig.metadata
		let vaultConfigToken = downloadedVaultConfig.token
		let masterkeyFile = downloadedMasterkey.masterkeyFile
		let masterkeyFileData = downloadedMasterkey.masterkeyFileData
		let masterkeyFileMetadata = downloadedMasterkey.metadata
		do {
			let masterkey = try masterkeyFile.unlock(passphrase: password)
			_ = try VaultProviderFactory.createVaultProvider(from: downloadedVaultConfig.vaultConfig, masterkey: masterkey, vaultPath: vaultPath, with: provider.delegate)
		} catch {
			return Promise(error)
		}
		let vaultConfigLastModifiedDate = vaultConfigMetadata.lastModifiedDate
		let masterkeyFileLastModifiedDate = masterkeyFileMetadata.lastModifiedDate
		let lastUpToDateCheck: Date = (vaultConfigLastModifiedDate ?? .distantPast) < (masterkeyFileLastModifiedDate ?? .distantPast) ? masterkeyFileLastModifiedDate! : vaultConfigLastModifiedDate ?? Date()
		let cachedVault = CachedVault(vaultUID: vaultUID, masterkeyFileData: masterkeyFileData, vaultConfigToken: vaultConfigToken, lastUpToDateCheck: lastUpToDateCheck, masterkeyFileLastModifiedDate: masterkeyFileMetadata.lastModifiedDate, vaultConfigLastModifiedDate: vaultConfigMetadata.lastModifiedDate)
		return addFileProviderDomain(forVaultUID: vaultUID, displayName: vaultItem.name).then {
			let vaultAccount = VaultAccount(vaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultPath: vaultPath, vaultName: vaultItem.name)
			try self.vaultAccountManager.saveNewAccount(vaultAccount)
			try self.postProcessVaultCreation(cachedVault: cachedVault, password: password, storePasswordInKeychain: false)
			DDLogInfo("Opened existing vault \"\(vaultItem.name)\" (\(vaultUID))")
		}
	}

	public func getUnverifiedVaultConfig(delegateAccountUID: String, vaultItem: VaultItem) -> Promise<DownloadedVaultConfig> {
		let provider: LocalizedCloudProviderDecorator
		do {
			provider = try LocalizedCloudProviderDecorator(delegate: providerManager.getProvider(with: delegateAccountUID))
		} catch {
			return Promise(error)
		}
		let tmpDirURL = FileManager.default.temporaryDirectory
		let localVaultConfigURL = tmpDirURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
		let vaultPath = vaultItem.vaultPath
		let vaultConfigPath = vaultPath.appendingPathComponent("vault.cryptomator")
		return provider.downloadFileWithMetadata(from: vaultConfigPath, to: localVaultConfigURL).then { vaultConfigMetadata -> DownloadedVaultConfig in
			let vaultConfigToken = try Data(contentsOf: localVaultConfigURL)
			let unverifiedVaultConfig = try UnverifiedVaultConfig(token: vaultConfigToken)
			return DownloadedVaultConfig(vaultConfig: unverifiedVaultConfig, token: vaultConfigToken, metadata: vaultConfigMetadata)
		}
	}

	public func downloadMasterkeyFile(delegateAccountUID: String, vaultItem: VaultItem) -> Promise<DownloadedMasterkeyFile> {
		let provider: LocalizedCloudProviderDecorator
		do {
			provider = try LocalizedCloudProviderDecorator(delegate: providerManager.getProvider(with: delegateAccountUID))
		} catch {
			return Promise(error)
		}
		let tmpDirURL = FileManager.default.temporaryDirectory
		let localMasterkeyURL = tmpDirURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
		let vaultPath = vaultItem.vaultPath
		let masterkeyPath = vaultPath.appendingPathComponent("masterkey.cryptomator")
		return provider.downloadFileWithMetadata(from: masterkeyPath, to: localMasterkeyURL).then { masterkeyFileMetadata -> DownloadedMasterkeyFile in
			let masterkeyFileData = try Data(contentsOf: localMasterkeyURL)
			let masterkeyFile = try MasterkeyFile.withContentFromData(data: masterkeyFileData)
			return DownloadedMasterkeyFile(masterkeyFile: masterkeyFile, metadata: masterkeyFileMetadata, masterkeyFileData: masterkeyFileData)
		}
	}

	public func addExistingHubVault(_ vault: ExistingHubVault) -> Promise<Void> {
		let delegateAccountUID = vault.delegateAccountUID
		let provider: LocalizedCloudProviderDecorator
		do {
			provider = try LocalizedCloudProviderDecorator(delegate: providerManager.getProvider(with: delegateAccountUID))
		} catch {
			return Promise(error)
		}
		let vaultItem = vault.vaultItem
		let downloadedVaultConfig = vault.downloadedVaultConfig
		let jweData = vault.jweData

		let vaultPath = vaultItem.vaultPath
		let vaultConfigMetadata = downloadedVaultConfig.metadata
		let vaultConfigToken = downloadedVaultConfig.token
		let masterkey: Masterkey
		do {
			let jwe = try JWE(compactSerialization: jweData)
			masterkey = try JWEHelper.decryptVaultKey(jwe: jwe, with: vault.privateKey)
		} catch {
			return Promise(error)
		}
		do {
			_ = try VaultProviderFactory.createVaultProvider(from: downloadedVaultConfig.vaultConfig, masterkey: masterkey, vaultPath: vaultPath, with: provider.delegate)
		} catch {
			return Promise(error)
		}
		let vaultUID = vault.vaultUID
		let cachedVault = CachedVault(vaultUID: vaultUID,
		                              masterkeyFileData: jweData,
		                              vaultConfigToken: vaultConfigToken,
		                              lastUpToDateCheck: Date(),
		                              masterkeyFileLastModifiedDate: nil,
		                              vaultConfigLastModifiedDate: vaultConfigMetadata.lastModifiedDate)
		return addFileProviderDomain(forVaultUID: vaultUID, displayName: vaultItem.name).then {
			let vaultAccount = VaultAccount(vaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultPath: vaultPath, vaultName: vaultItem.name)
			try self.vaultAccountManager.saveNewAccount(vaultAccount)
			do {
				try self.postProcessVaultCreation(cachedVault: cachedVault, password: nil)
			} catch {
				try self.vaultAccountManager.removeAccount(with: vaultUID)
				_ = self.removeFileProviderDomain(withVaultUID: vaultUID)
				throw error
			}
			DDLogInfo("Opened existing vault \"\(vaultItem.name)\" (\(vaultUID))")
		}
	}

	/**
	 Imports an existing legacy Vault.

	 Supported legacy vault formats are 6 & 7.

	 - Precondition: There is no `VaultAccount` for the `vaultUID` in the database yet.
	 - Precondition: A `CloudProviderAccount` with the `delegateAccountUID` exists in the database.
	 - Precondition: The masterkey file at `vaultItem.vaultPath.appendingPathComponent("masterkey.cryptomator")` exists in the cloud.
	 - Postcondition: The masterkey file is cached under the corresponding `vaultUID`.
	 - Postcondition: `storePasswordInKeychain` <=> the password for the masterkey is stored in the keychain.
	 - Postcondition: The passed `vaultUID`, `delegateAccountUID`, and `vaultItem.vaultPath` are stored as `VaultAccount` in the database.
	 */
	public func createLegacyFromExisting(withVaultUID vaultUID: String, delegateAccountUID: String, vaultItem: VaultItem, password: String, storePasswordInKeychain: Bool) -> Promise<Void> {
		let provider: LocalizedCloudProviderDecorator
		do {
			provider = try LocalizedCloudProviderDecorator(delegate: providerManager.getProvider(with: delegateAccountUID))
		} catch {
			return Promise(error)
		}
		let tmpDirURL = FileManager.default.temporaryDirectory
		let localMasterkeyURL = tmpDirURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
		let vaultPath = vaultItem.vaultPath
		let masterkeyPath = vaultPath.appendingPathComponent("masterkey.cryptomator")
		return provider.downloadFileWithMetadata(from: masterkeyPath, to: localMasterkeyURL).then { masterkeyFileMetadata -> Promise<(CachedVault, Void)>in
			let masterkeyFileData = try Data(contentsOf: localMasterkeyURL)
			let masterkeyFile = try MasterkeyFile.withContentFromData(data: masterkeyFileData)
			let masterkey = try masterkeyFile.unlock(passphrase: password)
			_ = try VaultProviderFactory.createLegacyVaultProvider(from: masterkey, vaultVersion: masterkeyFile.version, vaultPath: vaultPath, with: provider.delegate)
			let cachedVault = CachedVault(vaultUID: vaultUID, masterkeyFileData: masterkeyFileData, vaultConfigToken: nil, lastUpToDateCheck: Date(), masterkeyFileLastModifiedDate: masterkeyFileMetadata.lastModifiedDate, vaultConfigLastModifiedDate: nil)
			return all(Promise(cachedVault), self.addFileProviderDomain(forVaultUID: vaultUID, displayName: vaultItem.name))
		}.then { cachedVault, _ -> Void in
			let vaultAccount = VaultAccount(vaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultPath: vaultPath, vaultName: vaultItem.name)
			try self.vaultAccountManager.saveNewAccount(vaultAccount)
			try self.postProcessVaultCreation(cachedVault: cachedVault, password: password, storePasswordInKeychain: storePasswordInKeychain)
			DDLogInfo("Opened existing legacy vault \"\(vaultItem.name)\" (\(vaultUID))")
		}.catch { error in
			DDLogError("Opening existing legacy vault \"\(vaultItem.name)\" (\(vaultUID)) failed with error: \(error)")
		}
	}

	// MARK: - Remove Vault Locally

	/**
	 - Precondition: A `VaultAccount` for the `vaultUID` exists in the database.
	 - Precondition: A `NSFileProviderDomain` with the `vaultUID` as `identifier` exists.
	 - Postcondition: The `VaultAccount` for the `vaultUID` was removed in the database.
	 - Postcondition: The password for the `vaultUID` was removed.
	 - Postcondition: There is no longer a masterkey cached in the keychain for the `vaultUID`.
	 - Postcondition: The `NSFileProviderDomain` with the `vaultUID` as `identifier` was removed from the `NSFileProvider`.
	 */
	public func removeVault(withUID vaultUID: String) throws -> Promise<Void> {
		do {
			try passwordManager.removePassword(forVaultUID: vaultUID)
			try vaultAccountManager.removeAccount(with: vaultUID)
			try masterkeyCacheManager.removeCachedMasterkey(forVaultUID: vaultUID)
			return removeFileProviderDomain(withVaultUID: vaultUID).then { _ in
				DDLogInfo("Removed vault \(vaultUID)")
			}.catch { error in
				DDLogError("Removing vault \(vaultUID) failed with error: \(error)")
			}
		} catch {
			DDLogError("Removing vault \(vaultUID) failed with error: \(error)")
			throw error
		}
	}

	/**
	 Removes all unused FileProvider domains.

	 An unused FileProviderDomain is a domain that has no associated vault in the database.
	 An unused domain can be caused, for example, when the user reinstalls the app.
	 */
	public func removeAllUnusedFileProviderDomains() -> Promise<Void> {
		let vaultUIDs: [String]
		do {
			let vaults = try vaultAccountManager.getAllAccounts()
			vaultUIDs = vaults.map { $0.vaultUID }
		} catch {
			return Promise(error)
		}
		return NSFileProviderManager.getDomains().then { domains -> Promise<Void> in
			let unusedDomains = domains.filter { !vaultUIDs.contains($0.identifier.rawValue) }
			return self.removeUnusedDomainsFromFileProvider(unusedDomains)
		}
	}

	private func removeUnusedDomainsFromFileProvider(_ domains: [NSFileProviderDomain]) -> Promise<Void> {
		return Promise(on: .global()) { fulfill, _ in
			for domain in domains {
				do {
					try awaitPromise(self.removeFileProviderDomain(domain))
					DDLogInfo("Successfully removed the unused FileProvider domain: \(domain)")
				} catch {
					DDLogError("Remove unused FileProvider domain: \(domain) failed with error: \(error)")
				}
			}
			fulfill(())
		}
	}

	// MARK: - Manual Unlock Vault

	/**
	 Manually unlock a cached vault via KEK.

	 The masterkey gets cached in the keychain if the corresponding Auto-Lock timeout is not `KeepUnlockedDuration.off`.
	 */
	public func manualUnlockVault(withUID vaultUID: String, kek: [UInt8]) throws -> CloudProvider {
		let cachedVault = try vaultCache.getCachedVault(withVaultUID: vaultUID)
		let masterkeyFile = try MasterkeyFile.withContentFromData(data: cachedVault.masterkeyFileData)
		let masterkey = try masterkeyFile.unlock(kek: kek)
		return try createVaultProvider(cachedVault: cachedVault, masterkey: masterkey, masterkeyFile: masterkeyFile)
	}

	public func manualUnlockVault(withUID vaultUID: String, rawKey: [UInt8]) throws -> CloudProvider {
		let cachedVault = try vaultCache.getCachedVault(withVaultUID: vaultUID)

		guard let vaultConfigToken = cachedVault.vaultConfigToken else {
			throw VaultManagerError.missingVaultConfigToken
		}
		let unverifiedVaultConfig = try UnverifiedVaultConfig(token: vaultConfigToken)
		let vaultAccount = try vaultAccountManager.getAccount(with: vaultUID)
		let provider = try providerManager.getProvider(with: vaultAccount.delegateAccountUID)
		let masterkey = Masterkey.createFromRaw(rawKey: rawKey)
		let decorator = try VaultProviderFactory.createVaultProvider(from: unverifiedVaultConfig,
		                                                             masterkey: masterkey,
		                                                             vaultPath: vaultAccount.vaultPath,
		                                                             with: provider)
		if masterkeyCacheHelper.shouldCacheMasterkey(forVaultUID: vaultUID) {
			try masterkeyCacheManager.cacheMasterkey(masterkey, forVaultUID: vaultUID)
		}
		return decorator
	}

	public func createVaultProvider(withUID vaultUID: String, masterkey: Masterkey) throws -> CloudProvider {
		let cachedVault = try vaultCache.getCachedVault(withVaultUID: vaultUID)
		let masterkeyFile = try MasterkeyFile.withContentFromData(data: cachedVault.masterkeyFileData)
		return try createVaultProvider(cachedVault: cachedVault, masterkey: masterkey, masterkeyFile: masterkeyFile)
	}

	private func createVaultProvider(cachedVault: CachedVault, masterkey: Masterkey, masterkeyFile: MasterkeyFile) throws -> CloudProvider {
		let vaultUID = cachedVault.vaultUID
		let vaultAccount = try vaultAccountManager.getAccount(with: vaultUID)
		let provider = try providerManager.getProvider(with: vaultAccount.delegateAccountUID)
		let decorator: CloudProvider
		if let vaultConfigToken = cachedVault.vaultConfigToken {
			let unverifiedVaultConfig = try UnverifiedVaultConfig(token: vaultConfigToken)
			decorator = try VaultProviderFactory.createVaultProvider(from: unverifiedVaultConfig, masterkey: masterkey, vaultPath: vaultAccount.vaultPath, with: provider)
		} else {
			decorator = try VaultProviderFactory.createLegacyVaultProvider(from: masterkey, vaultVersion: masterkeyFile.version, vaultPath: vaultAccount.vaultPath, with: provider)
		}
		if masterkeyCacheHelper.shouldCacheMasterkey(forVaultUID: vaultUID) {
			try masterkeyCacheManager.cacheMasterkey(masterkey, forVaultUID: vaultUID)
		}
		return decorator
	}

	// MARK: - Move Vault

	public func moveVault(account: VaultAccount, to targetVaultPath: CloudPath) -> Promise<Void> {
		guard !targetVaultPath.contains(account.vaultPath) else {
			return Promise(VaultManagerError.moveVaultInsideItself)
		}
		let provider: CloudProvider
		do {
			provider = try LocalizedCloudProviderDecorator(delegate: providerManager.getProvider(with: account.delegateAccountUID))
		} catch {
			return Promise(error)
		}
		return provider.moveFolder(from: account.vaultPath, to: targetVaultPath).then { _ -> VaultAccount in
			let updatedVaultAccount = VaultAccount(vaultUID: account.vaultUID,
			                                       delegateAccountUID: account.delegateAccountUID,
			                                       vaultPath: targetVaultPath,
			                                       vaultName: targetVaultPath.lastPathComponent)
			try self.vaultAccountManager.updateAccount(updatedVaultAccount)
			return updatedVaultAccount
		}.then { updatedVaultAccount in
			self.addFileProviderDomain(forVaultUID: updatedVaultAccount.vaultUID, displayName: updatedVaultAccount.vaultName)
		}
	}

	// MARK: - Change Passphrase

	public func changePassphrase(oldPassphrase: String, newPassphrase: String, forVaultUID vaultUID: String) -> Promise<Void> {
		let tmpDirURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		let provider: LocalizedCloudProviderDecorator
		let vaultAccount: VaultAccount
		let masterkeyFileData: Data
		do {
			let cachedVault = try vaultCache.getCachedVault(withVaultUID: vaultUID)
			masterkeyFileData = try changePassphrase(masterkeyFileData: cachedVault.masterkeyFileData, oldPassphrase: oldPassphrase, newPassphrase: newPassphrase)
			vaultAccount = try vaultAccountManager.getAccount(with: vaultUID)
			try FileManager.default.createDirectory(at: tmpDirURL, withIntermediateDirectories: true)
			provider = try LocalizedCloudProviderDecorator(delegate: providerManager.getProvider(with: vaultAccount.delegateAccountUID))
		} catch {
			return Promise(error)
		}
		return uploadMasterkeyFileData(masterkeyFileData, vaultPath: vaultAccount.vaultPath, replaceExisting: true, provider: provider, tmpDirURL: tmpDirURL).then { metadata -> Void in
			try self.postProcessChangePassphrase(masterkeyFileData: masterkeyFileData, masterkeyFileDataLastModifiedDate: metadata.lastModifiedDate, forVaultUID: vaultUID, newPassphrase: newPassphrase)
		}
	}

	public func recoverMissingFileProviderDomains() -> Promise<Void> {
		let vaults: [VaultAccount]
		do {
			vaults = try vaultAccountManager.getAllAccounts()
		} catch {
			return Promise(error)
		}
		return NSFileProviderManager.getDomains().then { domains -> Promise<Void> in
			let domainIdentifiers = domains.map { $0.identifier.rawValue }
			let vaultsWithMissingDomains = vaults.filter { !domainIdentifiers.contains($0.vaultUID) }
			return self.recoverFileProviderDomains(for: vaultsWithMissingDomains)
		}
	}

	// MARK: - Internal

	func postProcessVaultCreation(cachedVault: CachedVault, password: String, storePasswordInKeychain: Bool) throws {
		try vaultCache.cache(cachedVault)
		if storePasswordInKeychain {
			try passwordManager.setPassword(password, forVaultUID: cachedVault.vaultUID)
		}
	}

	/**
	 Post-processing the vault creation by caching the vault and storing the corresponding master password (if set) in the keychain.
	 */
	func postProcessVaultCreation(cachedVault: CachedVault, password: String?) throws {
		try vaultCache.cache(cachedVault)
		if let password = password {
			try passwordManager.setPassword(password, forVaultUID: cachedVault.vaultUID)
		}
	}

	func postProcessChangePassphrase(masterkeyFileData: Data, masterkeyFileDataLastModifiedDate: Date?, forVaultUID vaultUID: String, newPassphrase: String) throws {
		try vaultCache.setMasterkeyFileData(masterkeyFileData, forVaultUID: vaultUID, lastModifiedDate: masterkeyFileDataLastModifiedDate)
		if try passwordManager.hasPassword(forVaultUID: vaultUID) {
			try passwordManager.setPassword(newPassphrase, forVaultUID: vaultUID)
		}
	}

	static func getRootDirectoryPath(for cryptor: Cryptor, vaultPath: CloudPath) throws -> CloudPath {
		let digest = try cryptor.encryptDirId(Data())
		let i = digest.index(digest.startIndex, offsetBy: 2)
		return vaultPath.appendingPathComponent("d/\(digest[..<i])/\(digest[i...])")
	}

	func exportMasterkey(_ masterkey: Masterkey, vaultVersion: Int, password: String) throws -> Data {
		return try MasterkeyFile.lock(masterkey: masterkey, vaultVersion: vaultVersion, passphrase: password)
	}

	func changePassphrase(masterkeyFileData: Data, oldPassphrase: String, newPassphrase: String) throws -> Data {
		return try MasterkeyFile.changePassphrase(masterkeyFileData: masterkeyFileData, oldPassphrase: oldPassphrase, newPassphrase: newPassphrase)
	}

	func removeFileProviderDomain(withVaultUID vaultUID: String) -> Promise<Void> {
		return getFileProviderDomain(forVaultUID: vaultUID).then { domainForVault in
			self.removeFileProviderDomain(domainForVault)
		}
	}

	private func removeFileProviderDomain(_ domain: NSFileProviderDomain) -> Promise<Void> {
		return NSFileProviderManager.remove(domain).then {
			let documentStorageURL = NSFileProviderManager.default.documentStorageURL
			let domainDocumentStorageURL = documentStorageURL.appendingPathComponent(domain.pathRelativeToDocumentStorage)
			try FileManager.default.removeItem(at: domainDocumentStorageURL)
		}
	}

	private func getFileProviderDomain(forVaultUID vaultUID: String) -> Promise<NSFileProviderDomain> {
		return NSFileProviderManager.getDomains().then { domains -> NSFileProviderDomain in
			let domain = domains.first { $0.identifier.rawValue == vaultUID }
			guard let domainForVault = domain else {
				throw VaultManagerError.fileProviderDomainNotFound
			}
			return domainForVault
		}
	}

	func addFileProviderDomain(forVaultUID vaultUID: String, displayName: String) -> Promise<Void> {
		let domain = NSFileProviderDomain(vaultUID: vaultUID, displayName: displayName)
		return NSFileProviderManager.add(domain)
	}

	private func recoverFileProviderDomains(for vaults: [VaultAccount]) -> Promise<Void> {
		return Promise(on: .global()) { fulfill, _ in
			for vault in vaults {
				do {
					try awaitPromise(self.addFileProviderDomain(forVaultUID: vault.vaultUID, displayName: vault.vaultName))
					DDLogInfo("Successfully recovered FileProvider domain for vault: \(vault.vaultName) - \(vault.vaultUID)")
				} catch {
					DDLogError("Recover FileProvider domain for vault: \(vault.vaultName) - \(vault.vaultUID) failed with error: \(error)")
				}
			}
			fulfill(())
		}
	}
}

extension CloudProvider {
	func downloadFileWithMetadata(from cloudPath: CloudPath, to localURL: URL) -> Promise<CloudItemMetadata> {
		let fetchItemMetadataPromise = fetchItemMetadata(at: cloudPath)
		return fetchItemMetadataPromise.then { _ in
			self.downloadFile(from: cloudPath, to: localURL)
		}.then {
			return fetchItemMetadataPromise
		}
	}
}

public extension NSFileProviderManager {
	static func getDomains() -> Promise<[NSFileProviderDomain]> {
		return Promise<[NSFileProviderDomain]> { fulfill, reject in
			NSFileProviderManager.getDomainsWithCompletionHandler { domains, error in
				if let error = error {
					os_log("NSFileProviderManager.getDomains() Error: %@", log: .default, type: .error, String(describing: error))
					reject(error)
				} else {
					fulfill(domains)
				}
			}
		}
	}

	static func remove(_ domain: NSFileProviderDomain) -> Promise<Void> {
		return Promise<Void> { fulfill, reject in
			NSFileProviderManager.remove(domain) { error in
				if let error = error {
					os_log("NSFileProviderManager.remove() \"%@\" Error: %@", log: .default, type: .error, domain.identifier.rawValue, String(describing: error))
					reject(error)
				} else {
					fulfill(())
				}
			}
		}
	}

	class func add(_ domain: NSFileProviderDomain) -> Promise<Void> {
		return Promise<Void> { fulfill, reject in
			NSFileProviderManager.add(domain) { error in
				if let error = error {
					os_log("NSFileProviderManager.add() \"%@\" Error: %@", log: .default, type: .error, domain.identifier.rawValue, String(describing: error))
					reject(error)
				} else {
					fulfill(())
				}
			}
		}
	}
}

public extension NSFileProviderDomain {
	convenience init(vaultUID: String, displayName: String) {
		self.init(identifier: NSFileProviderDomainIdentifier(vaultUID), displayName: displayName)
	}

	convenience init(identifier: NSFileProviderDomainIdentifier, displayName: String) {
		self.init(identifier: identifier, displayName: displayName, pathRelativeToDocumentStorage: identifier.rawValue)
	}

	/**
	 Creates a NSFileProviderDomain from a `NSFileProviderDomainIdentifier` where the `pathRelativeToDocumentStorage` equals to the raw value of the given `identifier` and an empty `displayName`.
	 */
	convenience init(identifier: NSFileProviderDomainIdentifier) {
		self.init(identifier: identifier, displayName: "")
	}
}

public struct DownloadedVaultConfig {
	public let vaultConfig: UnverifiedVaultConfig
	let token: Data
	let metadata: CloudItemMetadata
}

public struct DownloadedMasterkeyFile {
	let masterkeyFile: MasterkeyFile
	let metadata: CloudItemMetadata
	let masterkeyFileData: Data
}

struct PayloadMasterkey: Codable {
	let key: String
}
