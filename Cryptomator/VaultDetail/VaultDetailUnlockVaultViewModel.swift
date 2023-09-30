//
//  VaultDetailUnlockVaultViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 04.08.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import CryptomatorCommonCore
import CryptomatorCryptoLib
import Foundation

class VaultDetailUnlockVaultViewModel: SingleSectionTableViewModel, ReturnButtonSupport {
	var lastReturnButtonPressed: AnyPublisher<Void, Never> {
		return setupReturnButtonSupport(for: [passwordCellViewModel], subscribers: &subscribers)
	}

	override var title: String? {
		return vault.vaultName
	}

	override var cells: [TableViewCellViewModel] {
		return [passwordCellViewModel]
	}

	var enableVerifyButton: AnyPublisher<Bool, Never> {
		return passwordCellViewModel.input.$value.map { input in
			return !input.isEmpty
		}.eraseToAnyPublisher()
	}

	let passwordCellViewModel = TextFieldCellViewModel(type: .password, isInitialFirstResponder: true)
	private var password: String {
		return passwordCellViewModel.input.value
	}

	private let vault: VaultInfo
	private let biometryTypeName: String
	private let passwordManager: VaultPasswordManager
	private lazy var subscribers = Set<AnyCancellable>()

	init(vault: VaultInfo, biometryTypeName: String, passwordManager: VaultPasswordManager) {
		self.vault = vault
		self.biometryTypeName = biometryTypeName
		self.passwordManager = passwordManager
	}

	func unlockVault() throws {
		let cachedVault = try VaultDBCache().getCachedVault(withVaultUID: vault.vaultUID)
		let masterkeyFile = try MasterkeyFile.withContentFromData(data: cachedVault.masterkeyFileData)
		_ = try masterkeyFile.unlock(passphrase: password)
		try passwordManager.setPassword(password, forVaultUID: vault.vaultUID)
	}

	override func getFooterTitle(for section: Int) -> String? {
		guard section == 0 else {
			return nil
		}
		return String(format: LocalizedString.getValue("vaultDetail.unlockVault.footer"), vault.vaultName, biometryTypeName)
	}
}
