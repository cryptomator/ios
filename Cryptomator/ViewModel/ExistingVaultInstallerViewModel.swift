//
//  ExistingVaultInstallerViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 10.11.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CloudAccessPrivateCore
import CryptomatorCloudAccess
import FileProvider
import Foundation
import Promises
class ExistingVaultInstallerViewModel {
	let masterkeyPath: CloudPath
	let providerAccountUID: String

	init(providerAccountUID: String, masterkeyPath: CloudPath) {
		self.providerAccountUID = providerAccountUID
		self.masterkeyPath = masterkeyPath
	}

	func installVault(withPassword password: String) -> Promise<String> {
		let vaultUID = UUID().uuidString
		return VaultManager.shared.createFromExisting(withVaultID: vaultUID, delegateAccountUID: providerAccountUID, masterkeyPath: masterkeyPath, password: password, storePasswordInKeychain: true).then {
			self.registerFileProviderDomain(for: vaultUID)
		}.then{
			return vaultUID
		}
	}

	func registerFileProviderDomain(for vaultUID: String) -> Promise<Void> {
		let identifier = NSFileProviderDomainIdentifier(vaultUID)
		let vaultPath = VaultManager.shared.getVaultPath(from: masterkeyPath)
		let domain = NSFileProviderDomain(identifier: identifier, displayName: vaultPath.lastPathComponent, pathRelativeToDocumentStorage: vaultUID)
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
