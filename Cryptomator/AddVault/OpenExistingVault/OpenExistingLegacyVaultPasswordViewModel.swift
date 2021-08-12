//
//  OpenExistingLegacyVaultPasswordViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 15.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Foundation
import Promises

class OpenExistingLegacyVaultPasswordViewModel: OpenExistingVaultPasswordViewModelProtocol {
	var password: String?
	let provider: CloudProvider
	let account: CloudProviderAccount

	let vault: VaultItem
	var vaultName: String {
		return vault.name
	}

	var footerTitle: String {
		return String(format: LocalizedString.getValue("addVault.openExistingVault.password.footer"), vaultName)
	}

	private let localMasterkeyURL: URL
	let vaultUID: String

	init(provider: CloudProvider, account: CloudProviderAccount, vault: VaultItem, vaultID: String) {
		self.provider = provider
		self.account = account
		self.vault = vault
		let tmpDirURL = FileManager.default.temporaryDirectory
		self.localMasterkeyURL = tmpDirURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
		self.vaultUID = vaultID
	}

	func addVault() -> Promise<Void> {
		guard let password = password else {
			return Promise(MasterkeyProcessingViewModelError.noPasswordSet)
		}
		return VaultDBManager.shared.createLegacyFromExisting(withVaultUID: vaultUID, delegateAccountUID: account.accountUID, vaultItem: vault, password: password, storePasswordInKeychain: false)
	}
}
