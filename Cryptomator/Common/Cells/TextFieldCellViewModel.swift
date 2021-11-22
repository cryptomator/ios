//
//  TextFieldCellViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 29.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import Foundation

enum TextFieldCellType {
	case normal
	case password
	case username
	case url
}

class TextFieldCellViewModel: BindableTableViewCellViewModel {
	let textFielCellType: TextFieldCellType
	override var type: ConfigurableTableViewCell.Type {
		switch textFielCellType {
		case .normal:
			return TextFieldCell.self
		case .password:
			return PasswordFieldCell.self
		case .username:
			return UsernameFieldCell.self
		case .url:
			return URLFieldCell.self
		}
	}

	let input: Bindable<String>
	let placeholder: String?
	let isInitialFirstResponder: Bool
	private lazy var returnButtonPressedPublisher = PassthroughSubject<Void, Never>()
	private lazy var becomeFirstResponderPublisher = PassthroughSubject<Void, Never>()

	init(type: TextFieldCellType, text: String = "", placeholder: String? = nil, isInitialFirstResponder: Bool = false) {
		self.textFielCellType = type
		self.input = Bindable(text)
		self.placeholder = placeholder
		self.isInitialFirstResponder = isInitialFirstResponder
	}

	func returnButtonPressed() {
		returnButtonPressedPublisher.send()
	}

	func startListeningToReturnButtonPressedEvents() -> AnyPublisher<Void, Never> {
		return returnButtonPressedPublisher.eraseToAnyPublisher()
	}

	func becomeFirstResponder() {
		becomeFirstResponderPublisher.send()
	}

	func startListeningToBecomeFirstResponder() -> AnyPublisher<Void, Never> {
		return becomeFirstResponderPublisher.eraseToAnyPublisher()
	}
}
