//
//  EnterSharePointURLViewModel.swift
//  Cryptomator
//
//  Created by Majid Achhoud on 03.12.24.
//  Copyright © 2024 Skymatic GmbH. All rights reserved.
//

import Combine
import CryptomatorCommonCore
import Foundation

protocol EnterSharePointURLViewModelProtocol: SingleSectionTableViewModel, ReturnButtonSupport {
	func getValidatedSharePointURL() throws -> String
}

class EnterSharePointURLViewModel: SingleSectionTableViewModel, EnterSharePointURLViewModelProtocol {
	let account: AccountInfo
	init(account: AccountInfo) {
		self.account = account
	}

	var lastReturnButtonPressed: AnyPublisher<Void, Never> {
		return setupReturnButtonSupport(for: [sharePointURLCellViewModel], subscribers: &subscribers)
	}

	override var cells: [TableViewCellViewModel] {
		return [sharePointURLCellViewModel]
	}

	override var title: String? {
		return LocalizedString.getValue("addVault.enterSharePointURL.title")
	}

	let sharePointURLCellViewModel = TextFieldCellViewModel(
		type: .normal,
		placeholder: LocalizedString.getValue("addVault.enterSharePointURL.placeholder"),
		isInitialFirstResponder: true
	)
	var trimmedSharePointURL: String {
		return sharePointURLCellViewModel.input.value.trimmingCharacters(in: .whitespacesAndNewlines)
	}

	private lazy var subscribers = Set<AnyCancellable>()
	func getValidatedSharePointURL() throws -> String {
		guard !trimmedSharePointURL.isEmpty else {
			throw EnterSharePointURLViewModelError.emptyURL
		}
		try URLValidator.validateSharePointURL(urlString: trimmedSharePointURL)
		return trimmedSharePointURL
	}

	override func getHeaderTitle(for section: Int) -> String? {
		guard section == 0 else {
			return nil
		}
		return LocalizedString.getValue("addVault.enterSharePointURL.header.title")
	}
}

enum EnterSharePointURLViewModelError: LocalizedError {
	case emptyURL
	case invalidURL
	var errorDescription: String? {
		switch self {
		case .emptyURL:
			return LocalizedString.getValue("addVault.enterSharePointURL.error.emptyURL")
		case .invalidURL:
			return LocalizedString.getValue("addVault.enterSharePointURL.error.invalidURL")
		}
	}
}
