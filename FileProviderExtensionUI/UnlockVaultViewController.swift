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
import LocalAuthentication
import Promises
import UIKit

class UnlockVaultViewController: UITableViewController {
	weak var coordinator: FileProviderCoordinator?
	private let viewModel: UnlockVaultViewModel
	private lazy var passwordCell: PasswordFieldCell = {
		let cell = PasswordFieldCell()
		cell.textField.becomeFirstResponder()
		cell.textField.tintColor = .cryptomatorPrimary
		cell.textField.delegate = self
		cell.selectionStyle = .none
		return cell
	}()

	private lazy var button: UITableViewCell = {
		let cell = UITableViewCell()
		return cell
	}()

	private lazy var enableBiometricalUnlockCell: UITableViewCell = {
		let cell = UITableViewCell()
		cell.accessoryView = enableBiometricalUnlockSwitch
		return cell
	}()

	private lazy var enableBiometricalUnlockSwitch: UISwitch = {
		let switchView = UISwitch(frame: .zero)
		switchView.setOn(false, animated: false)
		return switchView
	}()

	private var viewToShake: UIView? {
		return navigationController?.view.superview // shake the whole modal dialog
	}

	init(viewModel: UnlockVaultViewModel) {
		self.viewModel = viewModel
		super.init(style: .insetGrouped)
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
		super.viewDidLoad()
		title = viewModel.title
		let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
		let unlockButton = UIBarButtonItem(title: LocalizedString.getValue("unlockVault.button.unlock"), style: .done, target: self, action: #selector(unlock))
		navigationItem.leftBarButtonItem = cancelButton
		navigationItem.rightBarButtonItem = unlockButton
		tableView.backgroundColor = .cryptomatorBackground
		tableView.cellLayoutMarginsFollowReadableWidth = true
	}

	private func biometricalUnlock() {
		viewModel.biometricalUnlock().then { [weak self] in
			self?.coordinator?.done()
		}
	}

	@objc func unlock() {
		let hud = ProgressHUD()
		hud.text = LocalizedString.getValue("unlockVault.progress")
		hud.show(presentingViewController: self)
		hud.showLoadingIndicator()
		viewModel.unlock(withPassword: passwordCell.textField.text ?? "", storePasswordInKeychain: enableBiometricalUnlockSwitch.isOn).then {
			hud.transformToSelfDismissingSuccess()
		}.then { [weak self] in
			self?.coordinator?.done()
		}.catch { [weak self] error in
			if case LAError.userFallback = error {
				// Do not show the fallback action as an error
			} else {
				self?.handleError(error, hud: hud)
			}
		}
	}

	@objc func cancel() {
		coordinator?.userCancelled()
	}

	func handleError(_ error: Error, hud: ProgressHUD) {
		hud.dismiss(animated: true).then { [weak self] in
			self?.handleError(error)
		}
	}

	func handleError(_ error: Error) {
		switch error {
		case let error as NSError where error.code == (MasterkeyFileError.invalidPassphrase as NSError).code && error.domain == (MasterkeyFileError.invalidPassphrase as NSError).domain:
			viewToShake?.shake()
		default:
			coordinator?.handleError(error, for: self)
		}
	}

	override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
		return viewModel.getFooterTitle(for: section)
	}

	// MARK: - UITableViewDataSource

	override func numberOfSections(in tableView: UITableView) -> Int {
		return viewModel.numberOfSections
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return viewModel.numberOfRows(in: section)
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		switch viewModel.getCellType(for: indexPath) {
		case .biometricalUnlock:
			tableView.deselectRow(at: indexPath, animated: true)
			biometricalUnlock()
		case .password, .enableBiometricalUnlock, .unknown:
			break
		}
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		switch viewModel.getCellType(for: indexPath) {
		case .password:
			return passwordCell
		case .biometricalUnlock:
			button.textLabel?.text = viewModel.getTitle(for: indexPath)
			if let systemImageName = viewModel.getSystemImageName(for: indexPath) {
				button.imageView?.image = UIImage(systemName: systemImageName)
				button.imageView?.tintColor = .cryptomatorPrimary
			}
			return button
		case .enableBiometricalUnlock:
			enableBiometricalUnlockCell.textLabel?.text = viewModel.getTitle(for: indexPath)
			enableBiometricalUnlockSwitch.isOn = viewModel.enableBiometricalUnlockIsOn
			return enableBiometricalUnlockCell
		case .unknown:
			return UITableViewCell()
		}
	}
}

extension UnlockVaultViewController: UITextFieldDelegate {
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		unlock()
		return false
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
			textField.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
			textField.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor)
		])
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}
