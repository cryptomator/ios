//
//  CreateNewVaultPasswordViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 18.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import UIKit

class CreateNewVaultPasswordViewController: UITableViewController {
	weak var coordinator: (Coordinator & VaultInstalling)?
	private var viewModel: CreateNewVaultPasswordViewModelProtocol
	private lazy var cells: [UITableViewCell] = {
		[passwordCell, confirmingPasswordCell]
	}()

	private lazy var passwordCell: PasswordFieldCell = {
		let cell = PasswordFieldCell()
		cell.textField.addTarget(self, action: #selector(passwordFieldDidChange), for: .editingChanged)
		cell.textField.becomeFirstResponder()
		return cell
	}()

	private lazy var confirmingPasswordCell: PasswordFieldCell = {
		let cell = PasswordFieldCell()
		cell.textField.addTarget(self, action: #selector(confirmingPasswordFieldDidChange), for: .editingChanged)
		return cell
	}()

	private lazy var createButton: UIBarButtonItem = {
		let button = UIBarButtonItem(title: NSLocalizedString("common.button.create", comment: ""), style: .done, target: self, action: #selector(createNewVault))
		return button
	}()

	init(viewModel: CreateNewVaultPasswordViewModelProtocol) {
		self.viewModel = viewModel
		super.init(nibName: nil, bundle: nil)
	}

	override func loadView() {
		tableView = UITableView(frame: .zero, style: .grouped)
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = NSLocalizedString("addVault.createNewVault.title", comment: "")
		navigationItem.rightBarButtonItem = createButton
		tableView.rowHeight = 44
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	@objc func passwordFieldDidChange(_ textField: UITextField) {
		viewModel.password = textField.text
	}

	@objc func confirmingPasswordFieldDidChange(_ textField: UITextField) {
		viewModel.confirmingPassword = textField.text
	}

	@objc func createNewVault() {
		do {
			try viewModel.validatePassword()
		} catch {
			coordinator?.handleError(error, for: self)
			return
		}
		let alertController = UIAlertController(title: NSLocalizedString("addVault.createNewVault.password.confirmPassword.alert.title", comment: ""), message: NSLocalizedString("addVault.createNewVault.password.confirmPassword.alert.message", comment: ""), preferredStyle: .alert)
		let okAction = UIAlertAction(title: NSLocalizedString("common.button.confirm", comment: ""), style: .default) { _ in
			self.userConfirmedPassword()
		}

		alertController.addAction(okAction)
		alertController.addAction(UIAlertAction(title: NSLocalizedString("common.button.cancel", comment: ""), style: .cancel))

		present(alertController, animated: true, completion: nil)
	}

	private func userConfirmedPassword() {
		viewModel.createNewVault().then { [weak self] in
			guard let self = self else { return }
			self.coordinator?.showSuccessfullyAddedVault(withName: self.viewModel.vaultName, vaultUID: self.viewModel.vaultUID)
		}.catch { [weak self] error in
			guard let self = self else { return }
			self.coordinator?.handleError(error, for: self)
		}
	}

	// MARK: - UITableViewDataSource

	override func numberOfSections(in tableView: UITableView) -> Int {
		return 2
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return 1
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		return cells[indexPath.section]
	}

	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		return viewModel.headerTitles[section]
	}

	// MARK: - UITableViewDelegate

	override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
		// Prevents the header title from being displayed in uppercase
		guard let headerView = view as? UITableViewHeaderFooterView else {
			return
		}
		headerView.textLabel?.text = viewModel.headerTitles[section]
	}
}

#if DEBUG
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
}
#endif
