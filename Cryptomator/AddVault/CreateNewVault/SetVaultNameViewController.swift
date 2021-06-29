//
//  SetVaultNameViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 16.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import UIKit

class SetVaultNameViewController: SingleSectionHeaderTableViewController {
	weak var coordinator: (VaultNaming & Coordinator)?
	private var viewModel: SetVaultNameViewModelProtocol
	private lazy var nameCell: TextFieldCell = {
		let cell = TextFieldCell()
		cell.textField.placeholder = NSLocalizedString("setVaultName.cells.name", comment: "")
		cell.textField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
		cell.textField.becomeFirstResponder()
		return cell
	}()

	init(viewModel: SetVaultNameViewModelProtocol) {
		self.viewModel = viewModel
		super.init(with: viewModel)
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		let doneButton = UIBarButtonItem(title: NSLocalizedString("common.button.next", comment: ""), style: .done, target: self, action: #selector(nextButtonClicked))
		navigationItem.rightBarButtonItem = doneButton
		tableView.rowHeight = 44
	}

	@objc func nextButtonClicked() {
		do {
			coordinator?.setVaultName(try viewModel.getValidatedVaultName())
		} catch {
			coordinator?.handleError(error, for: self)
		}
	}

	@objc func textFieldDidChange(_ textField: UITextField) {
		viewModel.vaultName = textField.text
	}

	// MARK: - UITableViewDataSource

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return 1
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		return nameCell
	}
}

#if DEBUG
import SwiftUI

struct SetVaultNameVCPreview: PreviewProvider {
	static var previews: some View {
		SetVaultNameViewController(viewModel: SetVaultNameViewModel()).toPreview()
	}
}
#endif
