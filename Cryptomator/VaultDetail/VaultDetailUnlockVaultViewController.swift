//
//  VaultDetailUnlockVaultViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 04.08.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import CryptomatorCryptoLib
import UIKit

class VaultDetailUnlockVaultViewController: SingleSectionTableViewController {
	weak var coordinator: (Coordinator & VaultPasswordVerifying)?
	lazy var enableButton: UIBarButtonItem = {
		let button = UIBarButtonItem(title: LocalizedString.getValue("common.button.enable"), style: .done, target: self, action: #selector(verify))
		button.isEnabled = false
		return button
	}()

	private var viewModel: VaultDetailUnlockVaultViewModel

	private var viewToShake: UIView? {
		return navigationController?.view.superview // shake the whole modal dialog
	}

	init(viewModel: VaultDetailUnlockVaultViewModel) {
		self.viewModel = viewModel
		super.init()
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = viewModel.title
		navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
		navigationItem.rightBarButtonItem = enableButton
		tableView.register(PasswordFieldCell.self, forCellReuseIdentifier: "PasswordFieldCell")
		tableView.rowHeight = 44
	}

	override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
		super.viewWillTransition(to: size, with: coordinator)
		viewToShake?.cancelShaking()
	}

	@objc func cancel() {
		coordinator?.cancel()
	}

	@objc func verify() {
		do {
			try viewModel.unlockVault()
			coordinator?.verifiedVaultPassword()
		} catch MasterkeyFileError.invalidPassphrase {
			viewToShake?.shake()
		} catch {
			coordinator?.handleError(error, for: self)
		}
	}

	@objc func textFieldDidChange(_ textField: UITextField) {
		viewModel.password = textField.text
		if textField.text?.isEmpty ?? true {
			enableButton.isEnabled = false
		} else {
			enableButton.isEnabled = true
		}
	}

	// MARK: - UITableViewDataSource

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return 1
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		// swiftlint:disable:next force_cast
		let cell = tableView.dequeueReusableCell(withIdentifier: "PasswordFieldCell", for: indexPath) as! PasswordFieldCell
		cell.textField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
		cell.textField.becomeFirstResponder()
		return cell
	}

	override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
		return viewModel.footerTitle
	}
}
