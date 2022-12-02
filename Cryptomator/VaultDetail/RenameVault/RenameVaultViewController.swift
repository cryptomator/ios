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

	override func lastReturnButtonPressedAction() {
		renameButtonClicked()
	}

	@objc private func renameButtonClicked() {
		Task {
			await renameVault()
		}
	}

	private func renameVault() async {
		let hud = ProgressHUD()
		hud.text = LocalizedString.getValue("vaultDetail.renameVault.progress")
		hud.show(presentingViewController: self)
		hud.showLoadingIndicator()
		do {
			try await viewModel.renameVault()
			hud.transformToSelfDismissingSuccess {
				self.coordinator?.setVaultName(self.viewModel.trimmedVaultName)
			}
		} catch {
			handleError(error, coordinator: coordinator, progressHUD: hud)
		}
	}
}
