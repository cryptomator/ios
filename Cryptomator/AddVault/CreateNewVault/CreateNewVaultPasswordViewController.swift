//
//  CreateNewVaultPasswordViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 18.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import UIKit

class CreateNewVaultPasswordViewController: StaticUITableViewController<CreateNewVaultPasswordSection> {
	weak var coordinator: (Coordinator & VaultInstalling)?
	private let viewModel: CreateNewVaultPasswordViewModelProtocol

	init(viewModel: CreateNewVaultPasswordViewModelProtocol) {
		self.viewModel = viewModel
		super.init(viewModel: viewModel)
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		let createButton = UIBarButtonItem(title: LocalizedString.getValue("common.button.create"), style: .done, target: self, action: #selector(createNewVault))
		navigationItem.rightBarButtonItem = createButton
		tableView.rowHeight = 44
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

	// MARK: - UITableViewDelegate

	override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
		// Prevents the header title from being displayed in uppercase
		guard let headerView = view as? UITableViewHeaderFooterView else {
			return
		}
		headerView.textLabel?.text = viewModel.getHeaderTitle(for: section)
	}
}

#if DEBUG
/*
 import Promises
 import SwiftUI

 private class CreateNewVaultPasswordViewModelMock: CreateNewVaultPasswordViewModelProtocol {
 	let vaultUID = ""
 	let vaultName = ""

 	let headerTitles = ["Enter a new password.", "Confirm the new password."]
 	var password: String?
 	var confirmingPassword: String?
 	func createNewVault() -> Promise<Void> {
 		return Promise(())
 	}

 	func validatePassword() throws {}
 }

 struct CreateNewVaultPasswordVC_Preview: PreviewProvider {
 	static var previews: some View {
 		CreateNewVaultPasswordViewController(viewModel: CreateNewVaultPasswordViewModelMock()).toPreview()
 	}
 }*/
#endif
