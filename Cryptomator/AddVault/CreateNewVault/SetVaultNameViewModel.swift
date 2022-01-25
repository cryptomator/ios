//
//  SetVaultNameViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 16.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import CryptomatorCommonCore
import Foundation

protocol SetVaultNameViewModelProtocol: SingleSectionTableViewModel, ReturnButtonSupport {
	func getValidatedVaultName() throws -> String
}

class SetVaultNameViewModel: SingleSectionTableViewModel, SetVaultNameViewModelProtocol {
	var lastReturnButtonPressed: AnyPublisher<Void, Never> {
		return setupReturnButtonSupport(for: [vaultNameCellViewModel], subscribers: &subscribers)
	}

	override var cells: [TableViewCellViewModel] {
		return [vaultNameCellViewModel]
	}

	override var title: String? {
		return LocalizedString.getValue("addVault.createNewVault.title")
	}

	let vaultNameCellViewModel = TextFieldCellViewModel(type: .normal, placeholder: LocalizedString.getValue("addVault.createNewVault.setVaultName.cells.name"), isInitialFirstResponder: true)

	var trimmedVaultName: String {
		return vaultNameCellViewModel.input.value.trimmingCharacters(in: .whitespacesAndNewlines)
	}

	private lazy var subscribers = Set<AnyCancellable>()

	// disallowed characters \ / : * ? " < > |
	// cannot end with .
	func getValidatedVaultName() throws -> String {
		guard !trimmedVaultName.isEmpty else {
			throw SetVaultNameViewModelError.emptyVaultName
		}
		try ItemNameValidator.validateName(trimmedVaultName)
		return trimmedVaultName
	}

	override func getHeaderTitle(for section: Int) -> String? {
		guard section == 0 else {
			return nil
		}
		return LocalizedString.getValue("addVault.createNewVault.setVaultName.header.title")
	}
}

enum SetVaultNameViewModelError: LocalizedError {
	case emptyVaultName

	var errorDescription: String? {
		switch self {
		case .emptyVaultName:
			return LocalizedString.getValue("addVault.createNewVault.setVaultName.error.emptyVaultName")
		}
	}
}
