//
//  DecoratorFactory.swift
//  CryptomatorIntegrationTests
//
//  Created by Philipp Schmid on 06.11.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import Foundation
import Promises
@testable import CloudAccessPrivateCore
@testable import CryptomatorCryptoLib
class DecoratorFactory {
	// MARK: VaultFormat7

	static func createNewVaultFormat7(delegate: CloudProvider, vaultPath: CloudPath, password: String) -> Promise<VaultFormat7ProviderDecorator> {
		do {
			let masterkey = Masterkey.createFromRaw(aesMasterKey: [UInt8](repeating: 0x55, count: 32), macMasterKey: [UInt8](repeating: 0x77, count: 32), version: 7)
			let cryptor = Cryptor(masterkey: masterkey)
			let decorator = try VaultFormat7ProviderDecorator(delegate: delegate, vaultPath: vaultPath, cryptor: cryptor)
			let rootDirPath = try VaultManager.getRootDirectoryPath(for: cryptor, vaultPath: vaultPath)
			return delegate.createFolder(at: vaultPath).then { () -> Promise<CloudItemMetadata> in
				let tmpDirURL = FileManager.default.temporaryDirectory
				let localMasterkeyURL = tmpDirURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
				let masterkeyData = try masterkey.exportEncrypted(password: password, scryptCostParam: 2)
				try masterkeyData.write(to: localMasterkeyURL)
				let masterkeyCloudPath = vaultPath.appendingPathComponent("masterkey.cryptomator")
				return delegate.uploadFile(from: localMasterkeyURL, to: masterkeyCloudPath, replaceExisting: false)
			}.then { _ -> Promise<Void> in
				let dPath = vaultPath.appendingPathComponent("d")
				return delegate.createFolder(at: dPath)
			}.then { () -> Promise<Void> in
				let twoCharsPath = rootDirPath.deletingLastPathComponent()
				return delegate.createFolder(at: twoCharsPath)
			}.then { () -> Promise<Void> in
				return delegate.createFolder(at: rootDirPath)
			}.then { () -> VaultFormat7ProviderDecorator in
				return decorator
			}
		} catch {
			return Promise(error)
		}
	}

	static func createFromExistingVaultFormat7(delegate: CloudProvider, vaultPath: CloudPath, password: String) -> Promise<VaultFormat7ProviderDecorator> {
		let masterkeyCloudPath = vaultPath.appendingPathComponent("masterkey.cryptomator")
		let tmpDirURL = FileManager.default.temporaryDirectory
		let localMasterkeyURL = tmpDirURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
		return delegate.downloadFile(from: masterkeyCloudPath, to: localMasterkeyURL).then { () -> VaultFormat7ProviderDecorator in
			let masterkey = try Masterkey.createFromMasterkeyFile(fileURL: localMasterkeyURL, password: password)
			let cryptor = Cryptor(masterkey: masterkey)
			return try VaultFormat7ProviderDecorator(delegate: delegate, vaultPath: vaultPath, cryptor: cryptor)
		}
	}

	// MARK: VaultFormat6

	static func createNewVaultFormat6(delegate: CloudProvider, vaultPath: CloudPath, password: String) -> Promise<VaultFormat6ProviderDecorator> {
		do {
			let masterkey = Masterkey.createFromRaw(aesMasterKey: [UInt8](repeating: 0x55, count: 32), macMasterKey: [UInt8](repeating: 0x77, count: 32), version: 6)
			let cryptor = Cryptor(masterkey: masterkey)
			let decorator = try VaultFormat6ProviderDecorator(delegate: delegate, vaultPath: vaultPath, cryptor: cryptor)
			let rootDirPath = try VaultManager.getRootDirectoryPath(for: cryptor, vaultPath: vaultPath)
			return delegate.createFolder(at: vaultPath).then { () -> Promise<CloudItemMetadata> in
				let tmpDirURL = FileManager.default.temporaryDirectory
				let localMasterkeyURL = tmpDirURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
				let masterkeyData = try masterkey.exportEncrypted(password: password, scryptCostParam: 2)
				try masterkeyData.write(to: localMasterkeyURL)
				let masterkeyCloudPath = vaultPath.appendingPathComponent("masterkey.cryptomator")
				return delegate.uploadFile(from: localMasterkeyURL, to: masterkeyCloudPath, replaceExisting: false)
			}.then { _ -> Promise<Void> in
				let mPath = vaultPath.appendingPathComponent("m")
				return delegate.createFolder(at: mPath)
			}.then { _ -> Promise<Void> in
				let dPath = vaultPath.appendingPathComponent("d")
				return delegate.createFolder(at: dPath)
			}.then { () -> Promise<Void> in
				let twoCharsPath = rootDirPath.deletingLastPathComponent()
				return delegate.createFolder(at: twoCharsPath)
			}.then { () -> Promise<Void> in
				return delegate.createFolder(at: rootDirPath)
			}.then { () -> VaultFormat6ProviderDecorator in
				return decorator
			}
		} catch {
			return Promise(error)
		}
	}

	static func createFromExistingVaultFormat6(delegate: CloudProvider, vaultPath: CloudPath, password: String) -> Promise<VaultFormat6ProviderDecorator> {
		let masterkeyCloudPath = vaultPath.appendingPathComponent("masterkey.cryptomator")
		let tmpDirURL = FileManager.default.temporaryDirectory
		let localMasterkeyURL = tmpDirURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
		return delegate.downloadFile(from: masterkeyCloudPath, to: localMasterkeyURL).then { () -> VaultFormat6ProviderDecorator in
			let masterkey = try Masterkey.createFromMasterkeyFile(fileURL: localMasterkeyURL, password: password)
			let cryptor = Cryptor(masterkey: masterkey)
			return try VaultFormat6ProviderDecorator(delegate: delegate, vaultPath: vaultPath, cryptor: cryptor)
		}
	}
}
