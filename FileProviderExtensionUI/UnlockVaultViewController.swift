//
//  UnlockVaultViewController.swift
//  FileProviderExtensionUI
//
//  Created by Philipp Schmid on 02.07.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import CryptomatorCryptoLib
import FileProviderUI
import UIKit

class UnlockVaultViewController: UITableViewController {
	weak var coordinator: FileProviderCoordinator?

	private let viewModel: UnlockVaultViewModel
	private lazy var passwordCell: PasswordFieldCell = {
		let cell = PasswordFieldCell()
		cell.textField.becomeFirstResponder()
		cell.selectionStyle = .none
		return cell
	}()

	private var viewToShake: UIView? {
		return navigationController?.view.superview // shake the whole modal dialog
	}

	init(viewModel: UnlockVaultViewModel) {
		self.viewModel = viewModel
		super.init(style: .grouped)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
		super.viewWillTransition(to: size, with: coordinator)
		viewToShake?.cancelShaking()
	}

	override func viewDidLoad() {
		title = viewModel.title
		let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
		let unlockButton = UIBarButtonItem(title: NSLocalizedString("unlockVault.button.unlock", comment: ""), style: .done, target: self, action: #selector(unlock))

		navigationItem.leftBarButtonItem = cancelButton
		navigationItem.rightBarButtonItem = unlockButton
	}

	@objc func unlock() {
		viewModel.unlock(withPassword: passwordCell.textField.text ?? "").then { [weak self] in
			self?.coordinator?.unlocked()
		}.catch { [weak self] error in
			guard let self = self else { return }
			switch error {
			case let error as NSError where error.isEqual(MasterkeyFileError.invalidPassphrase as NSError):
				self.viewToShake?.shake()
			default:
				self.coordinator?.handleError(error, for: self)
			}
		}
	}

	@objc func cancel() {
		coordinator?.userCancelled()
	}

	override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
		return viewModel.footerTitle
	}

	// MARK: - UITableViewDataSource

	override func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return 1
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		return passwordCell
	}
}

private class PasswordFieldCell: UITableViewCell {
	let textField: UITextField = {
		let textField = UITextField()
		textField.clearButtonMode = .whileEditing
		textField.isSecureTextEntry = true
		textField.textContentType = .password
		return textField
	}()

	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)
		textField.translatesAutoresizingMaskIntoConstraints = false
		contentView.addSubview(textField)
		NSLayoutConstraint.activate([
			textField.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
			textField.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
			textField.topAnchor.constraint(equalTo: topAnchor),
			textField.bottomAnchor.constraint(equalTo: bottomAnchor)
		])
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}
