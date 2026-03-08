//
//  ButtonCellViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 29.07.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import UIKit

class ButtonCellViewModel<T>: BindableTableViewCellViewModel {
	private let preferredCellStyle: UITableViewCell.CellStyle
	override var cellStyle: UITableViewCell.CellStyle {
		preferredCellStyle
	}

	let action: T
	init(action: T, title: String, titleTextColor: UIColor? = .cryptomatorPrimary, detailTitle: String? = nil, image: UIImage? = nil, isEnabled: Bool = true, selectionStyle: UITableViewCell.SelectionStyle = .default, accessoryType: UITableViewCell.AccessoryType = .none, cellStyle: UITableViewCell.CellStyle = .value1) {
		self.action = action
		self.preferredCellStyle = cellStyle
		super.init(title: title, titleTextColor: titleTextColor, detailTitle: detailTitle, image: image, isEnabled: isEnabled, selectionStyle: selectionStyle, accessoryType: accessoryType)
	}

	static func createDisclosureButton(action: T, title: String, detailTitle: String? = nil, image: UIImage? = nil, accessoryType: UITableViewCell.AccessoryType = .disclosureIndicator, isEnabled: Bool = true, cellStyle: UITableViewCell.CellStyle = .value1) -> ButtonCellViewModel<T> {
		return ButtonCellViewModel(action: action, title: title, titleTextColor: nil, detailTitle: detailTitle, image: image, isEnabled: isEnabled, accessoryType: accessoryType, cellStyle: cellStyle)
	}
}
