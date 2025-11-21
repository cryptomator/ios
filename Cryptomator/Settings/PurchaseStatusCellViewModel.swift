//
//  PurchaseStatusCellViewModel.swift
//  Cryptomator
//
//  Created by Majid Achhoud on 20.11.24.
//  Copyright © 2024 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import UIKit

class PurchaseStatusCellViewModel: TableViewCellViewModel {
	override var type: ConfigurableTableViewCell.Type { PurchaseStatusCell.self }

	let iconName: String
	let title: Bindable<String?>
	let subtitle: Bindable<String?>

	init(iconName: String, title: String, subtitle: String) {
		self.iconName = iconName
		self.title = Bindable(title)
		self.subtitle = Bindable(subtitle)
	}
}
