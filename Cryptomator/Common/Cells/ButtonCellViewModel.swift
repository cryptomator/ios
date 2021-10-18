//
//  ButtonCellViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 29.07.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import UIKit

class ButtonCellViewModel<T>: TableViewCellViewModel {
	let action: T
	init(action: T, title: String, titleTextColor: UIColor? = UIColor(named: "primary"), isEnabled: Bool = true, selectionStyle: UITableViewCell.SelectionStyle = .default, accessoryType: UITableViewCell.AccessoryType = .none) {
		self.action = action
		super.init(title: title, titleTextColor: titleTextColor, isEnabled: isEnabled, selectionStyle: selectionStyle, accessoryType: accessoryType)
	}

	static func createDisclosureButton(action: T, title: String, accessoryType: UITableViewCell.AccessoryType = .disclosureIndicator, isEnabled: Bool = true) -> ButtonCellViewModel<T> {
		return ButtonCellViewModel(action: action, title: title, titleTextColor: nil, isEnabled: isEnabled, accessoryType: accessoryType)
	}
}
