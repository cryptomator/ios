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
import Dependencies
import FileProvider
import Foundation
import Promises

protocol ChangePasswordViewModelProtocol: TableViewModel<ChangePasswordSection>, ReturnButtonSupport {
	func changePassword() async throws
	func validatePasswords() throws
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

class ChangePasswordViewModel: TableViewModel<ChangePasswordSection>, ChangePasswordViewModelProtocol {
	override var title: String? {
		return vaultAccount.vaultName
	}

	var lastReturnButtonPressed: AnyPublisher<Void, Never> {
		return setupReturnButtonSupport(for: [oldPasswordCellViewModel, newPasswordCellViewModel, newPasswordConfirmationCellViewModel], subscribers: &subscribers)
	}

	override var sections: [Section<ChangePasswordSection>] {
		return _sections
	}

	lazy var cells: [ChangePasswordSection: [BindableTableViewCellViewModel]] = [
		.oldPassword: [oldPasswordCellViewModel],
		.newPassword: [newPasswordCellViewModel],
		.newPasswordConfirmation: [newPasswordConfirmationCellViewModel]
	]

	private lazy var _sections: [Section<ChangePasswordSection>] = [
		Section(id: .oldPassword, elements: [oldPasswordCellViewModel]),
		Section(id: .newPassword, elements: [newPasswordCellViewModel]),
		Section(id: .newPasswordConfirmation, elements: [newPasswordConfirmationCellViewModel])
	]

	private static let minimumPasswordLength = 8
	private let vaultAccount: VaultAccount
	private let domain: NSFileProviderDomain
	private let vaultManager: VaultManager
	@Dependency(\.fileProviderConnector) private var fileProviderConnector

	private let oldPasswordCellViewModel = TextFieldCellViewModel(type: .password, isInitialFirstResponder: true)
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

	private lazy var subscribers = Set<AnyCancellable>()

	init(vaultAccount: VaultAccount, domain: NSFileProviderDomain, vaultManager: VaultManager = VaultDBManager.shared) {
		self.vaultAccount = vaultAccount
		self.domain = domain
		self.vaultManager = vaultManager
		super.init()
	}

	func changePassword() async throws {
		let validatedPasswords = try getValidatedPasswords()
		let xpc: XPC<MaintenanceModeHelper> = try await fileProviderConnector.getXPC(serviceName: .maintenanceModeHelper,
		                                                                             domain: domain)
		defer {
			fileProviderConnector.invalidateXPC(xpc)
		}
		try await xpc.proxy.executeExclusiveOperation {
			try await self.lockVault()
			do {
				try await self.changePassphrase(validatedPasswords: validatedPasswords)
			} catch MasterkeyFileError.invalidPassphrase {
				throw ChangePasswordViewModelError.invalidOldPassword
			}
		}
	}

	func validatePasswords() throws {
		_ = try getValidatedPasswords()
	}

	override func getHeaderTitle(for section: Int) -> String? {
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

	private func lockVault() async throws {
		let xpc: XPC<VaultLocking> = try await fileProviderConnector.getXPC(serviceName: .vaultLocking,
		                                                                    domain: domain)
		xpc.proxy.lockVault(domainIdentifier: domain.identifier)
		fileProviderConnector.invalidateXPC(xpc)
	}

	private func changePassphrase(validatedPasswords: ValidatedPasswords) async throws {
		try await withCheckedThrowingContinuation({ (continuation: CheckedContinuation<Void, Error>) -> Void in
			vaultManager.changePassphrase(oldPassphrase: validatedPasswords.oldPassword, newPassphrase: validatedPasswords.newPassword, forVaultUID: self.vaultAccount.vaultUID).then {
				continuation.resume()
			}.catch {
				continuation.resume(throwing: $0)
			}
		})
	}
}

private struct ValidatedPasswords {
	let oldPassword: String
	let newPassword: String
}
