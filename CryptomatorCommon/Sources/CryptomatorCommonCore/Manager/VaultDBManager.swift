//
//  VaultDBManager.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 30.10.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCloudAccessCore
import CryptomatorCryptoLib
import FileProvider
import Foundation
import os.log
import Promises

public enum VaultManagerError: Error {
	case vaultAlreadyExists
	case vaultVersionNotSupported
	case fileProviderDomainNotFound
}

public protocol VaultManager {
	func createNewVault(withVaultUID vaultUID: String, delegateAccountUID: String, vaultPath: CloudPath, password: String, storePasswordInKeychain: Bool) -> Promise<Void>
	func createFromExisting(withVaultUID vaultUID: String, delegateAccountUID: String, vaultItem: VaultItem, password: String, storePasswordInKeychain: Bool) -> Promise<Void>
	func createLegacyFromExisting(withVaultUID vaultUID: String, delegateAccountUID: String, vaultItem: VaultItem, password: String, storePasswordInKeychain: Bool) -> Promise<Void>
	func manualUnlockVault(withUID vaultUID: String, kek: [UInt8]) throws -> CloudProvider
	func removeVault(withUID vaultUID: String) throws -> Promise<Void>
	func removeAllUnusedFileProviderDomains() -> Promise<Void>
}

public class VaultDBManager: VaultManager {
	public static let shared = VaultDBManager(providerManager: CloudProviderDBManager.shared, vaultAccountManager: VaultAccountDBManager.shared, vaultCache: VaultDBCache(dbWriter: CryptomatorDatabase.shared.dbPool), passwordManager: VaultPasswordKeychainManager())
	static var cachedDecorators = [String: CloudProvider]()
	let providerManager: CloudProviderDBManager
	let vaultAccountManager: VaultAccountManager
	private static let fakeVaultVersion = 999
	private let vaultCache: VaultCache
	private let passwordManager: VaultPasswordManager

	init(providerManager: CloudProviderDBManager, vaultAccountManager: VaultAccountManager, vaultCache: VaultCache, passwordManager: VaultPasswordManager) {
		self.providerManager = providerManager
		self.vaultAccountManager = vaultAccountManager
		self.vaultCache = vaultCache
		self.passwordManager = passwordManager
	}

	// MARK: - Create New Vault

	/**
	 - Precondition: There is no `VaultAccount` for the `vaultUID` in the database yet.
	 - Precondition: A `CloudProviderAccount` with the `delegateAccountUID` exists in the database.
	 - Postcondition: The root path was created in the cloud and the masterkey file was uploaded.
	 - Postcondition: The masterkey file and vault config token are cached under the corresponding `vaultUID`.
	 - Postcondition: `storePasswordInKeychain` <=> the password for the masterkey is stored in the keychain.
	 - Postcondition: The passed `vaultUID`, `delegateAccountUID`, and `vaultPath` are stored as `VaultAccount` in the database.
	 - Postcondition: The created vault decorator is cached under the corresponding `vaultUID`.
	 */
	public func createNewVault(withVaultUID vaultUID: String, delegateAccountUID: String, vaultPath: CloudPath, password: String, storePasswordInKeychain: Bool) -> Promise<Void> {
		guard VaultDBManager.cachedDecorators[vaultUID] == nil else {
			return Promise(VaultManagerError.vaultAlreadyExists)
		}
		let tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true)
		let vaultConfig = VaultConfig.createNew(format: 8, cipherCombo: .sivCTRMAC, shorteningThreshold: 220)
		let masterkey: Masterkey
		let provider: LocalizedCloudProviderDecorator
		let vaultConfigToken: String
		do {
			try FileManager.default.createDirectory(at: tmpDirURL, withIntermediateDirectories: true)
			masterkey = try Masterkey.createNew()
			vaultConfigToken = try vaultConfig.toToken(keyId: "masterkeyfile:masterkey.cryptomator", rawKey: masterkey.rawKey)
			provider = LocalizedCloudProviderDecorator(delegate: try providerManager.getProvider(with: delegateAccountUID))
		} catch {
			return Promise(error)
		}
		return provider.createFolder(at: vaultPath).then { _ -> Promise<CloudItemMetadata> in
			try self.uploadMasterkey(masterkey, password: password, vaultPath: vaultPath, provider: provider, tmpDirURL: tmpDirURL)
		}.then { _ -> Promise<CloudItemMetadata> in
			try self.uploadVaultConfigToken(vaultConfigToken, vaultPath: vaultPath, provider: provider, tmpDirURL: tmpDirURL)
		}.then { _ -> Promise<Void> in
			try self.createVaultFolderStructure(masterkey: masterkey, vaultPath: vaultPath, provider: provider)
		}.then { _ -> Promise<Void> in
			let unverifiedVaultConfig = try UnverifiedVaultConfig(token: vaultConfigToken)
			let decorator = try VaultProviderFactory.createVaultProvider(from: unverifiedVaultConfig, masterkey: masterkey, vaultPath: vaultPath, with: provider.delegate)
			VaultDBManager.cachedDecorators[vaultUID] = decorator
			return self.addFileProviderDomain(forVaultUID: vaultUID, displayName: vaultPath.lastPathComponent)
		}.then {
			let account = VaultAccount(vaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultPath: vaultPath, vaultName: vaultPath.lastPathComponent)
			try self.vaultAccountManager.saveNewAccount(account)
			try self.postProcessVaultCreation(for: masterkey, forVaultUID: vaultUID, vaultConfigToken: vaultConfigToken, password: password, storePasswordInKeychain: storePasswordInKeychain)
			DDLogInfo("Created new vault \"\(vaultPath.lastPathComponent)\" (\(vaultUID))")
		}.catch { error in
			DDLogError("Creating new vault \"\(vaultPath.lastPathComponent)\" (\(vaultUID)) failed with error: \(error)")
			VaultDBManager.cachedDecorators[vaultUID] = nil
		}
	}

	private func uploadMasterkey(_ masterkey: Masterkey, password: String, vaultPath: CloudPath, provider: CloudProvider, tmpDirURL: URL) throws -> Promise<CloudItemMetadata> {
		let localMasterkeyURL = tmpDirURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
		let masterkeyData = try exportMasterkey(masterkey, vaultVersion: VaultDBManager.fakeVaultVersion, password: password)
		try masterkeyData.write(to: localMasterkeyURL)
		let masterkeyCloudPath = vaultPath.appendingPathComponent("masterkey.cryptomator")
		return provider.uploadFile(from: localMasterkeyURL, to: masterkeyCloudPath, replaceExisting: false)
	}

	private func uploadVaultConfigToken(_ token: String, vaultPath: CloudPath, provider: CloudProvider, tmpDirURL: URL) throws -> Promise<CloudItemMetadata> {
		let localVaultConfigURL = tmpDirURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
		try token.write(to: localVaultConfigURL, atomically: true, encoding: .utf8)
		let vaultConfigCloudPath = vaultPath.appendingPathComponent("vault.cryptomator")
		return provider.uploadFile(from: localVaultConfigURL, to: vaultConfigCloudPath, replaceExisting: false)
	}

	private func createVaultFolderStructure(masterkey: Masterkey, vaultPath: CloudPath, provider: CloudProvider) throws -> Promise<Void> {
		let cryptor = Cryptor(masterkey: masterkey)
		let rootDirPath = try VaultDBManager.getRootDirectoryPath(for: cryptor, vaultPath: vaultPath)
		let dPath = vaultPath.appendingPathComponent("d")
		return provider.createFolder(at: dPath).then { _ -> Promise<Void> in
			let twoCharsPath = rootDirPath.deletingLastPathComponent()
			return provider.createFolder(at: twoCharsPath)
		}.then {
			provider.createFolder(at: rootDirPath)
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
	 - Postcondition: The created vault decorator is cached under the corresponding `vaultUID`.
	 */
	public func createFromExisting(withVaultUID vaultUID: String, delegateAccountUID: String, vaultItem: VaultItem, password: String, storePasswordInKeychain: Bool) -> Promise<Void> {
		let provider: LocalizedCloudProviderDecorator
		do {
			guard VaultDBManager.cachedDecorators[vaultUID] == nil else {
				throw VaultManagerError.vaultAlreadyExists
			}
			provider = LocalizedCloudProviderDecorator(delegate: try providerManager.getProvider(with: delegateAccountUID))
		} catch {
			return Promise(error)
		}
		let tmpDirURL = FileManager.default.temporaryDirectory
		let localVaultConfigURL = tmpDirURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
		let localMasterkeyURL = tmpDirURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
		let vaultPath = vaultItem.vaultPath
		let vaultConfigPath = vaultPath.appendingPathComponent("vault.cryptomator")
		let masterkeyPath = vaultPath.appendingPathComponent("masterkey.cryptomator")
		return provider.downloadFile(from: vaultConfigPath, to: localVaultConfigURL).then {
			provider.downloadFile(from: masterkeyPath, to: localMasterkeyURL)
		}.then { _ -> Promise<(Masterkey, String, Void)> in
			let token = try String(contentsOf: localVaultConfigURL, encoding: .utf8)
			let unverifiedVaultConfig = try UnverifiedVaultConfig(token: token)
			let masterkeyFile = try MasterkeyFile.withContentFromURL(url: localMasterkeyURL)
			let masterkey = try masterkeyFile.unlock(passphrase: password)
			let decorator = try VaultProviderFactory.createVaultProvider(from: unverifiedVaultConfig, masterkey: masterkey, vaultPath: vaultPath, with: provider.delegate)
			VaultDBManager.cachedDecorators[vaultUID] = decorator
			return all(Promise(masterkey), Promise(token), self.addFileProviderDomain(forVaultUID: vaultUID, displayName: vaultItem.name))
		}.then { masterkey, token, _ -> Void in
			let vaultAccount = VaultAccount(vaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultPath: vaultPath, vaultName: vaultItem.name)
			try self.vaultAccountManager.saveNewAccount(vaultAccount)
			try self.postProcessVaultCreation(for: masterkey, forVaultUID: vaultUID, vaultConfigToken: token, password: password, storePasswordInKeychain: storePasswordInKeychain)
			DDLogInfo("Opened existing vault \"\(vaultItem.name)\" (\(vaultUID))")
		}.catch { error in
			DDLogError("Opening existing vault \"\(vaultItem.name)\" (\(vaultUID)) failed with error: \(error)")
			VaultDBManager.cachedDecorators[vaultUID] = nil
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
	 - Postcondition: The created vault decorator is cached under the corresponding `vaultUID`.
	 */
	public func createLegacyFromExisting(withVaultUID vaultUID: String, delegateAccountUID: String, vaultItem: VaultItem, password: String, storePasswordInKeychain: Bool) -> Promise<Void> {
		let provider: LocalizedCloudProviderDecorator
		do {
			guard VaultDBManager.cachedDecorators[vaultUID] == nil else {
				throw VaultManagerError.vaultAlreadyExists
			}
			provider = LocalizedCloudProviderDecorator(delegate: try providerManager.getProvider(with: delegateAccountUID))
		} catch {
			return Promise(error)
		}
		let tmpDirURL = FileManager.default.temporaryDirectory
		let localMasterkeyURL = tmpDirURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
		let vaultPath = vaultItem.vaultPath
		let masterkeyPath = vaultPath.appendingPathComponent("masterkey.cryptomator")
		return provider.downloadFile(from: masterkeyPath, to: localMasterkeyURL).then { _ -> Promise<(Masterkey, MasterkeyFile, Void)> in
			let masterkeyFile = try MasterkeyFile.withContentFromURL(url: localMasterkeyURL)
			let masterkey = try masterkeyFile.unlock(passphrase: password)
			let decorator = try VaultProviderFactory.createLegacyVaultProvider(from: masterkey, vaultVersion: masterkeyFile.version, vaultPath: vaultPath, with: provider.delegate)
			VaultDBManager.cachedDecorators[vaultUID] = decorator
			return all(Promise(masterkey), Promise(masterkeyFile), self.addFileProviderDomain(forVaultUID: vaultUID, displayName: vaultItem.name))
		}.then { masterkey, masterkeyFile, _ -> Void in
			let vaultAccount = VaultAccount(vaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultPath: vaultPath, vaultName: vaultItem.name)
			try self.vaultAccountManager.saveNewAccount(vaultAccount)
			try self.postProcessLegacyVaultCreation(for: masterkey, forVaultUID: vaultUID, vaultVersion: masterkeyFile.version, password: password, storePasswordInKeychain: storePasswordInKeychain)
			DDLogInfo("Opened existing legacy vault \"\(vaultItem.name)\" (\(vaultUID))")
		}.catch { error in
			DDLogError("Opening existing legacy vault \"\(vaultItem.name)\" (\(vaultUID)) failed with error: \(error)")
			VaultDBManager.cachedDecorators[vaultUID] = nil
		}
	}

	// MARK: - Remove Vault Locally

	/**
	 - Precondition: A `VaultAccount` for the `vaultUID` exists in the database.
	 - Precondition: A `NSFileProviderDomain` with the `vaultUID` as `identifier` exists.
	 - Postcondition: The `VaultAccount` for the `vaultUID` was removed in the database.
	 - Postcondition: The password for the `vaultUID` was removed.
	 - Postcondition: The vault decorator under the corresponding `vaultUID` was removed from cache.
	 - Postcondition: The `NSFileProviderDomain` with the `vaultUID` as `identifier` was removed from the `NSFileProvider`.
	 */
	public func removeVault(withUID vaultUID: String) throws -> Promise<Void> {
		do {
			try passwordManager.removePassword(forVaultUID: vaultUID)
			try vaultAccountManager.removeAccount(with: vaultUID)
			VaultDBManager.cachedDecorators[vaultUID] = nil
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
			return self.removeDomainsFromFileProvider(unusedDomains)
		}.then { _ in
			DDLogInfo("Removed all unused FileProviderDomains")
		}.catch { error in
			DDLogError("Removing all unused FileProviderDomains failed with error: \(error)")
		}
	}

	func removeDomainsFromFileProvider(_ domains: [NSFileProviderDomain]) -> Promise<Void> {
		return Promise(on: .global()) { fulfill, _ in
			for domain in domains {
				try awaitPromise(self.removeFileProviderDomain(domain))
			}
			fulfill(())
		}
	}

	// MARK: - Manual Unlock Vault

	/**
	 Manually unlock a vault via KEK.

	 This method is used to unlock the vault with `vaultUID` if the user does not want to store his vault password in the keychain.

	 - Postcondition: The created vault decorator is cached under the corresponding `vaultUID`.
	 */
	public func manualUnlockVault(withUID vaultUID: String, kek: [UInt8]) throws -> CloudProvider {
		let cachedVault = try vaultCache.getCachedVault(withVaultUID: vaultUID)
		let masterkeyFile = try MasterkeyFile.withContentFromData(data: cachedVault.masterkeyFileData)
		let masterkey = try masterkeyFile.unlock(kek: kek)
		let vaultAccount = try vaultAccountManager.getAccount(with: vaultUID)
		let provider = try providerManager.getProvider(with: vaultAccount.delegateAccountUID)
		let decorator: CloudProvider
		if let vaultConfigToken = cachedVault.vaultConfigToken {
			let unverifiedVaultConfig = try UnverifiedVaultConfig(token: vaultConfigToken)
			decorator = try VaultProviderFactory.createVaultProvider(from: unverifiedVaultConfig, masterkey: masterkey, vaultPath: vaultAccount.vaultPath, with: provider)
		} else {
			decorator = try VaultProviderFactory.createLegacyVaultProvider(from: masterkey, vaultVersion: masterkeyFile.version, vaultPath: vaultAccount.vaultPath, with: provider)
		}
		VaultDBManager.cachedDecorators[vaultUID] = decorator
		return decorator
	}

	// MARK: - Internal

	func postProcessVaultCreation(for masterkey: Masterkey, forVaultUID vaultUID: String, vaultConfigToken: String, password: String, storePasswordInKeychain: Bool) throws {
		let masterkeyFileData = try exportMasterkey(masterkey, vaultVersion: VaultDBManager.fakeVaultVersion, password: password)
		let cachedVault = CachedVault(vaultUID: vaultUID, masterkeyFileData: masterkeyFileData, vaultConfigToken: vaultConfigToken, lastUpToDateCheck: Date())
		try postProcessVaultCreation(cachedVault: cachedVault, password: password, storePasswordInKeychain: storePasswordInKeychain)
	}

	func postProcessLegacyVaultCreation(for masterkey: Masterkey, forVaultUID vaultUID: String, vaultVersion: Int, password: String, storePasswordInKeychain: Bool) throws {
		let masterkeyFileData = try exportMasterkey(masterkey, vaultVersion: vaultVersion, password: password)
		let cachedVault = CachedVault(vaultUID: vaultUID, masterkeyFileData: masterkeyFileData, vaultConfigToken: nil, lastUpToDateCheck: Date())
		try postProcessVaultCreation(cachedVault: cachedVault, password: password, storePasswordInKeychain: storePasswordInKeychain)
	}

	func postProcessVaultCreation(cachedVault: CachedVault, password: String, storePasswordInKeychain: Bool) throws {
		try vaultCache.cache(cachedVault)
		if storePasswordInKeychain {
			try passwordManager.setPassword(password, forVaultUID: cachedVault.vaultUID)
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
		let identifier = NSFileProviderDomainIdentifier(vaultUID)
		let domain = NSFileProviderDomain(identifier: identifier, displayName: displayName, pathRelativeToDocumentStorage: vaultUID)
		return NSFileProviderManager.add(domain)
	}
}

extension NSFileProviderManager {
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
