//
//  VaultDBManager.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 30.10.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCryptoLib
import FileProvider
import Foundation
import Promises

public enum VaultManagerError: Error {
	case vaultAlreadyExists
	case vaultVersionNotSupported
	case fileProviderDomainNotFound
}

public protocol VaultManager {
	func createNewVault(withVaultUID vaultUID: String, delegateAccountUID: String, vaultPath: CloudPath, password: String, storePasswordInKeychain: Bool) -> Promise<Void>
	func manualUnlockVault(withUID vaultUID: String, kek: [UInt8]) throws -> CloudProvider
	func getDecorator(forVaultUID vaultUID: String) throws -> CloudProvider
	func createFromExisting(withVaultUID vaultUID: String, delegateAccountUID: String, vaultItem: VaultItem, password: String, storePasswordInKeychain: Bool) -> Promise<Void>
	func createLegacyFromExisting(withVaultUID vaultUID: String, delegateAccountUID: String, vaultItem: VaultItem, password: String, storePasswordInKeychain: Bool) -> Promise<Void>
	func removeVault(withUID vaultUID: String) throws -> Promise<Void>
	func removeAllUnusedFileProviderDomains() -> Promise<Void>
	func getVaultPath(from masterkeyPath: CloudPath) -> CloudPath
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

	// MARK: Create new vault

	/**
	 - Precondition: There is no VaultAccount for the `vaultUID` in the database yet
	 - Precondition: It exists a CloudProviderAccount with the `delegateAccountUID` in the database
	 - Postcondition: The root path was created in the cloud and the masterkey file was uploaded.
	 - Postcondition: The masterkey file and vault config token is cached under the corresponding `vaultUID`
	 - Postcondition: storePasswordInKeychain <=> the password for the masterkey is stored in the keychain.
	 - Postcondition: The passed `vaultUID`, `delegateAccountUID` and `vaultPath` are stored as VaultAccount in the database
	 - Postcondition: The created VaultDecorator is cached under the corresponding `vaultUID`.
	 */
	public func createNewVault(withVaultUID vaultUID: String, delegateAccountUID: String, vaultPath: CloudPath, password: String, storePasswordInKeychain: Bool) -> Promise<Void> {
		guard VaultDBManager.cachedDecorators[vaultUID] == nil else {
			return Promise(VaultManagerError.vaultAlreadyExists)
		}
		let tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true)
		let vaultConfig = VaultConfig.createNew(format: 8, cipherCombo: .sivCTRMAC, shorteningThreshold: 220)
		let masterkey: Masterkey
		let delegate: CloudProvider
		let vaultConfigToken: String
		do {
			try FileManager.default.createDirectory(at: tmpDirURL, withIntermediateDirectories: true)
			masterkey = try Masterkey.createNew()
			vaultConfigToken = try vaultConfig.toToken(keyId: "masterkeyfile:masterkey.cryptomator", rawKey: masterkey.rawKey)
			delegate = try providerManager.getProvider(with: delegateAccountUID)
		} catch {
			return Promise(error)
		}
		return delegate.createFolder(at: vaultPath).then { _ -> Promise<CloudItemMetadata> in
			try self.uploadMasterkey(masterkey, password: password, vaultPath: vaultPath, delegate: delegate, tmpDirURL: tmpDirURL)
		}.then { _ -> Promise<CloudItemMetadata> in
			try self.uploadVaultConfigToken(vaultConfigToken, vaultPath: vaultPath, delegate: delegate, tmpDirURL: tmpDirURL)
		}.then { _ -> Promise<Void> in
			try self.createVaultFolderStructure(masterkey: masterkey, vaultPath: vaultPath, delegate: delegate)
		}.then { _ -> Promise<Void> in
			let unverifiedVaultConfig = try UnverifiedVaultConfig(token: vaultConfigToken)
			let decorator = try VaultProviderFactory.createVaultProvider(from: unverifiedVaultConfig, masterkey: masterkey, vaultPath: vaultPath, with: delegate)
			VaultDBManager.cachedDecorators[vaultUID] = decorator
			return self.addFileProviderDomain(forVaultUID: vaultUID, displayName: vaultPath.lastPathComponent)
		}.then {
			let account = VaultAccount(vaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultPath: vaultPath, vaultName: vaultPath.lastPathComponent)
			try self.vaultAccountManager.saveNewAccount(account)
			try self.postProcessVaultCreation(for: masterkey, forVaultUID: vaultUID, vaultConfigToken: vaultConfigToken, password: password, storePasswordInKeychain: storePasswordInKeychain)
		}.catch { _ in
			VaultDBManager.cachedDecorators[vaultUID] = nil
		}
	}

	private func uploadMasterkey(_ masterkey: Masterkey, password: String, vaultPath: CloudPath, delegate: CloudProvider, tmpDirURL: URL) throws -> Promise<CloudItemMetadata> {
		let localMasterkeyURL = tmpDirURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
		let masterkeyData = try exportMasterkey(masterkey, vaultVersion: VaultDBManager.fakeVaultVersion, password: password)
		try masterkeyData.write(to: localMasterkeyURL)
		let masterkeyCloudPath = vaultPath.appendingPathComponent("masterkey.cryptomator")
		return delegate.uploadFile(from: localMasterkeyURL, to: masterkeyCloudPath, replaceExisting: false)
	}

	private func uploadVaultConfigToken(_ token: String, vaultPath: CloudPath, delegate: CloudProvider, tmpDirURL: URL) throws -> Promise<CloudItemMetadata> {
		let localVaultConfigURL = tmpDirURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
		try token.write(to: localVaultConfigURL, atomically: true, encoding: .utf8)
		let vaultConfigCloudPath = vaultPath.appendingPathComponent("vault.cryptomator")
		return delegate.uploadFile(from: localVaultConfigURL, to: vaultConfigCloudPath, replaceExisting: false)
	}

	private func createVaultFolderStructure(masterkey: Masterkey, vaultPath: CloudPath, delegate: CloudProvider) throws -> Promise<Void> {
		let cryptor = Cryptor(masterkey: masterkey)
		let rootDirPath = try VaultDBManager.getRootDirectoryPath(for: cryptor, vaultPath: vaultPath)
		let dPath = vaultPath.appendingPathComponent("d")
		return delegate.createFolder(at: dPath).then { _ -> Promise<Void> in
			let twoCharsPath = rootDirPath.deletingLastPathComponent()
			return delegate.createFolder(at: twoCharsPath)
		}.then {
			delegate.createFolder(at: rootDirPath)
		}
	}

	/**
	 Manually unlock a vault via KEK.

	  This method is used to unlock the vault with `vaultUID` if the user does not want to store his vault password in the keychain.
	  - Postcondition: The created VaultDecorator is cached under the corresponding `vaultUID`
	  */
	public func manualUnlockVault(withUID vaultUID: String, kek: [UInt8]) throws -> CloudProvider {
		let cachedVault = try vaultCache.getCachedVault(withVaultUID: vaultUID)
		let masterkeyFile = try MasterkeyFile.withContentFromData(data: cachedVault.masterkeyFileData)
		let masterkey = try masterkeyFile.unlock(kek: kek)
		return try createVaultDecorator(from: masterkey, vaultUID: vaultUID, vaultVersion: masterkeyFile.version, vaultConfigToken: cachedVault.vaultConfigToken)
	}

	func createVaultDecorator(from masterkey: Masterkey, vaultUID: String, vaultVersion: Int, vaultConfigToken: String?) throws -> CloudProvider {
		let vaultAccount = try vaultAccountManager.getAccount(with: vaultUID)
		let delegate = try providerManager.getProvider(with: vaultAccount.delegateAccountUID)
		if let vaultConfigToken = vaultConfigToken {
			let unverifiedVaultConfig = try UnverifiedVaultConfig(token: vaultConfigToken)
			return try createVaultDecorator(from: masterkey, unverifiedVaultConfig: unverifiedVaultConfig, delegate: delegate, vaultPath: vaultAccount.vaultPath, vaultUID: vaultUID)
		} else {
			return try createLegacyVaultDecorator(from: masterkey, delegate: delegate, vaultPath: vaultAccount.vaultPath, vaultUID: vaultUID, vaultVersion: vaultVersion)
		}
	}

	func createVaultDecorator(from masterkey: Masterkey, unverifiedVaultConfig: UnverifiedVaultConfig, delegate: CloudProvider, vaultPath: CloudPath, vaultUID: String) throws -> CloudProvider {
		let decorator = try VaultProviderFactory.createVaultProvider(from: unverifiedVaultConfig, masterkey: masterkey, vaultPath: vaultPath, with: delegate)
		VaultDBManager.cachedDecorators[vaultUID] = decorator
		return decorator
	}

	func createLegacyVaultDecorator(from masterkey: Masterkey, delegate: CloudProvider, vaultPath: CloudPath, vaultUID: String, vaultVersion: Int) throws -> CloudProvider {
		let decorator = try VaultProviderFactory.createLegacyVaultProvider(from: masterkey, vaultVersion: vaultVersion, vaultPath: vaultPath, with: delegate)
		VaultDBManager.cachedDecorators[vaultUID] = decorator
		return decorator
	}

	public func getDecorator(forVaultUID vaultUID: String) throws -> CloudProvider {
		if let cachedDecorator = VaultDBManager.cachedDecorators[vaultUID] {
			// MARK: Add here masterkey up to date check

			return cachedDecorator
		}
		let password = try passwordManager.getPassword(forVaultUID: vaultUID)
		let cachedVault = try vaultCache.getCachedVault(withVaultUID: vaultUID)
		let masterkeyFile = try MasterkeyFile.withContentFromData(data: cachedVault.masterkeyFileData)
		let masterkey = try masterkeyFile.unlock(passphrase: password)
		return try createVaultDecorator(from: masterkey, vaultUID: vaultUID, vaultVersion: masterkeyFile.version, vaultConfigToken: cachedVault.vaultConfigToken)
	}

	// MARK: Open Existing Vault

	/**
	 Imports an existing Vault.

	  - Precondition: There is no VaultAccount for the `vaultUID` in the database yet
	  - Precondition: It exists a CloudProviderAccount with the `delegateAccountUID` in the database
	  - Precondition: The masterkey file at `vaultItem.vaultPath.appendingPathComponent("masterkey.cryptomator")` does exist in the cloud
	  - Postcondition: The masterkey file and vault config token is cached under the corresponding `vaultUID`
	  - Postcondition: storePasswordInKeychain <=> the password for the masterkey is stored in the keychain.
	  - Postcondition: The passed `vaultUID`, `delegateAccountUID` and the `vaultPath` derived from `masterkeyPath` are stored as VaultAccount in the database
	  - Postcondition: The created VaultDecorator is cached under the corresponding `vaultUID`
	  */
	public func createFromExisting(withVaultUID vaultUID: String, delegateAccountUID: String, vaultItem: VaultItem, password: String, storePasswordInKeychain: Bool) -> Promise<Void> {
		let delegate: CloudProvider
		do {
			guard VaultDBManager.cachedDecorators[vaultUID] == nil else {
				throw VaultManagerError.vaultAlreadyExists
			}
			delegate = try providerManager.getProvider(with: delegateAccountUID)
		} catch {
			return Promise(error)
		}
		let tmpDirURL = FileManager.default.temporaryDirectory
		let localVaultConfigURL = tmpDirURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
		let localMasterkeyURL = tmpDirURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
		let vaultPath = vaultItem.vaultPath
		let vaultConfigPath = vaultPath.appendingPathComponent("vault.cryptomator")
		let masterkeyPath = vaultPath.appendingPathComponent("masterkey.cryptomator")
		return delegate.downloadFile(from: vaultConfigPath, to: localVaultConfigURL).then {
			delegate.downloadFile(from: masterkeyPath, to: localMasterkeyURL)
		}.then { _ -> Promise<(Masterkey, String, Void)> in
			let token = try String(contentsOf: localVaultConfigURL, encoding: .utf8)
			let unverifiedVaultConfig = try UnverifiedVaultConfig(token: token)
			let masterkeyFile = try MasterkeyFile.withContentFromURL(url: localMasterkeyURL)
			let masterkey = try masterkeyFile.unlock(passphrase: password)
			let vaultProvider = try VaultProviderFactory.createVaultProvider(from: unverifiedVaultConfig, masterkey: masterkey, vaultPath: vaultPath, with: delegate)
			VaultDBManager.cachedDecorators[vaultUID] = vaultProvider
			return all(Promise(masterkey), Promise(token), self.addFileProviderDomain(forVaultUID: vaultUID, displayName: vaultItem.name))
		}.then { masterkey, token, _ -> Void in
			let vaultAccount = VaultAccount(vaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultPath: vaultPath, vaultName: vaultItem.name)
			try self.vaultAccountManager.saveNewAccount(vaultAccount)
			try self.postProcessVaultCreation(for: masterkey, forVaultUID: vaultUID, vaultConfigToken: token, password: password, storePasswordInKeychain: storePasswordInKeychain)
		}.catch { _ in
			VaultDBManager.cachedDecorators[vaultUID] = nil
		}
	}

	/**
	 Imports an existing legacy Vault.

	 Supported legacy vault formats are 6 & 7

	  - Precondition: There is no VaultAccount for the `vaultUID` in the database yet
	  - Precondition: It exists a CloudProviderAccount with the `delegateAccountUID` in the database
	  - Precondition: The masterkey file at `vaultItem.vaultPath.appendingPathComponent("masterkey.cryptomator")` does exist in the cloud
	  - Postcondition: The masterkey file is cached under the corresponding `vaultUID`
	  - Postcondition: storePasswordInKeychain <=> the password for the masterkey is stored in the keychain.
	  - Postcondition: The passed `vaultUID`, `delegateAccountUID` and the `vaultPath` derived from `masterkeyPath` are stored as VaultAccount in the database
	  - Postcondition: The created VaultDecorator is cached under the corresponding `vaultUID`
	  */
	public func createLegacyFromExisting(withVaultUID vaultUID: String, delegateAccountUID: String, vaultItem: VaultItem, password: String, storePasswordInKeychain: Bool) -> Promise<Void> {
		do {
			guard VaultDBManager.cachedDecorators[vaultUID] == nil else {
				throw VaultManagerError.vaultAlreadyExists
			}
			let delegate = try providerManager.getProvider(with: delegateAccountUID)
			let tmpDirURL = FileManager.default.temporaryDirectory
			let localMasterkeyURL = tmpDirURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
			let vaultPath = vaultItem.vaultPath
			let masterkeyPath = vaultPath.appendingPathComponent("masterkey.cryptomator")
			return delegate.downloadFile(from: masterkeyPath, to: localMasterkeyURL).then { _ -> Promise<(Masterkey, MasterkeyFile, Void)> in
				let masterkeyFile = try MasterkeyFile.withContentFromURL(url: localMasterkeyURL)
				let masterkey = try masterkeyFile.unlock(passphrase: password)
				let vaultProvider = try self.createLegacyVaultDecorator(from: masterkey, delegate: delegate, vaultPath: vaultPath, vaultUID: vaultUID, vaultVersion: masterkeyFile.version)
				VaultDBManager.cachedDecorators[vaultUID] = vaultProvider
				return all(Promise(masterkey), Promise(masterkeyFile), self.addFileProviderDomain(forVaultUID: vaultUID, displayName: vaultItem.name))
			}.then { masterkey, masterkeyFile, _ -> Void in
				let vaultAccount = VaultAccount(vaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultPath: vaultPath, vaultName: vaultItem.name)
				try self.vaultAccountManager.saveNewAccount(vaultAccount)
				try self.postProcessLegacyVaultCreation(for: masterkey, forVaultUID: vaultUID, vaultVersion: masterkeyFile.version, password: password, storePasswordInKeychain: storePasswordInKeychain)
			}
		} catch {
			VaultDBManager.cachedDecorators[vaultUID] = nil
			return Promise(error)
		}
	}

	// MARK: Remove Vault locally

	/**
	 - Precondition: It exists a `VaultAccount` for the `vaultUID` in the database
	 - Precondition: It exists a `NSFileProviderDomain` with the `vaultUID` as `identifier`
	 - Postcondition: No `VaultAccount` exists for the `vaultUID` in the database
	 - Postcondition: No password is stored for this `vaultUID`
	 - Postcondition: No `VaultDecorator` is cached under the corresponding `vaultUID`
	 - Postcondition: The `NSFileProviderDomain` with the `vaultUID` as `identifier` was removed from the NSFileProvider
	 */
	public func removeVault(withUID vaultUID: String) throws -> Promise<Void> {
		try passwordManager.removePassword(forVaultUID: vaultUID)
		try vaultAccountManager.removeAccount(with: vaultUID)
		VaultDBManager.cachedDecorators[vaultUID] = nil
		return removeFileProviderDomain(withVaultUID: vaultUID)
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

	// MARK: Internal

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

	public func getVaultPath(from masterkeyPath: CloudPath) -> CloudPath {
		precondition(masterkeyPath.path.hasSuffix("masterkey.cryptomator"))
		return masterkeyPath.deletingLastPathComponent()
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
					reject(error)
					return
				}
				fulfill(domains)
			}
		}
	}

	static func remove(_ domain: NSFileProviderDomain) -> Promise<Void> {
		return Promise<Void> { fulfill, reject in
			NSFileProviderManager.remove(domain) { error in
				if let error = error {
					reject(error)
					return
				}
				fulfill(())
			}
		}
	}

	class func add(_ domain: NSFileProviderDomain) -> Promise<Void> {
		return Promise<Void> { fulfill, reject in
			NSFileProviderManager.add(domain) { error in
				if let error = error {
					reject(error)
				} else {
					fulfill(())
				}
			}
		}
	}
}
