//
//  CreateNewVaultPasswordViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 18.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import CryptomatorCommonCore
import UIKit

class CreateNewVaultPasswordViewController: StaticUITableViewController<CreateNewVaultPasswordSection> {
	weak var coordinator: (Coordinator & VaultInstalling)?
	private let viewModel: CreateNewVaultPasswordViewModelProtocol
	private var lastReturnButtonPressedSubscriber: AnyCancellable?

	init(viewModel: CreateNewVaultPasswordViewModelProtocol) {
		self.viewModel = viewModel
		super.init(viewModel: viewModel)
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		let createButton = UIBarButtonItem(title: LocalizedString.getValue("common.button.create"), style: .done, target: self, action: #selector(createNewVault))
		navigationItem.rightBarButtonItem = createButton
		lastReturnButtonPressedSubscriber = viewModel.lastReturnButtonPressed.sink { [weak self] in
			self?.createNewVault()
		}
	}

	@objc func createNewVault() {
		do {
			try viewModel.validatePassword()
		} catch {
			coordinator?.handleError(error, for: self)
			return
		}
		let alertController = UIAlertController(title: LocalizedString.getValue("addVault.createNewVault.password.confirmPassword.alert.title"), message: LocalizedString.getValue("addVault.createNewVault.password.confirmPassword.alert.message"), preferredStyle: .alert)
		let okAction = UIAlertAction(title: LocalizedString.getValue("common.button.confirm"), style: .default) { _ in
			self.userConfirmedPassword()
		}

		alertController.addAction(okAction)
		alertController.addAction(UIAlertAction(title: LocalizedString.getValue("common.button.cancel"), style: .cancel))

		present(alertController, animated: true, completion: nil)
	}

	private func userConfirmedPassword() {
		let hud = ProgressHUD()
		hud.text = LocalizedString.getValue("addVault.createNewVault.progress")
		hud.show(presentingViewController: self)
		hud.showLoadingIndicator()
		viewModel.createNewVault().then {
			hud.transformToSelfDismissingSuccess()
		}.then { [weak self] in
			guard let self = self else { return }
			self.coordinator?.showSuccessfullyAddedVault(withName: self.viewModel.vaultName, vaultUID: self.viewModel.vaultUID)
		}.catch { [weak self] error in
			self?.handleError(error, coordinator: self?.coordinator, progressHUD: hud)
		}
	}
}

#if DEBUG
import CryptomatorCloudAccessCore
import SwiftUI

struct CreateNewVaultPasswordVC_Preview: PreviewProvider {
	static var previews: some View {
		CreateNewVaultPasswordViewController(viewModel: CreateNewVaultPasswordViewModel(vaultPath: CloudPath("/"), account: CloudProviderAccount(accountUID: "123", cloudProviderType: .webDAV(type: .custom)), vaultUID: "456")).toPreview()
	}
}
#endif
