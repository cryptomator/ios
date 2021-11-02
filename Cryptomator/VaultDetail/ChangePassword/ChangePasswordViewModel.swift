//
//  ChangePasswordViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 28.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import Combine
import CryptomatorCommonCore
import CryptomatorCryptoLib
import CryptomatorFileProvider
import Foundation
import Promises

protocol ChangePasswordViewModelProtocol {
	var title: String { get }
	var cells: [ChangePasswordSection: [TableViewCellViewModel]] { get }
	var sections: [ChangePasswordSection] { get }
	func changePassword() -> Promise<Void>
	func validatePasswords() throws
	func getHeaderTitle(for section: Int) -> String?
}

enum ChangePasswordViewModelError: Error {
	case emptyPassword
	case newPasswordsDoNotMatch
	case invalidOldPassword
	case tooShortPassword
}

extension ChangePasswordViewModelError: LocalizedError {
	public var errorDescription: String? {
		switch self {
		case .emptyPassword:
			return LocalizedString.getValue("addVault.createNewVault.password.error.emptyPassword")
		case .newPasswordsDoNotMatch:
			return LocalizedString.getValue("addVault.createNewVault.password.error.nonMatchingPasswords")
		case .invalidOldPassword:
			return LocalizedString.getValue("changePassword.error.invalidOldPassword")
		case .tooShortPassword:
			return LocalizedString.getValue("addVault.createNewVault.password.error.tooShortPassword")
		}
	}
}

enum ChangePasswordSection: Int {
	case oldPassword = 0
	case newPassword
	case newPasswordConfirmation
}

class ChangePasswordViewModel: ChangePasswordViewModelProtocol {
	var title: String {
		return vaultAccount.vaultName
	}

	let sections: [ChangePasswordSection] = [.oldPassword, .newPassword, .newPasswordConfirmation]
	lazy var cells: [ChangePasswordSection: [TableViewCellViewModel]] = {
		return [
			.oldPassword: [oldPasswordCellViewModel],
			.newPassword: [newPasswordCellViewModel],
			.newPasswordConfirmation: [newPasswordConfirmationCellViewModel]
		]
	}()

	private static let minimumPasswordLength = 8
	private let vaultAccount: VaultAccount
	private let vaultManager: VaultManager
	private let maintenanceManager: MaintenanceManager
	private let fileProviderConnector: FileProviderConnector

	private let oldPasswordCellViewModel = TextFieldCellViewModel(type: .password)
	private let newPasswordCellViewModel = TextFieldCellViewModel(type: .password)
	private let newPasswordConfirmationCellViewModel = TextFieldCellViewModel(type: .password)

	private var oldPassword: String {
		return oldPasswordCellViewModel.input.value
	}

	private var newPassword: String {
		return newPasswordCellViewModel.input.value
	}

	private var newPasswordConfirmation: String {
		return newPasswordConfirmationCellViewModel.input.value
	}

	init(vaultAccount: VaultAccount, maintenanceManager: MaintenanceManager, vaultManager: VaultManager = VaultDBManager.shared, fileProviderConnector: FileProviderConnector = FileProviderXPCConnector.shared) {
		self.vaultAccount = vaultAccount
		self.maintenanceManager = maintenanceManager
		self.vaultManager = vaultManager
		self.fileProviderConnector = fileProviderConnector
	}

	func changePassword() -> Promise<Void> {
		let validatedPasswords: ValidatedPasswords
		do {
			validatedPasswords = try getValidatedPasswords()
			try maintenanceManager.enableMaintenanceMode()
		} catch {
			return Promise(error)
		}
		return lockVault().then {
			return self.vaultManager.changePassphrase(oldPassphrase: validatedPasswords.oldPassword, newPassphrase: validatedPasswords.newPassword, forVaultUID: self.vaultAccount.vaultUID)
		}.recover { error -> Void in
			if case MasterkeyFileError.invalidPassphrase = error {
				throw ChangePasswordViewModelError.invalidOldPassword
			} else {
				throw error
			}
		}.always {
			do {
				try self.maintenanceManager.disableMaintenanceMode()
			} catch {
				DDLogError("ChangePasswordViewModel: Disabling Maintenance Mode failed with error: \(error)")
			}
		}
	}

	func validatePasswords() throws {
		_ = try getValidatedPasswords()
	}

	func getHeaderTitle(for section: Int) -> String? {
		switch ChangePasswordSection(rawValue: section) {
		case .oldPassword:
			return LocalizedString.getValue("changePassword.header.currentPassword.title")
		case .newPassword:
			return LocalizedString.getValue("changePassword.header.newPassword.title")
		case .newPasswordConfirmation:
			return LocalizedString.getValue("changePassword.header.newPasswordConfirmation.title")
		case nil:
			return nil
		}
	}

	private func getValidatedPasswords() throws -> ValidatedPasswords {
		return try getValidatedPasswords(oldPassword: oldPassword, newPassword: newPassword, newPasswordConfirmation: newPasswordConfirmation)
	}

	private func getValidatedPasswords(oldPassword: String, newPassword: String, newPasswordConfirmation: String) throws -> ValidatedPasswords {
		guard !oldPassword.isEmpty, !newPassword.isEmpty, !newPasswordConfirmation.isEmpty else {
			throw ChangePasswordViewModelError.emptyPassword
		}
		guard newPassword.count >= ChangePasswordViewModel.minimumPasswordLength else {
			throw ChangePasswordViewModelError.tooShortPassword
		}
		guard newPassword == newPasswordConfirmation else {
			throw ChangePasswordViewModelError.newPasswordsDoNotMatch
		}
		return ValidatedPasswords(oldPassword: oldPassword, newPassword: newPassword)
	}

	private func lockVault() -> Promise<Void> {
		let domainIdentifier = NSFileProviderDomainIdentifier(vaultAccount.vaultUID)
		let getProxyPromise: Promise<VaultLocking> = fileProviderConnector.getProxy(serviceName: VaultLockingService.name, domainIdentifier: domainIdentifier)
		return getProxyPromise.then { proxy -> Void in
			proxy.lockVault(domainIdentifier: domainIdentifier)
		}
	}
}

private struct ValidatedPasswords {
	let oldPassword: String
	let newPassword: String
}
