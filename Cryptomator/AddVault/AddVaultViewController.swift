//
//  AddVaultViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 12.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation
import UIKit

class AddVaultViewController: UITableViewController {
	weak var coordinator: AddVaultCoordinator?

	override func loadView() {
		tableView = UITableView(frame: .zero, style: .grouped)
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = NSLocalizedString("addVault.title", comment: "")
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
			text = NSLocalizedString("addVault.createNewVault.title", comment: "")
		case 1:
			text = NSLocalizedString("addVault.openExistingVault.title", comment: "")
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
		let headerView = UIView()
		let cryptoBotImage = UIImage(named: "bot")
		let imageView = UIImageView(image: cryptoBotImage)
		headerView.addSubview(imageView)

		imageView.contentMode = .scaleAspectFit
		imageView.translatesAutoresizingMaskIntoConstraints = false
		NSLayoutConstraint.activate([
			imageView.leadingAnchor.constraint(equalTo: headerView.layoutMarginsGuide.leadingAnchor),
			imageView.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -20),
			imageView.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 20),
			imageView.trailingAnchor.constraint(equalTo: headerView.layoutMarginsGuide.trailingAnchor)
		])

		return headerView
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
import CryptomatorCloudAccess
import SwiftUI

struct VaultAddVCPreview: PreviewProvider {
	static var previews: some View {
		AddVaultViewController().toPreview()
	}
}
#endif
