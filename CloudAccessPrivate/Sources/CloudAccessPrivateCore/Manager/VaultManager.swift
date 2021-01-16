//
//  VaultManager.swift
//  CloudAccessPrivateCore
//
//  Created by Philipp Schmid on 30.10.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import CryptomatorCryptoLib
import FileProvider
import Foundation
import Promises
public enum VaultManagerError: Error {
	case vaultAlreadyExists
	case vaultNotFound
	case vaultVersionNotSupported
	case passwordNotInKeychain
	case fileProviderDomainNotFound
}

struct VaultKeychainEntry: Codable {
	let masterkeyData: Data
	let password: String?
}

public class VaultManager {
	static let scryptCostParamForFileProvider = 2 // MARK: Change CostParam!

	public static let shared = VaultManager(providerManager: CloudProviderManager.shared, vaultAccountManager: VaultAccountManager.shared)
	static let updateCheckInterval: TimeInterval = 3600
	static var cachedDecorators = [String: CloudProvider]()
	let providerManager: CloudProviderManager
	let vaultAccountManager: VaultAccountManager

	init(providerManager: CloudProviderManager, vaultAccountManager: VaultAccountManager) {
		self.providerManager = providerManager
		self.vaultAccountManager = vaultAccountManager
	}

	/**
	 - Precondition: There is no VaultAccount for the `vaultUID` in the database yet
	 - Precondition: It exists a CloudProviderAccount with the `delegateAccountUID` in the database
	 - Postcondition: The root path was created in the cloud and the masterkey file was uploaded.
	 - Postcondition: The masterkey is stored in the keychain with a ScryptCostParameter, which allows the usage in the FileProviderExtension (15mb Memory Limit). Additionally: storePasswordInKeychain <=> the password for the masterkey is also stored in the keychain.
	 - Postcondition: The passed `vaultUID`, `delegateAccountUID` and `vaultPath` are stored as VaultAccount in the database
	 - Postcondition: The created VaultDecorator is cached under the corresponding `vaultUID`.
	 */
	public func createNewVault(withVaultID vaultUID: String, delegateAccountUID: String, vaultPath: CloudPath, password: String, storePasswordInKeychain: Bool) -> Promise<Void> {
		do {
			guard VaultManager.cachedDecorators[vaultUID] == nil else {
				throw VaultManagerError.vaultAlreadyExists
			}
			let vaultVersion = 7
			let masterkey = try Masterkey.createNew()
			let cryptor = Cryptor(masterkey: masterkey)
			let delegate = try providerManager.getProvider(with: delegateAccountUID)
			let decorator = try VaultFormat7ProviderDecorator(delegate: delegate, vaultPath: vaultPath, cryptor: cryptor)
			let rootDirPath = try VaultManager.getRootDirectoryPath(for: cryptor, vaultPath: vaultPath)
			return delegate.createFolder(at: vaultPath).then { _ -> Promise<CloudItemMetadata> in
				let tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true)
				try FileManager.default.createDirectory(at: tmpDirURL, withIntermediateDirectories: true)
				let localMasterkeyURL = tmpDirURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
				let masterkeyData = try self.exportMasterkey(masterkey, vaultVersion: vaultVersion, password: password)
				try masterkeyData.write(to: localMasterkeyURL)
				let masterkeyCloudPath = vaultPath.appendingPathComponent("masterkey.cryptomator")
				return delegate.uploadFile(from: localMasterkeyURL, to: masterkeyCloudPath, replaceExisting: false)
			}.then { _ -> Promise<Void> in
				let dPath = vaultPath.appendingPathComponent("d")
				return delegate.createFolder(at: dPath)
			}.then { _ -> Promise<Void> in
				let twoCharsPath = rootDirPath.deletingLastPathComponent()
				return delegate.createFolder(at: twoCharsPath)
			}.then { _ -> Promise<Void> in
				return delegate.createFolder(at: rootDirPath)
			}.then { _ -> Void in
				let shorteningDecorator = try VaultFormat7ShorteningProviderDecorator(delegate: decorator, vaultPath: vaultPath)
				let account = VaultAccount(vaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultPath: vaultPath, lastUpToDateCheck: Date())
				try self.vaultAccountManager.saveNewAccount(account)
				try self.saveFileProviderConformMasterkeyToKeychain(masterkey, forVaultUID: vaultUID, vaultVersion: vaultVersion, password: password, storePasswordInKeychain: storePasswordInKeychain)
				VaultManager.cachedDecorators[vaultUID] = shorteningDecorator
			}
		} catch {
			return Promise(error)
		}
	}

	/**
	 - Precondition: It exists a `VaultKeychainEntry` for the `vaultUID` in the keychain
	 - throws: `VaultManagerError.vaultNotFound` if no `VaultKeychainEntry` exists in the keychain for the `vaultUID`
	 */
	func getVaultFromKeychain(forVaultUID vaultUID: String) throws -> VaultKeychainEntry {
		guard let data = CryptomatorKeychain.vault.getAsData(vaultUID) else {
			throw VaultManagerError.vaultNotFound
		}
		let jsonDecoder = JSONDecoder()
		return try jsonDecoder.decode(VaultKeychainEntry.self, from: data)
	}

	/**
	 This method is used to unlock the Vault with `vaultUID` if the user does not want to store his Vault password in the keychain.
	 - Postcondition: The created VaultDecorator is cached under the corresponding `vaultUID`
	 */
	public func manualUnlockVault(withUID vaultUID: String, password: String) throws -> CloudProvider {
		let keychainEntry = try getVaultFromKeychain(forVaultUID: vaultUID)
		let masterkeyFile = try MasterkeyFile.withContentFromData(data: keychainEntry.masterkeyData)
		let masterkey = try masterkeyFile.unlock(passphrase: password)
		return try createVaultDecorator(from: masterkey, vaultUID: vaultUID, vaultVersion: masterkeyFile.version)
	}

	func createVaultDecorator(from masterkey: Masterkey, vaultUID: String, vaultVersion: Int) throws -> CloudProvider {
		let vaultAccount = try vaultAccountManager.getAccount(with: vaultUID)
		let delegate = try providerManager.getProvider(with: vaultAccount.delegateAccountUID)
		return try createVaultDecorator(from: masterkey, delegate: delegate, vaultPath: vaultAccount.vaultPath, vaultUID: vaultUID, vaultVersion: vaultVersion)
	}

	func createVaultDecorator(from masterkey: Masterkey, delegate: CloudProvider, vaultPath: CloudPath, vaultUID: String, vaultVersion: Int) throws -> CloudProvider {
		let cryptor = Cryptor(masterkey: masterkey)
		switch vaultVersion {
		case 7:
			let decorator = try VaultFormat7ProviderDecorator(delegate: delegate, vaultPath: vaultPath, cryptor: cryptor)
			let shorteningDecorator = try VaultFormat7ShorteningProviderDecorator(delegate: decorator, vaultPath: vaultPath)
			VaultManager.cachedDecorators[vaultUID] = shorteningDecorator
			return shorteningDecorator
		case 6:
			let decorator = try VaultFormat6ProviderDecorator(delegate: delegate, vaultPath: vaultPath, cryptor: cryptor)
			let shorteningDecorator = try VaultFormat6ShorteningProviderDecorator(delegate: decorator, vaultPath: vaultPath)
			VaultManager.cachedDecorators[vaultUID] = shorteningDecorator
			return shorteningDecorator
		default:
			throw VaultManagerError.vaultVersionNotSupported
		}
	}

	public func getDecorator(forVaultUID vaultUID: String) throws -> CloudProvider {
		if let cachedDecorator = VaultManager.cachedDecorators[vaultUID] {
			// MARK: Add here masterkey up to date check

			return cachedDecorator
		}
		let vault = try getVaultFromKeychain(forVaultUID: vaultUID)
		guard let password = vault.password else {
			throw VaultManagerError.passwordNotInKeychain
		}
		let masterkeyFile = try MasterkeyFile.withContentFromData(data: vault.masterkeyData)
		let masterkey = try masterkeyFile.unlock(passphrase: password)
		return try createVaultDecorator(from: masterkey, vaultUID: vaultUID, vaultVersion: masterkeyFile.version)
	}

	/**
	 - Precondition: There is no VaultAccount for the `vaultUID` in the database yet
	 - Precondition: It exists a CloudProviderAccount with the `delegateAccountUID` in the database
	 - Precondition: The masterkey file at `masterkeyPath` does exist in the cloud
	 - Postcondition: The masterkey is stored in the keychain with a ScryptCostParameter, which allows the usage in the FileProviderExtension (15mb Memory Limit). Additionally: storePasswordInKeychain <=> the password for the masterkey is also stored in the keychain.
	 - Postcondition: The passed `vaultUID`, `delegateAccountUID` and the `vaultPath` derived from `masterkeyPath` are stored as VaultAccount in the database
	 - Postcondition: The created VaultDecorator is cached under the corresponding `vaultUID`
	 */
	public func createFromExisting(withVaultID vaultUID: String, delegateAccountUID: String, masterkeyPath: CloudPath, password: String, storePasswordInKeychain: Bool) -> Promise<Void> {
		do {
			guard VaultManager.cachedDecorators[vaultUID] == nil else {
				throw VaultManagerError.vaultAlreadyExists
			}
			let delegate = try providerManager.getProvider(with: delegateAccountUID)
			let tmpDirURL = FileManager.default.temporaryDirectory
			let localMasterkeyURL = tmpDirURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
			return delegate.downloadFile(from: masterkeyPath, to: localMasterkeyURL).then {
				let masterkeyFile = try MasterkeyFile.withContentFromURL(url: localMasterkeyURL)
				let masterkey = try masterkeyFile.unlock(passphrase: password)
				let vaultPath = self.getVaultPath(from: masterkeyPath)
				_ = try self.createVaultDecorator(from: masterkey, delegate: delegate, vaultPath: vaultPath, vaultUID: vaultUID, vaultVersion: masterkeyFile.version)
				let vaultAccount = VaultAccount(vaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultPath: vaultPath, lastUpToDateCheck: Date())
				try self.saveFileProviderConformMasterkeyToKeychain(masterkey, forVaultUID: vaultUID, vaultVersion: masterkeyFile.version, password: password, storePasswordInKeychain: storePasswordInKeychain)
				try self.vaultAccountManager.saveNewAccount(vaultAccount)
			}
		} catch {
			VaultManager.cachedDecorators[vaultUID] = nil
			return Promise(error)
		}
	}

	/**
	 - Precondition: It exists a `VaultAccount` for the `vaultUID` in the database
	 - Precondition: It exists a `VaultKeychainEntry` for the `vaultUID` in the keychain
	 - Precondition: It exists a `NSFileProviderDomain` with the `vaultUID` as `identifier`
	 - Postcondition: No `VaultAccount` exists for the `vaultUID` in the database
	 - Postcondition: No `VaultKeychainEntry` exists for the `vaultUID` in the keychain
	 - Postcondition: No `VaultDecorator` is cached under the corresponding `vaultUID`
	 - Postcondition: The `NSFileProviderDomain` with the `vaultUID` as `identifier` was removed from the NSFileProvider
	 */
	public func removeVault(withUID vaultUID: String) -> Promise<Void> {
		do {
			try CryptomatorKeychain.vault.delete(vaultUID)
			try vaultAccountManager.removeAccount(with: vaultUID)
		} catch {
			return Promise(error)
		}
		VaultManager.cachedDecorators[vaultUID] = nil
		return removeFileProviderDomain(withVaultUID: vaultUID)
	}

	public func removeAllUnusedFileProviderDomains() -> Promise<Void> {
		let vaultUIDs: [String]
		do {
			let vaults = try VaultAccountManager.shared.getAllAccounts()
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
				try await (NSFileProviderManager.remove(domain))
			}
			fulfill(())
		}
	}

	/**
	 - Postcondition: The masterkey is stored in the keychain with a ScryptCostParameter, which allows the usage in the FileProviderExtension (15mb Memory Limit). Additionally: storePasswordInKeychain <=> the password for the masterkey is also stored in the keychain.
	 */
	func saveFileProviderConformMasterkeyToKeychain(_ masterkey: Masterkey, forVaultUID vaultUID: String, vaultVersion: Int, password: String, storePasswordInKeychain: Bool) throws {
		let masterkeyDataForFileProvider = try MasterkeyFile.lock(masterkey: masterkey, vaultVersion: vaultVersion, passphrase: password, pepper: [UInt8](), scryptCostParam: VaultManager.scryptCostParamForFileProvider)
		let keychainEntry = VaultKeychainEntry(masterkeyData: masterkeyDataForFileProvider, password: storePasswordInKeychain ? password : nil)
		let jsonEnccoder = JSONEncoder()
		let encodedEntry = try jsonEnccoder.encode(keychainEntry)
		try CryptomatorKeychain.vault.set(vaultUID, value: encodedEntry)
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
		return NSFileProviderManager.getDomains().then { domains -> NSFileProviderDomain in
			let domain = domains.first { $0.identifier.rawValue == vaultUID }
			guard let domainForVault = domain else {
				throw VaultManagerError.fileProviderDomainNotFound
			}
			return domainForVault
		}.then { domainForVault in
			NSFileProviderManager.remove(domainForVault)
		}
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
}
