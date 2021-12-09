//
//  AccountCellContent.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 20.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation

class AccountCellContent: TableViewCellViewModel {
	let mainLabelText: String
	let detailLabelText: String?

	init(mainLabelText: String, detailLabelText: String?) {
		self.mainLabelText = mainLabelText
		self.detailLabelText = detailLabelText
	}

	override func hash(into hasher: inout Hasher) {
		hasher.combine(mainLabelText)
		hasher.combine(detailLabelText)
	}
}
