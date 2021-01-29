//
//  OpenExistingVaultPasswordViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 27.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CloudAccessPrivateCore
import CryptomatorCloudAccess
import UIKit
class OpenExistingVaultPasswordViewController: UITableViewController {
	lazy var verifyButton: UIBarButtonItem = {
		let button = UIBarButtonItem(title: "Verify", style: .plain, target: self, action: #selector(verify))
		button.isEnabled = false
		return button
	}()

	private var viewModel: OpenExistingVaultPasswordViewModelProtocol

	init(viewModel: OpenExistingVaultPasswordViewModelProtocol) {
		self.viewModel = viewModel
		super.init(nibName: nil, bundle: nil)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func loadView() {
		tableView = UITableView(frame: .zero, style: .grouped)
		tableView.register(PasswordFieldCell.self, forCellReuseIdentifier: "PasswordFieldCell")
		tableView.rowHeight = 44
		navigationItem.rightBarButtonItem = verifyButton
	}

	@objc func verify() {
		viewModel.addVault().then {
			#warning("TODO: Add Coordinator")
		}.catch { _ in
			#warning("TODO: Add Coordinator")
			#warning("TODO: Add Shake Animation")
		}
	}

	@objc func textFieldDidChange(_ textField: UITextField) {
		viewModel.password = textField.text
		if textField.text?.isEmpty ?? true {
			verifyButton.isEnabled = false
		} else {
			verifyButton.isEnabled = true
		}
	}

	override func numberOfSections(in tableView: UITableView) -> Int {
		1
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		1
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "PasswordFieldCell", for: indexPath) as! PasswordFieldCell
		cell.textField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
		return cell
	}

	override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
		viewModel.footerTitle
	}
}

#if canImport(SwiftUI) && DEBUG
import Promises
import SwiftUI
private class OpenExistingVaultMasterkeyProcessingViewModelMock: OpenExistingVaultPasswordViewModelProtocol {
	var password: String?
	var footerTitle : String {
		"Enter password for \"\(vaultName)\""
	}
	let vaultName = "Work"
	
	func addVault() -> Promise<Void> {
		Promise(())
	}
}

@available(iOS 13, *)
struct OpenExistingVaultMasterkeyProcessingVC_Preview: PreviewProvider {
	static var previews: some View {
		OpenExistingVaultPasswordViewController(viewModel: OpenExistingVaultMasterkeyProcessingViewModelMock()).toPreview()
	}
}
#endif
