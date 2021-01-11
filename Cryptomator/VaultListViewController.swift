//
//  VaultListViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 04.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CloudAccessPrivateCore
import Foundation
import UIKit

class VaultListViewController: UITableViewController {
	private let header = HeaderView(title: "Vaults".uppercased(), editButtonTitle: "Edit")
	private let viewModel: VaultListViewModel
	weak var coordinator: MainCoordinator?

	init(with viewModel: VaultListViewModel) {
		self.viewModel = viewModel
		super.init(nibName: nil, bundle: nil)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func loadView() {
		tableView = UITableView(frame: .zero, style: .grouped)

		let settingsButton = UIBarButtonItem(image: UIImage(named: "740-gear"), style: .plain, target: self, action: #selector(showSettings))
		navigationItem.leftBarButtonItem = settingsButton

		let addNewVaulButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addNewVault))
		navigationItem.rightBarButtonItem = addNewVaulButton

		title = "Cryptomator"

		header.editButton.addTarget(self, action: #selector(editButtonToggled), for: .touchUpInside)
	}

	override func viewDidLoad() {
		tableView.register(UITableViewCell.self, forCellReuseIdentifier: "VaultCell")
	}

	@objc func addNewVault() {
		coordinator?.addVault()
	}

	@objc func showSettings() {}

	@objc func editButtonToggled() {
		tableView.isEditing.toggle()
		header.editButton.setTitle(tableView.isEditing ? "Done" : "Edit", for: .normal)
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		do {
			try viewModel.refreshItems()
			tableView.reloadData()
		} catch {
			print(error)
		}
	}

	// MARK: TableView

	override func numberOfSections(in tableView: UITableView) -> Int {
		1
	}

	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		return header
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return viewModel.vaults.count
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "VaultCell", for: indexPath)
		cell.accessoryType = .disclosureIndicator
		let vault = viewModel.vaults[indexPath.row]
		let image = UIImage(for: vault.cloudProviderType)
		if #available(iOS 14, *) {
			var content = cell.defaultContentConfiguration()
			content.text = vault.vaultPath.lastPathComponent
			content.secondaryText = vault.vaultPath.path
			content.secondaryTextProperties.color = .secondaryLabel
			content.image = image
			cell.contentConfiguration = content
		} else {
			cell.textLabel?.text = vault.vaultPath.lastPathComponent
			cell.detailTextLabel?.text = vault.vaultPath.path
			cell.detailTextLabel?.textColor = .white
			cell.imageView?.image = image
		}
		return cell
	}

	override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
		do {
			try viewModel.moveRow(at: sourceIndexPath.row, to: destinationIndexPath.row)
		} catch {
			print(error)
		}
	}

	override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
		if editingStyle == .delete {
			do {
				try viewModel.removeRow(at: indexPath.row)
			} catch {
				print(error)
			}
			tableView.deleteRows(at: [indexPath], with: .automatic)
		}
	}
}

private class HeaderView: UITableViewHeaderFooterView {
	let editButton = UIButton()
	let title = UILabel()

	convenience init(title: String, editButtonTitle: String) {
		self.init()
		self.title.text = title
		editButton.setTitle(editButtonTitle, for: .normal)
	}

	convenience init() {
		self.init(reuseIdentifier: nil)

		editButton.setTitleColor(.systemBlue, for: .normal)
		editButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .footnote)

		title.font = UIFont.preferredFont(forTextStyle: .footnote)

		editButton.translatesAutoresizingMaskIntoConstraints = false
		title.translatesAutoresizingMaskIntoConstraints = false

		contentView.addSubview(editButton)
		contentView.addSubview(title)

		NSLayoutConstraint.activate([
			title.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
			title.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
			title.heightAnchor.constraint(equalTo: contentView.layoutMarginsGuide.heightAnchor),

			editButton.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
			editButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
			editButton.heightAnchor.constraint(equalTo: contentView.layoutMarginsGuide.heightAnchor)

		])
	}
}

#if canImport(SwiftUI) && DEBUG
import CryptomatorCloudAccess
import SwiftUI

private class VaultListViewModelMock: VaultListViewModel {
	let vaults = [
		VaultInfo(vaultAccount: VaultAccount(vaultUID: "1", delegateAccountUID: "1", vaultPath: CloudPath("/Work")), cloudProviderAccount: CloudProviderAccount(accountUID: "1", cloudProviderType: .webDAV), vaultListPosition: VaultListPosition(position: 1, vaultUID: "1")),

		VaultInfo(vaultAccount: VaultAccount(vaultUID: "2", delegateAccountUID: "2", vaultPath: CloudPath("/Family")), cloudProviderAccount: CloudProviderAccount(accountUID: "2", cloudProviderType: .googleDrive), vaultListPosition: VaultListPosition(position: 2, vaultUID: "2"))
	]

	func refreshItems() throws {}
	func moveRow(at sourceIndex: Int, to destinationIndex: Int) throws {}
	func removeRow(at index: Int) throws {}
}

@available(iOS 13, *)
struct VaultListVCPreview: PreviewProvider {
	static var previews: some View {
		VaultListViewController(with: VaultListViewModelMock()).toPreview()
	}
}
#endif
