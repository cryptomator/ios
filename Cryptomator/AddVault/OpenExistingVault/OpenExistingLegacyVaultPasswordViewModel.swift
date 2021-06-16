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

	// later: localMasterkeyURL: URL instead of masterkeyPath: CloudPath
	let masterkeyPath: CloudPath
	var vaultName: String {
		let masterkeyParentPath = masterkeyPath.deletingLastPathComponent()
		return masterkeyParentPath.lastPathComponent
	}

	var footerTitle: String {
		return String(format: NSLocalizedString("addVault.openExistingVault.password.footer", comment: ""), vaultName)
	}

	private let localMasterkeyURL: URL
	let vaultUID: String

	init(provider: CloudProvider, account: CloudProviderAccount, masterkeyPath: CloudPath, vaultID: String) {
		self.provider = provider
		self.account = account
		self.masterkeyPath = masterkeyPath
		let tmpDirURL = FileManager.default.temporaryDirectory
		self.localMasterkeyURL = tmpDirURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
		self.vaultUID = vaultID
	}

	func addVault() -> Promise<Void> {
		guard let password = password else {
			return Promise(MasterkeyProcessingViewModelError.noPasswordSet)
		}
		return VaultManager.shared.createLegacyFromExisting(withVaultUID: vaultUID, delegateAccountUID: account.accountUID, masterkeyPath: masterkeyPath, password: password, storePasswordInKeychain: true)
	}
}
