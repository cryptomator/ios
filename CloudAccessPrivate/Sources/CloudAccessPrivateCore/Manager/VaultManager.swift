//
//  VaultManager.swift
//  CloudAccessPrivateCore
//
//  Created by Philipp Schmid on 30.10.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import CryptomatorCryptoLib
import Foundation
import Promises
public enum VaultManagerError: Error {
	case vaultAlreadyExists
	case vaultNotFound
	case vaultVersionNotSupported
	case passwordNotInKeychain
}

struct VaultKeychainEntry: Codable {
	let masterkeyData: Data
	let password: String?
}

/* class DecoratorCache{
 	private static var cachedDecorators = [String: CloudProvider]()
 	private static var delegateAccountUIDToVaultUIDMap = [String: [String]]()

 	static func getCachedDecorator(forVaultUID vaultUID: String) -> CloudProvider? {
 		return cachedDecorators[vaultUID]
 	}

 	static func cacheDecorator(_ decorator: CloudProvider, forVaultUID vaultUID: String, delegateAccountUID: String) {
 		if let vaultUIDs = delegateAccountUIDToVaultUIDMap[delegateAccountUID] {
 			delegateAccountUIDToVaultUIDMap[delegateAccountUID] = vaultUIDs.append(vaultUID)
 		} else {
 			delegateAccountUIDToVaultUIDMap[delegateAccountUID] = [vaultUID]
 		}
 		cachedDecorators[vaultUID] = decorator
 	}

 	static func uncacheDecorator(withVaultUID vaultUID: String) {
 		cachedDecorators[vaultUID] = nil
 	}

 	static func getVaultUIDs(withDelegateAccountUID delegateAccountUID: String) -> [String]? {
 		return delegateAccountUIDToVaultUIDMap[delegateAccountUID]
 	}
 } */

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
			let masterkey = try Masterkey.createNew()
			let cryptor = Cryptor(masterkey: masterkey)
			let delegate = try providerManager.getProvider(with: delegateAccountUID)
			let decorator = try VaultFormat7ProviderDecorator(delegate: delegate, vaultPath: vaultPath, cryptor: cryptor)
			let rootDirPath = try VaultManager.getRootDirectoryPath(for: cryptor, vaultPath: vaultPath)
			return delegate.createFolder(at: vaultPath).then { _ -> Promise<CloudItemMetadata> in
				let tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true)
				try FileManager.default.createDirectory(at: tmpDirURL, withIntermediateDirectories: true)
				let localMasterkeyURL = tmpDirURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
				let masterkeyData = try self.exportMasterkey(masterkey, password: password)
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
				try self.saveFileProviderConformMasterkeyToKeychain(masterkey, forVaultUID: vaultUID, password: password, storePasswordInKeychain: storePasswordInKeychain)
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
		let masterkey = try Masterkey.createFromMasterkeyFile(jsonData: keychainEntry.masterkeyData, password: password)
		return try createVaultDecorator(from: masterkey, vaultUID: vaultUID)
	}

	func createVaultDecorator(from masterkey: Masterkey, vaultUID: String) throws -> CloudProvider {
		let vaultAccount = try vaultAccountManager.getAccount(with: vaultUID)
		let delegate = try providerManager.getProvider(with: vaultAccount.delegateAccountUID)
		return try createVaultDecorator(from: masterkey, delegate: delegate, vaultPath: vaultAccount.vaultPath, vaultUID: vaultUID)
	}

	func createVaultDecorator(from masterkey: Masterkey, delegate: CloudProvider, vaultPath: CloudPath, vaultUID: String) throws -> CloudProvider {
		let cryptor = Cryptor(masterkey: masterkey)
		switch masterkey.version {
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
		let masterkey = try Masterkey.createFromMasterkeyFile(jsonData: vault.masterkeyData, password: password)
		return try createVaultDecorator(from: masterkey, vaultUID: vaultUID)
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
				let masterkey = try Masterkey.createFromMasterkeyFile(fileURL: localMasterkeyURL, password: password)
				let vaultPath = masterkeyPath.deletingLastPathComponent()
				_ = try self.createVaultDecorator(from: masterkey, delegate: delegate, vaultPath: vaultPath, vaultUID: vaultUID)
				let vaultAccount = VaultAccount(vaultUID: vaultUID, delegateAccountUID: delegateAccountUID, vaultPath: vaultPath, lastUpToDateCheck: Date())
				try self.saveFileProviderConformMasterkeyToKeychain(masterkey, forVaultUID: vaultUID, password: password, storePasswordInKeychain: storePasswordInKeychain)
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
	 - Postcondition: No `VaultAccount` exists for the `vaultUID` in the database
	 - Postcondition: No `VaultKeychainEntry` exists for the `vaultUID` in the keychain
	 - Postcondition: No `VaultDecorator` is cached under the corresponding `vaultUID`.
	 */
	public func removeVault(withUID vaultUID: String) throws {
		try CryptomatorKeychain.vault.delete(vaultUID)
		try vaultAccountManager.removeAccount(with: vaultUID)
		VaultManager.cachedDecorators[vaultUID] = nil
	}

	/**
	 - Postcondition: The masterkey is stored in the keychain with a ScryptCostParameter, which allows the usage in the FileProviderExtension (15mb Memory Limit). Additionally: storePasswordInKeychain <=> the password for the masterkey is also stored in the keychain.
	 */
	func saveFileProviderConformMasterkeyToKeychain(_ masterkey: Masterkey, forVaultUID vaultUID: String, password: String, storePasswordInKeychain: Bool) throws {
		let masterkeyDataForFileProvider = try masterkey.exportEncrypted(password: password, pepper: [UInt8](), scryptCostParam: VaultManager.scryptCostParamForFileProvider)
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

	func exportMasterkey(_ masterkey: Masterkey, password: String) throws -> Data {
		return try masterkey.exportEncrypted(password: password)
	}
}
