//
//  DecoratorFactory.swift
//  CryptomatorIntegrationTests
//
//  Created by Philipp Schmid on 06.11.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation
@testable import CloudAccessPrivateCore
import CryptomatorCryptoLib
import CryptomatorCloudAccess
import Promises
class DecoratorFactory {
	static func createNewVault7(delegate: CloudProvider, vaultPath: CloudPath, password: String) -> Promise<VaultFormat7ProviderDecorator> {
		do{
			let masterkey = try Masterkey.createNew()
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

	static func createFromExistingVault7(delegate: CloudProvider, vaultPath: CloudPath, password: String) -> Promise<VaultFormat7ProviderDecorator> {
		do {
			let masterkeyCloudPath = vaultPath.appendingPathComponent("masterkey.cryptomator")
			let tmpDirURL = FileManager.default.temporaryDirectory
			let localMasterkeyURL = tmpDirURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
			return delegate.downloadFile(from: masterkeyCloudPath, to: localMasterkeyURL).then { () -> VaultFormat7ProviderDecorator in
				let masterkey = try Masterkey.createFromMasterkeyFile(fileURL: localMasterkeyURL, password: password)
				let cryptor = Cryptor(masterkey: masterkey)
				return try VaultFormat7ProviderDecorator(delegate: delegate, vaultPath: vaultPath, cryptor: cryptor)
			}
		} catch {
			return Promise(error)
		}
	}
}
