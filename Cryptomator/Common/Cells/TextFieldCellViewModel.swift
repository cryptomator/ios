//
//  TextFieldCellViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 29.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

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

	init(type: TextFieldCellType, placeholder: String? = nil) {
		self.textFielCellType = type
		self.input = Bindable("")
		self.placeholder = placeholder
	}
}
