//
//  SetVaultNameViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 16.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Foundation

protocol SetVaultNameViewModelProtocol: SingleSectionHeaderTableViewModelProtocol {
	var vaultName: String? { get set }
	func getValidatedVaultName() throws -> String
}

class SetVaultNameViewModel: SetVaultNameViewModelProtocol {
	let headerTitle = LocalizedString.getValue("addVault.createNewVault.setVaultName.header.title")
	let headerUppercased = false

	var vaultName: String? {
		get {
			return trimmedVaultName
		}
		set {
			trimmedVaultName = newValue?.trimmingCharacters(in: .whitespacesAndNewlines)
		}
	}

	private var trimmedVaultName: String?

	// disallowed characters \ / : * ? " < > |
	// cannot end with .
	// swiftlint:disable:next force_try
	private let regex = try! NSRegularExpression(pattern: "[\\\\/:\\*\\?\"<>\\|]|\\.$")

	func getValidatedVaultName() throws -> String {
		guard let trimmedVaultName = trimmedVaultName, !trimmedVaultName.isEmpty else {
			throw SetVaultNameViewModelError.emptyVaultName
		}
		let range = NSRange(location: 0, length: trimmedVaultName.utf16.count)
		guard regex.firstMatch(in: trimmedVaultName, options: [], range: range) == nil else {
			throw SetVaultNameViewModelError.invalidInput
		}
		return trimmedVaultName
	}
}

enum SetVaultNameViewModelError: LocalizedError {
	case emptyVaultName
	case invalidInput

	var errorDescription: String? {
		switch self {
		case .emptyVaultName:
			return LocalizedString.getValue("addVault.createNewVault.setVaultName.error.emptyVaultName")
		case .invalidInput:
			return LocalizedString.getValue("addVault.createNewVault.setVaultName.error.invalidInput")
		}
	}
}
