//
//  ButtonCellViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 29.07.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import UIKit

class ButtonCellViewModel<T>: BindableTableViewCellViewModel {
	override var type: ConfigurableTableViewCell.Type { ButtonTableViewCell.self }
	let action: T
	init(action: T, title: String, titleTextColor: UIColor? = .cryptomatorPrimary, detailTitle: String? = nil, isEnabled: Bool = true, selectionStyle: UITableViewCell.SelectionStyle = .default, accessoryType: UITableViewCell.AccessoryType = .none) {
		self.action = action
		super.init(title: title, titleTextColor: titleTextColor, detailTitle: detailTitle, isEnabled: isEnabled, selectionStyle: selectionStyle, accessoryType: accessoryType)
	}

	static func createDisclosureButton(action: T, title: String, detailTitle: String? = nil, accessoryType: UITableViewCell.AccessoryType = .disclosureIndicator, isEnabled: Bool = true) -> ButtonCellViewModel<T> {
		return ButtonCellViewModel(action: action, title: title, titleTextColor: nil, detailTitle: detailTitle, isEnabled: isEnabled, accessoryType: accessoryType)
	}
}

class ButtonTableViewCell: TableViewCell {
	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: .value1, reuseIdentifier: reuseIdentifier)
	}
}
