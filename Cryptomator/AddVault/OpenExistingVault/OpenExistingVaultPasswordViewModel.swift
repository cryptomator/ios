//
//  OpenExistingVaultPasswordViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 29.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Foundation
import Promises

protocol OpenExistingVaultPasswordViewModelProtocol {
	var password: String? { get set }
	var footerTitle: String { get }
	var vaultName: String { get }
	var vaultUID: String { get }
	// This function is later no longer asynchronous
	func addVault() -> Promise<Void>
}

class OpenExistingVaultPasswordViewModel: OpenExistingVaultPasswordViewModelProtocol {
	var password: String?
	let provider: CloudProvider
	let account: CloudProviderAccount

	// later: localMasterkeyURL: URL instead of masterkeyPath: CloudPath
	let vault: VaultItem
	var vaultName: String {
		return vault.name
	}

	var footerTitle: String {
		return String(format: NSLocalizedString("addVault.openExistingVault.password.footer", comment: ""), vaultName)
	}

	let vaultUID: String

	init(provider: CloudProvider, account: CloudProviderAccount, vault: VaultItem, vaultUID: String) {
		self.provider = provider
		self.account = account
		self.vault = vault
		self.vaultUID = vaultUID
	}

	func addVault() -> Promise<Void> {
		guard let password = password else {
			return Promise(MasterkeyProcessingViewModelError.noPasswordSet)
		}
		return VaultDBManager.shared.createFromExisting(withVaultUID: vaultUID, delegateAccountUID: account.accountUID, vaultDetails: vault, password: password, storePasswordInKeychain: true)
	}
}

enum MasterkeyProcessingViewModelError: Error {
	case noPasswordSet
}
