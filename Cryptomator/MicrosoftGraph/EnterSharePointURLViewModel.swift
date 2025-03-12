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
	func getValidatedSharePointURL() throws -> URL
}

class EnterSharePointURLViewModel: SingleSectionTableViewModel, EnterSharePointURLViewModelProtocol {
	var lastReturnButtonPressed: AnyPublisher<Void, Never> {
		return setupReturnButtonSupport(for: [sharePointURLCellViewModel], subscribers: &subscribers)
	}

	override var cells: [TableViewCellViewModel] {
		return [sharePointURLCellViewModel]
	}

	override var title: String? {
		return LocalizedString.getValue("sharePoint.enterURL.title")
	}

	let sharePointURLCellViewModel = TextFieldCellViewModel(type: .url, text: "https://", placeholder: LocalizedString.getValue("sharePoint.enterURL.placeholder"), isInitialFirstResponder: true)

	var trimmedSharePointURL: String {
		var trimmedSharePointURL = sharePointURLCellViewModel.input.value.trimmingCharacters(in: .whitespacesAndNewlines)
		while trimmedSharePointURL.hasSuffix("/") && trimmedSharePointURL.count > "https://".count {
			trimmedSharePointURL = String(trimmedSharePointURL.dropLast())
		}
		return trimmedSharePointURL
	}

	private lazy var subscribers = Set<AnyCancellable>()

	func getValidatedSharePointURL() throws -> URL {
		return try SharePointURLValidator.validateSharePointURL(urlString: trimmedSharePointURL)
	}

	override func getHeaderTitle(for section: Int) -> String? {
		guard section == 0 else {
			return nil
		}
		return LocalizedString.getValue("sharePoint.enterURL.header.title")
	}
}
