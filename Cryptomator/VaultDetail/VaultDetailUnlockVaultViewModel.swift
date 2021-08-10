//
//  VaultDetailUnlockVaultViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 04.08.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import CryptomatorCryptoLib
import Foundation

class VaultDetailUnlockVaultViewModel {
	var title: String {
		return vault.vaultName
	}

	var footerTitle: String {
		return String(format: NSLocalizedString("vaultDetail.unlockVault.footer", comment: ""), vault.vaultName, biometryTypeName)
	}

	var password: String?
	private let vault: VaultInfo
	private let biometryTypeName: String
	private let passwordManager: VaultPasswordManager

	init(vault: VaultInfo, biometryTypeName: String, passwordManager: VaultPasswordManager) {
		self.vault = vault
		self.biometryTypeName = biometryTypeName
		self.passwordManager = passwordManager
	}

	func unlockVault() throws {
		guard let password = password else {
			throw MasterkeyProcessingViewModelError.noPasswordSet
		}
		let cachedVault = try VaultDBCache(dbWriter: CryptomatorDatabase.shared.dbPool).getCachedVault(withVaultUID: vault.vaultUID)
		let masterkeyFile = try MasterkeyFile.withContentFromData(data: cachedVault.masterkeyFileData)
		_ = try masterkeyFile.unlock(passphrase: password)
		try passwordManager.setPassword(password, forVaultUID: vault.vaultUID)
	}
}
