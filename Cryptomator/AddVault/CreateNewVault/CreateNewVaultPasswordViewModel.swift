//
//  CreateNewVaultPasswordViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 18.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Foundation
import Promises

protocol CreateNewVaultPasswordViewModelProtocol: TableViewModel<CreateNewVaultPasswordSection>, ReturnButtonSupport {
	var vaultUID: String { get }
	var vaultName: String { get }
	func validatePassword() throws
	func createNewVault() -> Promise<Void>
}

enum CreateNewVaultPasswordSection: Int {
	case password = 0
	case confirmPassword
}

class CreateNewVaultPasswordViewModel: TableViewModel<CreateNewVaultPasswordSection>, CreateNewVaultPasswordViewModelProtocol {
	var lastReturnButtonPressed: AnyPublisher<Void, Never> {
		return setupReturnButtonSupport(for: [passwordCellViewModel, confirmPasswordCellViewModel], subscribers: &subscribers)
	}

	var vaultName: String {
		return vaultPath.lastPathComponent
	}

	override var title: String? {
		return LocalizedString.getValue("addVault.createNewVault.title")
	}

	override var sections: [Section<CreateNewVaultPasswordSection>] {
		return [
			Section(id: .password, elements: [passwordCellViewModel]),
			Section(id: .confirmPassword, elements: [confirmPasswordCellViewModel])
		]
	}

	let vaultUID: String

	private let vaultPath: CloudPath
	private let account: CloudProviderAccount
	private static let minimumPasswordLength = 8
	private lazy var passwordCellViewModel = TextFieldCellViewModel(type: .password, isInitialFirstResponder: true)
	private lazy var confirmPasswordCellViewModel = TextFieldCellViewModel(type: .password)
	private lazy var subscribers = Set<AnyCancellable>()

	private var password: String {
		return passwordCellViewModel.input.value
	}

	private var confirmingPassword: String {
		return confirmPasswordCellViewModel.input.value
	}

	init(vaultPath: CloudPath, account: CloudProviderAccount, vaultUID: String) {
		self.vaultPath = vaultPath
		self.account = account
		self.vaultUID = vaultUID
	}

	func validatePassword() throws {
		guard !password.isEmpty else {
			throw CreateNewVaultPasswordViewModelError.emptyPassword
		}
		guard password == confirmingPassword else {
			throw CreateNewVaultPasswordViewModelError.nonMatchingPasswords
		}
		guard password.count >= CreateNewVaultPasswordViewModel.minimumPasswordLength else {
			throw CreateNewVaultPasswordViewModelError.tooShortPassword
		}
	}

	func createNewVault() -> Promise<Void> {
		do {
			try validatePassword()
		} catch {
			return Promise(error)
		}
		return VaultDBManager.shared.createNewVault(withVaultUID: vaultUID, delegateAccountUID: account.accountUID, vaultPath: vaultPath, password: password, storePasswordInKeychain: false)
	}

	override func getHeaderTitle(for section: Int) -> String? {
		switch CreateNewVaultPasswordSection(rawValue: section) {
		case .password:
			return LocalizedString.getValue("addVault.createNewVault.password.enterPassword.header")
		case .confirmPassword:
			return LocalizedString.getValue("addVault.createNewVault.password.confirmPassword.header")
		case .none:
			return nil
		}
	}
}

enum CreateNewVaultPasswordViewModelError: LocalizedError {
	case emptyPassword
	case nonMatchingPasswords
	case tooShortPassword

	var errorDescription: String? {
		switch self {
		case .emptyPassword:
			return LocalizedString.getValue("addVault.createNewVault.password.error.emptyPassword")
		case .nonMatchingPasswords:
			return LocalizedString.getValue("addVault.createNewVault.password.error.nonMatchingPasswords")
		case .tooShortPassword:
			return LocalizedString.getValue("addVault.createNewVault.password.error.tooShortPassword")
		}
	}
}
