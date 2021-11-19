//
//  OpenExistingVaultPasswordViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 29.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Foundation
import Promises

protocol OpenExistingVaultPasswordViewModelProtocol: SingleSectionTableViewModel, ReturnButtonSupport {
	var vaultName: String { get }
	var vaultUID: String { get }
	var enableVerifyButton: AnyPublisher<Bool, Never> { get }
	// This function is later no longer asynchronous
	func addVault() -> Promise<Void>
}

class OpenExistingVaultPasswordViewModel: SingleSectionTableViewModel, OpenExistingVaultPasswordViewModelProtocol {
	var lastReturnButtonPressed: AnyPublisher<Void, Never> {
		return setupReturnButtonSupport(for: [passwordCellViewModel], subscribers: &subscribers)
	}

	override var title: String? {
		return LocalizedString.getValue("addVault.openExistingVault.title")
	}

	override var cells: [TableViewCellViewModel] {
		return [passwordCellViewModel]
	}

	var enableVerifyButton: AnyPublisher<Bool, Never> {
		return passwordCellViewModel.input.$value.map { input in
			return !input.isEmpty
		}.eraseToAnyPublisher()
	}

	let provider: CloudProvider
	let account: CloudProviderAccount

	let vault: VaultItem
	var vaultName: String {
		return vault.name
	}

	let vaultUID: String
	let passwordCellViewModel = TextFieldCellViewModel(type: .password, isInitialFirstResponder: true)
	var password: String {
		return passwordCellViewModel.input.value
	}

	private lazy var subscribers = Set<AnyCancellable>()

	init(provider: CloudProvider, account: CloudProviderAccount, vault: VaultItem, vaultUID: String) {
		self.provider = provider
		self.account = account
		self.vault = vault
		self.vaultUID = vaultUID
	}

	func addVault() -> Promise<Void> {
		return VaultDBManager.shared.createFromExisting(withVaultUID: vaultUID, delegateAccountUID: account.accountUID, vaultItem: vault, password: password, storePasswordInKeychain: false)
	}

	override func getFooterTitle(for section: Int) -> String? {
		guard section == 0 else {
			return nil
		}
		return String(format: LocalizedString.getValue("addVault.openExistingVault.password.footer"), vaultName)
	}
}
