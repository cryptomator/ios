//
//  RenameVaultViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 20.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import UIKit

class RenameVaultViewController: SetVaultNameViewController {
	private let viewModel: RenameVaultViewModel

	init(viewModel: RenameVaultViewModel) {
		self.viewModel = viewModel
		super.init(viewModel: viewModel)
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		let renameButton = UIBarButtonItem(title: LocalizedString.getValue("vaultDetail.button.renameVault"), style: .done, target: self, action: #selector(renameButtonClicked))
		navigationItem.rightBarButtonItem = renameButton
	}

	@objc private func renameButtonClicked() {
		viewModel.renameVault().then { [weak self] in
			guard let self = self else {
				return
			}
			self.coordinator?.setVaultName(self.viewModel.vaultName ?? "")
		}.catch { [weak self] error in
			guard let self = self else {
				return
			}
			self.coordinator?.handleError(error, for: self)
		}
	}
}
