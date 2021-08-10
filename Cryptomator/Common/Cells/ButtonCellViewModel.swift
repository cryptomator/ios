//
//  ButtonCellViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 29.07.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import UIKit

class ButtonCellViewModel<T>: TableViewCellViewModel {
	var type: TableViewCell.Type {
		return TableViewCell.self
	}

	let title: Bindable<String?>
	let titleTextColor: Bindable<UIColor?>
	let detailTitle: Bindable<String?> = Bindable(nil)
	let detailTitleTextColor: Bindable<UIColor?> = Bindable(nil)
	let image: Bindable<UIImage?> = Bindable(nil)
	var isEnabled: Bindable<Bool>
	let selectionStyle: Bindable<UITableViewCell.SelectionStyle>

	let action: T
	init(action: T, title: String, titleTextColor: UIColor? = UIColor(named: "primary"), isEnabled: Bool = true, selectionStyle: UITableViewCell.SelectionStyle = .default) {
		self.action = action
		self.title = Bindable(title)
		self.titleTextColor = Bindable(titleTextColor)
		self.isEnabled = Bindable(isEnabled)
		self.selectionStyle = Bindable(selectionStyle)
	}
}
