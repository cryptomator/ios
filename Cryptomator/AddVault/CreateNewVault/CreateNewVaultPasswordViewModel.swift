//
//  CreateNewVaultPasswordViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 18.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Foundation
import Promises
protocol CreateNewVaultPasswordViewModelProtocol {
	var headerTitles: [String] { get }
	var vaultUID: String { get }
	var vaultName: String { get }
	var password: String? { get set }
	var confirmingPassword: String? { get set }
	func validatePassword() throws
	func createNewVault() -> Promise<Void>
}

class CreateNewVaultPasswordViewModel: CreateNewVaultPasswordViewModelProtocol {
	var vaultName: String {
		return vaultPath.lastPathComponent
	}

	let vaultUID: String
	let headerTitles = ["Enter a new password.", "Confirm the new password."]
	var password: String?
	var confirmingPassword: String?

	private let vaultPath: CloudPath
	private let account: CloudProviderAccount
	private static let minimumPasswordLength = 8

	init(vaultPath: CloudPath, account: CloudProviderAccount, vaultUID: String) {
		self.vaultPath = vaultPath
		self.account = account
		self.vaultUID = vaultUID
	}

	func validatePassword() throws {
		guard let password = password, !password.isEmpty else {
			throw CreateNewVaultPasswordViewModelError.emptyPassword
		}
		guard let confirmingPassword = confirmingPassword, password == confirmingPassword else {
			throw CreateNewVaultPasswordViewModelError.nonMatchingPasswords
		}
		guard password.count >= CreateNewVaultPasswordViewModel.minimumPasswordLength else {
			throw CreateNewVaultPasswordViewModelError.tooShortPassword
		}
	}

	func createNewVault() -> Promise<Void> {
		guard let password = password else {
			return Promise(CreateNewVaultPasswordViewModelError.emptyPassword)
		}
		return VaultDBManager.shared.createNewVault(withVaultUID: vaultUID, delegateAccountUID: account.accountUID, vaultPath: vaultPath, password: password, storePasswordInKeychain: true)
	}
}

enum CreateNewVaultPasswordViewModelError: Error {
	case emptyPassword
	case nonMatchingPasswords
	case tooShortPassword
}
