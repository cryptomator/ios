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

public enum VaultManagerError: Error {
	case vaultAlreadyExists
	case vaultVersionNotSupported
	case fileProviderDomainNotFound
	case moveVaultInsideItself
	case missingVaultConfigToken
}

public protocol VaultManager: Sendable {
	func createNewVault(withVaultUID vaultUID: String, delegateAccountUID: String, vaultPath: CloudPath, password: String, storePasswordInKeychain: Bool) async throws
	func createFromExisting(withVaultUID vaultUID: String, delegateAccountUID: String, vaultItem: VaultItem, password: String, storePasswordInKeychain: Bool) async throws
	func createLegacyFromExisting(withVaultUID vaultUID: String, delegateAccountUID: String, vaultItem: VaultItem, password: String, storePasswordInKeychain: Bool) async throws
	func manualUnlockVault(withUID vaultUID: String, kek: [UInt8]) throws -> CloudProvider
	func createVaultProvider(withUID vaultUID: String, masterkey: Masterkey) throws -> CloudProvider
	@discardableResult func removeVault(withUID vaultUID: String) throws -> Task<Void, Never>
	func removeVaults(withUIDs vaultUIDs: [String]) async throws
	func removeAllUnusedFileProviderDomains() async throws
	func moveVault(account: VaultAccount, to targetVaultPath: CloudPath) async throws
	func changePassphrase(oldPassphrase: String, newPassphrase: String, forVaultUID vaultUID: String) async throws
	func addExistingHubVault(_ vault: ExistingHubVault) async throws
	func manualUnlockVault(withUID vaultUID: String, rawKey: [UInt8]) throws -> CloudProvider
}

/// @unchecked Sendable: all stored properties are immutable and Sendable; the class is only subclassed by test doubles
public class VaultDBManager: VaultManager, @unchecked Sendable {
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
	public func createNewVault(withVaultUID vaultUID: String, delegateAccountUID: String, vaultPath: CloudPath, password: String, storePasswordInKeychain: Bool) async throws {
		let tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true)
		let cipherCombo = CryptorScheme.sivGcm
		let vaultConfig = VaultConfig.createNew(format: 8, cipherCombo: cipherCombo, shorteningThreshold: 220)
		try FileManager.default.createDirectory(at: tmpDirURL, withIntermediateDirectories: true)
		let masterkey = try Masterkey.createNew()
		let vaultConfigToken = try vaultConfig.toToken(keyId: "masterkeyfile:masterkey.cryptomator", rawKey: masterkey.rawKey)
		let provider = try LocalizedCloudProviderDecorator(delegate: providerManager.getProvider(with: delegateAccountUID))
		let masterkeyFileData = try exportMasterkey(masterkey, vaultVersion: VaultDBManager.fakeVaultVersion, password: password)
		var cachedVault = CachedVault(vaultUID: vaultUID, masterkeyFileData: masterkeyFileData, vaultConfigToken: vaultConfigToken, lastUpToDateCheck: Date(), masterkeyFileLastModifiedDate: nil, vaultConfigLastModifiedDate: nil)
		let cryptor = Cryptor(masterkey: masterkey, scheme: cipherCombo)
		do {
			try await provider.createFolder(at: vaultPath)
			let masterkeyFileMetadata = try await uploadMasterkey(masterkey, password: password, vaultPath: vaultPath, provider: provider, tmpDirURL: tmpDirURL)
			cachedVault.masterkeyFileLastModifiedDate = masterkeyFileMetadata.lastModifiedDate
			let vaultConfigMetadata = try await uploadVaultConfigToken(vaultConfigToken, vaultPath: vaultPath, provider: provider, tmpDirURL: tmpDirURL)
			cachedVault.vaultConfigLastModifiedDate = vaultConfigMetadata.lastModifiedDate
			try await createVaultFolderStructure(cryptor: cryptor, vaultPath: vaultPath, provider: provider)
			try await uploadRootDirIdFile(cryptor: cryptor, vaultPath: vaultPath, provider: provider, tmpDirURL: tmpDirURL)
			let unverifiedVaultConfig = try UnverifiedVaultConfig(token: vaultConfigToken)
			_ = try VaultProviderFactory.createVaultProvider(from: unverifiedVaultConfig, masterkey: masterkey, vaultPath: vaultPath, with: provider.delegate)
			try await addFileProviderDomain(forVaultUID: vaultUID, displayName: vaultPath.lastPathComponent)
			let account = VaultAccount(vaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultPath: vaultPath, vaultName: vaultPath.lastPathComponent)
			try vaultAccountManager.saveNewAccount(account)
			try postProcessVaultCreation(cachedVault: cachedVault, password: password, storePasswordInKeychain: storePasswordInKeychain)
			DDLogInfo("Created new vault \"\(vaultPath.lastPathComponent)\" (\(vaultUID))")
		} catch {
			DDLogError("Creating new vault \"\(vaultPath.lastPathComponent)\" (\(vaultUID)) failed with error: \(error)")
			throw error
		}
	}

	private func uploadMasterkey(_ masterkey: Masterkey, password: String, vaultPath: CloudPath, provider: CloudProvider, tmpDirURL: URL) async throws -> CloudItemMetadata {
		let masterkeyData = try exportMasterkey(masterkey, vaultVersion: VaultDBManager.fakeVaultVersion, password: password)
		return try await uploadMasterkeyFileData(masterkeyData, vaultPath: vaultPath, replaceExisting: false, provider: provider, tmpDirURL: tmpDirURL)
	}

	private func uploadMasterkeyFileData(_ data: Data, vaultPath: CloudPath, replaceExisting: Bool, provider: CloudProvider, tmpDirURL: URL) async throws -> CloudItemMetadata {
		let localMasterkeyURL = tmpDirURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
		try data.write(to: localMasterkeyURL)
		defer {
			try? FileManager.default.removeItem(at: localMasterkeyURL)
		}
		let masterkeyCloudPath = vaultPath.appendingPathComponent("masterkey.cryptomator")
		return try await provider.uploadFile(from: localMasterkeyURL, to: masterkeyCloudPath, replaceExisting: replaceExisting)
	}

	private func uploadVaultConfigToken(_ token: Data, vaultPath: CloudPath, provider: CloudProvider, tmpDirURL: URL) async throws -> CloudItemMetadata {
		let localVaultConfigURL = tmpDirURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
		try token.write(to: localVaultConfigURL)
		defer {
			try? FileManager.default.removeItem(at: localVaultConfigURL)
		}
		let vaultConfigCloudPath = vaultPath.appendingPathComponent("vault.cryptomator")
		return try await provider.uploadFile(from: localVaultConfigURL, to: vaultConfigCloudPath, replaceExisting: false)
	}

	private func createVaultFolderStructure(cryptor: Cryptor, vaultPath: CloudPath, provider: CloudProvider) async throws {
		let rootDirPath = try VaultDBManager.getRootDirectoryPath(for: cryptor, vaultPath: vaultPath)
		let dPath = vaultPath.appendingPathComponent("d")
		try await provider.createFolder(at: dPath)
		let twoCharsPath = rootDirPath.deletingLastPathComponent()
		try await provider.createFolder(at: twoCharsPath)
		try await provider.createFolder(at: rootDirPath)
	}

	private func uploadRootDirIdFile(cryptor: Cryptor, vaultPath: CloudPath, provider: CloudProvider, tmpDirURL: URL) async throws {
		let cleartextDirIdFileURL = tmpDirURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
		try Data().write(to: cleartextDirIdFileURL)
		let ciphertextDirIdFileURL = tmpDirURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
		try await cryptor.encryptContent(from: cleartextDirIdFileURL, to: ciphertextDirIdFileURL, progress: nil)
		try? FileManager.default.removeItem(at: cleartextDirIdFileURL)

		let rootDirPath = try VaultDBManager.getRootDirectoryPath(for: cryptor, vaultPath: vaultPath)
		let ciphertextDirIdFileCloudPath = rootDirPath.appendingPathComponent("dirid.c9r")
		_ = try? await provider.uploadFile(from: ciphertextDirIdFileURL, to: ciphertextDirIdFileCloudPath, replaceExisting: false)
		try? FileManager.default.removeItem(at: ciphertextDirIdFileURL)
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
	public func createFromExisting(withVaultUID vaultUID: String, delegateAccountUID: String, vaultItem: VaultItem, password: String, storePasswordInKeychain: Bool) async throws {
		let provider = try LocalizedCloudProviderDecorator(delegate: providerManager.getProvider(with: delegateAccountUID))
		let tmpDirURL = FileManager.default.temporaryDirectory
		let localVaultConfigURL = tmpDirURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
		let localMasterkeyURL = tmpDirURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
		let vaultPath = vaultItem.vaultPath
		let vaultConfigPath = vaultPath.appendingPathComponent("vault.cryptomator")
		let masterkeyPath = vaultPath.appendingPathComponent("masterkey.cryptomator")
		do {
			let vaultConfigMetadata = try await provider.downloadFile(from: vaultConfigPath, to: localVaultConfigURL)
			let masterkeyFileMetadata = try await provider.downloadFile(from: masterkeyPath, to: localMasterkeyURL)
			let vaultConfigToken = try Data(contentsOf: localVaultConfigURL)
			let masterkeyFileData = try Data(contentsOf: localMasterkeyURL)
			let unverifiedVaultConfig = try UnverifiedVaultConfig(token: vaultConfigToken)
			let masterkeyFile = try MasterkeyFile.withContentFromURL(url: localMasterkeyURL)
			let masterkey = try masterkeyFile.unlock(passphrase: password)
			_ = try VaultProviderFactory.createVaultProvider(from: unverifiedVaultConfig, masterkey: masterkey, vaultPath: vaultPath, with: provider.delegate)
			let cachedVault = CachedVault(vaultUID: vaultUID, masterkeyFileData: masterkeyFileData, vaultConfigToken: vaultConfigToken, lastUpToDateCheck: Date(), masterkeyFileLastModifiedDate: masterkeyFileMetadata.lastModifiedDate, vaultConfigLastModifiedDate: vaultConfigMetadata.lastModifiedDate)
			try await addFileProviderDomain(forVaultUID: vaultUID, displayName: vaultItem.name)
			let vaultAccount = VaultAccount(vaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultPath: vaultPath, vaultName: vaultItem.name)
			try vaultAccountManager.saveNewAccount(vaultAccount)
			try postProcessVaultCreation(cachedVault: cachedVault, password: password, storePasswordInKeychain: storePasswordInKeychain)
			DDLogInfo("Opened existing vault \"\(vaultItem.name)\" (\(vaultUID))")
		} catch {
			DDLogError("Opening existing vault \"\(vaultItem.name)\" (\(vaultUID)) failed with error: \(error)")
			throw error
		}
	}

	// swiftlint:disable:next function_parameter_count
	public func createFromExisting(withVaultUID vaultUID: String, delegateAccountUID: String, downloadedVaultConfig: DownloadedVaultConfig, downloadedMasterkey: DownloadedMasterkeyFile, vaultItem: VaultItem, password: String) async throws {
		let provider = try LocalizedCloudProviderDecorator(delegate: providerManager.getProvider(with: delegateAccountUID))
		let vaultPath = vaultItem.vaultPath
		let vaultConfigMetadata = downloadedVaultConfig.metadata
		let vaultConfigToken = downloadedVaultConfig.token
		let masterkeyFile = downloadedMasterkey.masterkeyFile
		let masterkeyFileData = downloadedMasterkey.masterkeyFileData
		let masterkeyFileMetadata = downloadedMasterkey.metadata
		let masterkey = try masterkeyFile.unlock(passphrase: password)
		_ = try VaultProviderFactory.createVaultProvider(from: downloadedVaultConfig.vaultConfig, masterkey: masterkey, vaultPath: vaultPath, with: provider.delegate)
		let vaultConfigLastModifiedDate = vaultConfigMetadata.lastModifiedDate
		let masterkeyFileLastModifiedDate = masterkeyFileMetadata.lastModifiedDate
		let lastUpToDateCheck: Date = (vaultConfigLastModifiedDate ?? .distantPast) < (masterkeyFileLastModifiedDate ?? .distantPast) ? masterkeyFileLastModifiedDate! : vaultConfigLastModifiedDate ?? Date()
		let cachedVault = CachedVault(vaultUID: vaultUID, masterkeyFileData: masterkeyFileData, vaultConfigToken: vaultConfigToken, lastUpToDateCheck: lastUpToDateCheck, masterkeyFileLastModifiedDate: masterkeyFileMetadata.lastModifiedDate, vaultConfigLastModifiedDate: vaultConfigMetadata.lastModifiedDate)
		try await addFileProviderDomain(forVaultUID: vaultUID, displayName: vaultItem.name)
		let vaultAccount = VaultAccount(vaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultPath: vaultPath, vaultName: vaultItem.name)
		try vaultAccountManager.saveNewAccount(vaultAccount)
		try postProcessVaultCreation(cachedVault: cachedVault, password: password, storePasswordInKeychain: false)
		DDLogInfo("Opened existing vault \"\(vaultItem.name)\" (\(vaultUID))")
	}

	public func getUnverifiedVaultConfig(delegateAccountUID: String, vaultItem: VaultItem) async throws -> DownloadedVaultConfig {
		let provider = try LocalizedCloudProviderDecorator(delegate: providerManager.getProvider(with: delegateAccountUID))
		let tmpDirURL = FileManager.default.temporaryDirectory
		let localVaultConfigURL = tmpDirURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
		let vaultPath = vaultItem.vaultPath
		let vaultConfigPath = vaultPath.appendingPathComponent("vault.cryptomator")
		let vaultConfigMetadata = try await provider.downloadFile(from: vaultConfigPath, to: localVaultConfigURL)
		let vaultConfigToken = try Data(contentsOf: localVaultConfigURL)
		let unverifiedVaultConfig = try UnverifiedVaultConfig(token: vaultConfigToken)
		return DownloadedVaultConfig(vaultConfig: unverifiedVaultConfig, token: vaultConfigToken, metadata: vaultConfigMetadata)
	}

	public func downloadMasterkeyFile(delegateAccountUID: String, vaultItem: VaultItem) async throws -> DownloadedMasterkeyFile {
		let provider = try LocalizedCloudProviderDecorator(delegate: providerManager.getProvider(with: delegateAccountUID))
		let tmpDirURL = FileManager.default.temporaryDirectory
		let localMasterkeyURL = tmpDirURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
		let vaultPath = vaultItem.vaultPath
		let masterkeyPath = vaultPath.appendingPathComponent("masterkey.cryptomator")
		let masterkeyFileMetadata = try await provider.downloadFile(from: masterkeyPath, to: localMasterkeyURL)
		let masterkeyFileData = try Data(contentsOf: localMasterkeyURL)
		let masterkeyFile = try MasterkeyFile.withContentFromData(data: masterkeyFileData)
		return DownloadedMasterkeyFile(masterkeyFile: masterkeyFile, metadata: masterkeyFileMetadata, masterkeyFileData: masterkeyFileData)
	}

	public func addExistingHubVault(_ vault: ExistingHubVault) async throws {
		let delegateAccountUID = vault.delegateAccountUID
		let provider = try LocalizedCloudProviderDecorator(delegate: providerManager.getProvider(with: delegateAccountUID))
		let vaultItem = vault.vaultItem
		let downloadedVaultConfig = vault.downloadedVaultConfig
		let jweData = vault.jweData

		let vaultPath = vaultItem.vaultPath
		let vaultConfigMetadata = downloadedVaultConfig.metadata
		let vaultConfigToken = downloadedVaultConfig.token
		let jwe = try JWE(compactSerialization: jweData)
		let masterkey = try JWEHelper.decryptVaultKey(jwe: jwe, with: vault.privateKey)
		_ = try VaultProviderFactory.createVaultProvider(from: downloadedVaultConfig.vaultConfig, masterkey: masterkey, vaultPath: vaultPath, with: provider.delegate)
		let vaultUID = vault.vaultUID
		let cachedVault = CachedVault(vaultUID: vaultUID,
		                              masterkeyFileData: jweData,
		                              vaultConfigToken: vaultConfigToken,
		                              lastUpToDateCheck: Date(),
		                              masterkeyFileLastModifiedDate: nil,
		                              vaultConfigLastModifiedDate: vaultConfigMetadata.lastModifiedDate)
		try await addFileProviderDomain(forVaultUID: vaultUID, displayName: vaultItem.name)
		let vaultAccount = VaultAccount(vaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultPath: vaultPath, vaultName: vaultItem.name)
		try vaultAccountManager.saveNewAccount(vaultAccount)
		do {
			try postProcessVaultCreation(cachedVault: cachedVault, password: nil)
		} catch {
			try vaultAccountManager.removeAccount(with: vaultUID)
			Task {
				try? await removeFileProviderDomain(withVaultUID: vaultUID)
			}
			throw error
		}
		DDLogInfo("Opened existing vault \"\(vaultItem.name)\" (\(vaultUID))")
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
	public func createLegacyFromExisting(withVaultUID vaultUID: String, delegateAccountUID: String, vaultItem: VaultItem, password: String, storePasswordInKeychain: Bool) async throws {
		let provider = try LocalizedCloudProviderDecorator(delegate: providerManager.getProvider(with: delegateAccountUID))
		let tmpDirURL = FileManager.default.temporaryDirectory
		let localMasterkeyURL = tmpDirURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
		let vaultPath = vaultItem.vaultPath
		let masterkeyPath = vaultPath.appendingPathComponent("masterkey.cryptomator")
		do {
			let masterkeyFileMetadata = try await provider.downloadFile(from: masterkeyPath, to: localMasterkeyURL)
			let masterkeyFileData = try Data(contentsOf: localMasterkeyURL)
			let masterkeyFile = try MasterkeyFile.withContentFromData(data: masterkeyFileData)
			let masterkey = try masterkeyFile.unlock(passphrase: password)
			_ = try VaultProviderFactory.createLegacyVaultProvider(from: masterkey, vaultVersion: masterkeyFile.version, vaultPath: vaultPath, with: provider.delegate)
			let cachedVault = CachedVault(vaultUID: vaultUID, masterkeyFileData: masterkeyFileData, vaultConfigToken: nil, lastUpToDateCheck: Date(), masterkeyFileLastModifiedDate: masterkeyFileMetadata.lastModifiedDate, vaultConfigLastModifiedDate: nil)
			try await addFileProviderDomain(forVaultUID: vaultUID, displayName: vaultItem.name)
			let vaultAccount = VaultAccount(vaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultPath: vaultPath, vaultName: vaultItem.name)
			try vaultAccountManager.saveNewAccount(vaultAccount)
			try postProcessVaultCreation(cachedVault: cachedVault, password: password, storePasswordInKeychain: storePasswordInKeychain)
			DDLogInfo("Opened existing legacy vault \"\(vaultItem.name)\" (\(vaultUID))")
		} catch {
			DDLogError("Opening existing legacy vault \"\(vaultItem.name)\" (\(vaultUID)) failed with error: \(error)")
			throw error
		}
	}

	// MARK: - Remove Vault Locally

	/**
	 - Precondition: A `VaultAccount` for the `vaultUID` exists in the database.
	 - Precondition: A `NSFileProviderDomain` with the `vaultUID` as `identifier` exists.
	 - Postcondition: The `VaultAccount` for the `vaultUID` was removed in the database.
	 - Postcondition: The password for the `vaultUID` was removed.
	 - Postcondition: There is no longer a masterkey cached in the keychain for the `vaultUID`.
	 - Postcondition: The returned task removes the `NSFileProviderDomain` with the `vaultUID` as `identifier` from the `NSFileProvider`.
	 */
	@discardableResult
	public func removeVault(withUID vaultUID: String) throws -> Task<Void, Never> {
		do {
			try passwordManager.removePassword(forVaultUID: vaultUID)
			try vaultAccountManager.removeAccount(with: vaultUID)
			try masterkeyCacheManager.removeCachedMasterkey(forVaultUID: vaultUID)
		} catch {
			DDLogError("Removing vault \(vaultUID) failed with error: \(error)")
			throw error
		}
		return Task {
			do {
				try await removeFileProviderDomain(withVaultUID: vaultUID)
				DDLogInfo("Removed vault \(vaultUID)")
			} catch {
				DDLogError("Removing vault \(vaultUID) failed with error: \(error)")
			}
		}
	}

	/**
	 Removes multiple vaults at once, handling database operations in a single transaction to avoid constraint violations.
	 - Precondition: `VaultAccount`s for the `vaultUIDs` exist in the database.
	 - Postcondition: All specified vaults are removed from the database, keychain, and FileProvider.
	 */
	@concurrent
	public func removeVaults(withUIDs vaultUIDs: [String]) async throws {
		guard !vaultUIDs.isEmpty else {
			return
		}
		do {
			// Remove passwords and cached masterkeys for all vaults
			for vaultUID in vaultUIDs {
				do {
					try passwordManager.removePassword(forVaultUID: vaultUID)
					try masterkeyCacheManager.removeCachedMasterkey(forVaultUID: vaultUID)
				} catch {
					DDLogError("Failed to remove password/masterkey for vault \(vaultUID): \(error)")
				}
			}

			// Remove all FileProvider domains
			for vaultUID in vaultUIDs {
				do {
					try await removeFileProviderDomain(withVaultUID: vaultUID)
				} catch {
					DDLogError("Failed to remove FileProvider domain for vault \(vaultUID): \(error)")
				}
			}

			// Remove all vault accounts in a single transaction
			try vaultAccountManager.removeAccounts(with: vaultUIDs)
			DDLogInfo("Removed \(vaultUIDs.count) vaults")
		} catch {
			DDLogError("Removing vaults failed with error: \(error)")
			throw error
		}
	}

	/**
	 Removes all unused FileProvider domains.

	 An unused FileProviderDomain is a domain that has no associated vault in the database.
	 An unused domain can be caused, for example, when the user reinstalls the app.
	 */
	public func removeAllUnusedFileProviderDomains() async throws {
		let vaults = try vaultAccountManager.getAllAccounts()
		let vaultUIDs = vaults.map { $0.vaultUID }
		let domains = try await NSFileProviderManager.domains()
		let unusedDomains = domains.filter { !vaultUIDs.contains($0.identifier.rawValue) }
		await removeUnusedDomainsFromFileProvider(unusedDomains)
	}

	@concurrent
	private func removeUnusedDomainsFromFileProvider(_ domains: [NSFileProviderDomain]) async {
		for domain in domains {
			do {
				try await removeFileProviderDomain(domain)
				DDLogInfo("Successfully removed the unused FileProvider domain: \(domain)")
			} catch {
				DDLogError("Remove unused FileProvider domain: \(domain) failed with error: \(error)")
			}
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
		// it's important to use the vaultUID as background URLSession identifier to avoid identifier collisions
		let provider = try providerManager.getBackgroundSessionProvider(with: vaultAccount.delegateAccountUID, sessionIdentifier: vaultUID)
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

	public func moveVault(account: VaultAccount, to targetVaultPath: CloudPath) async throws {
		guard !targetVaultPath.contains(account.vaultPath) else {
			throw VaultManagerError.moveVaultInsideItself
		}
		let provider = try LocalizedCloudProviderDecorator(delegate: providerManager.getProvider(with: account.delegateAccountUID))
		try await provider.moveFolder(from: account.vaultPath, to: targetVaultPath)
		let updatedVaultAccount = VaultAccount(vaultUID: account.vaultUID,
		                                       delegateAccountUID: account.delegateAccountUID,
		                                       vaultPath: targetVaultPath,
		                                       vaultName: targetVaultPath.lastPathComponent)
		try vaultAccountManager.updateAccount(updatedVaultAccount)
		try await addFileProviderDomain(forVaultUID: updatedVaultAccount.vaultUID, displayName: updatedVaultAccount.vaultName)
	}

	// MARK: - Change Passphrase

	public func changePassphrase(oldPassphrase: String, newPassphrase: String, forVaultUID vaultUID: String) async throws {
		let tmpDirURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		let cachedVault = try vaultCache.getCachedVault(withVaultUID: vaultUID)
		let masterkeyFileData = try changePassphrase(masterkeyFileData: cachedVault.masterkeyFileData, oldPassphrase: oldPassphrase, newPassphrase: newPassphrase)
		let vaultAccount = try vaultAccountManager.getAccount(with: vaultUID)
		try FileManager.default.createDirectory(at: tmpDirURL, withIntermediateDirectories: true)
		let provider = try LocalizedCloudProviderDecorator(delegate: providerManager.getProvider(with: vaultAccount.delegateAccountUID))
		let metadata = try await uploadMasterkeyFileData(masterkeyFileData, vaultPath: vaultAccount.vaultPath, replaceExisting: true, provider: provider, tmpDirURL: tmpDirURL)
		try postProcessChangePassphrase(masterkeyFileData: masterkeyFileData, masterkeyFileDataLastModifiedDate: metadata.lastModifiedDate, forVaultUID: vaultUID, newPassphrase: newPassphrase)
	}

	public func recoverMissingFileProviderDomains() async throws {
		let vaults = try vaultAccountManager.getAllAccounts()
		let domains = try await NSFileProviderManager.domains()
		let domainIdentifiers = domains.map { $0.identifier.rawValue }
		let vaultsWithMissingDomains = vaults.filter { !domainIdentifiers.contains($0.vaultUID) }
		await recoverFileProviderDomains(for: vaultsWithMissingDomains)
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

	func removeFileProviderDomain(withVaultUID vaultUID: String) async throws {
		let domainForVault = try await getFileProviderDomain(forVaultUID: vaultUID)
		try await removeFileProviderDomain(domainForVault)
	}

	private func removeFileProviderDomain(_ domain: NSFileProviderDomain) async throws {
		try await NSFileProviderManager.remove(domain)
		let documentStorageURL = NSFileProviderManager.default.documentStorageURL
		let domainDocumentStorageURL = documentStorageURL.appendingPathComponent(domain.pathRelativeToDocumentStorage)
		try FileManager.default.removeItem(at: domainDocumentStorageURL)
	}

	private func getFileProviderDomain(forVaultUID vaultUID: String) async throws -> NSFileProviderDomain {
		let domains = try await NSFileProviderManager.domains()
		guard let domainForVault = domains.first(where: { $0.identifier.rawValue == vaultUID }) else {
			throw VaultManagerError.fileProviderDomainNotFound
		}
		return domainForVault
	}

	func addFileProviderDomain(forVaultUID vaultUID: String, displayName: String) async throws {
		let domain = NSFileProviderDomain(vaultUID: vaultUID, displayName: displayName)
		try await NSFileProviderManager.add(domain)
	}

	@concurrent
	private func recoverFileProviderDomains(for vaults: [VaultAccount]) async {
		for vault in vaults {
			do {
				try await addFileProviderDomain(forVaultUID: vault.vaultUID, displayName: vault.vaultName)
				DDLogInfo("Successfully recovered FileProvider domain for vault: \(vault.vaultName) - \(vault.vaultUID)")
			} catch {
				DDLogError("Recover FileProvider domain for vault: \(vault.vaultName) - \(vault.vaultUID) failed with error: \(error)")
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
