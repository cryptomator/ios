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
	
	override func loadView() {
		tableView = UITableView(frame: .zero, style: .grouped)
		title = "Add Vault"
	}

	override func viewDidLoad() {
		tableView.register(UITableViewCell.self, forCellReuseIdentifier: "AddVaultCell")
	}

	// MARK: TableView

	override func numberOfSections(in tableView: UITableView) -> Int {
		1
	}

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

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return 2
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "AddVaultCell", for: indexPath)
		cell.accessoryType = .disclosureIndicator
		let text: String
		switch indexPath.row {
		case 0:
			text = "Create New Vault"
		case 1:
			text = "Open Existing Vault"
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
}

#if canImport(SwiftUI) && DEBUG
import CryptomatorCloudAccess
import SwiftUI

@available(iOS 13, *)
struct VaultAddVCPreview: PreviewProvider {
	static var previews: some View {
		AddVaultViewController().toPreview()
	}
}
#endif
