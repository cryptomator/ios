//
//  AddVaultSuccessViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 11.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Foundation

class AddVaultSuccessViewModel: SingleSectionTableViewModel {
	let vaultName: String
	let vaultUID: String
	override var title: String? {
		return LocalizedString.getValue("addVault.openExistingVault.title")
	}

	override var cells: [TableViewCellViewModel] {
		return [openInFilesAppButtonViewModel]
	}

	private lazy var openInFilesAppButtonViewModel = ButtonCellViewModel(action: "OpenInFilesApp", title: LocalizedString.getValue("common.cells.openInFilesApp"))

	init(vaultName: String, vaultUID: String) {
		self.vaultName = vaultName
		self.vaultUID = vaultUID
	}
}
