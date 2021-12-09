//
//  AddVaultViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 12.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Foundation
import UIKit

class AddVaultViewController: BaseUITableViewController {
	weak var coordinator: AddVaultCoordinator?

	override func viewDidLoad() {
		super.viewDidLoad()
		title = LocalizedString.getValue("addVault.title")
		let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(close))
		navigationItem.leftBarButtonItem = cancelButton
		tableView.register(UITableViewCell.self, forCellReuseIdentifier: "AddVaultCell")
	}

	@objc func close() {
		coordinator?.close()
	}

	// MARK: - UITableViewDataSource

	override func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return 2
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "AddVaultCell", for: indexPath)
		cell.accessoryType = .disclosureIndicator
		let text: String
		switch indexPath.row {
		case 0:
			text = LocalizedString.getValue("addVault.createNewVault.title")
		case 1:
			text = LocalizedString.getValue("addVault.openExistingVault.title")
		default:
			return cell
		}
		if #available(iOS 14, *) {
			var content = cell.defaultContentConfiguration()
			content.text = text
			cell.contentConfiguration = content
		} else {
			cell.textLabel?.text = text
		}
		return cell
	}

	// MARK: - UITableViewDelegate

	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		return CryptoBotHeaderFooterView(infoText: nil)
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		switch indexPath.row {
		case 0:
			coordinator?.createNewVault()
		case 1:
			coordinator?.openExistingVault()
		default:
			return
		}
	}
}

#if DEBUG
import SwiftUI

struct VaultAddVCPreview: PreviewProvider {
	static var previews: some View {
		AddVaultViewController().toPreview()
	}
}
#endif
