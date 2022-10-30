//
//  ChangePasswordViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 29.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import CryptomatorCommonCore
import UIKit

class ChangePasswordViewController: StaticUITableViewController<ChangePasswordSection> {
	private let viewModel: ChangePasswordViewModelProtocol
	private lazy var subscriber = Set<AnyCancellable>()
	private lazy var changePasswordButton = UIBarButtonItem(title: LocalizedString.getValue("common.button.change"), style: .done, target: self, action: #selector(changePassword))
	weak var coordinator: (Coordinator & VaultPasswordChanging)?

	init(viewModel: ChangePasswordViewModelProtocol) {
		self.viewModel = viewModel
		super.init(viewModel: viewModel)
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		navigationItem.rightBarButtonItem = changePasswordButton
		viewModel.lastReturnButtonPressed.sink { [weak self] in
			self?.changePassword()
		}.store(in: &subscriber)
	}

	@objc func changePassword() {
		do {
			try viewModel.validatePasswords()
		} catch {
			coordinator?.handleError(error, for: self)
			return
		}
		let alertController = UIAlertController(title: LocalizedString.getValue("addVault.createNewVault.password.confirmPassword.alert.title"), message: LocalizedString.getValue("addVault.createNewVault.password.confirmPassword.alert.message"), preferredStyle: .alert)
		let okAction = UIAlertAction(title: LocalizedString.getValue("common.button.confirm"), style: .default) { _ in
			Task {
				await self.userConfirmedPassword()
			}
		}
		alertController.addAction(okAction)
		alertController.addAction(UIAlertAction(title: LocalizedString.getValue("common.button.cancel"), style: .cancel))
		present(alertController, animated: true, completion: nil)
	}

	private func userConfirmedPassword() async {
		let hud = ProgressHUD()
		hud.text = LocalizedString.getValue("changePassword.progress")
		hud.show(presentingViewController: self)
		hud.showLoadingIndicator()

		do {
			try await viewModel.changePassword()
			hud.transformToSelfDismissingSuccess {
				self.coordinator?.changedPassword()
			}
		} catch {
			handleError(error, coordinator: coordinator, progressHUD: hud)
		}
	}
}
