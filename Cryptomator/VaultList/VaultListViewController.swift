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
	private let header = EditableTableViewHeader(title: "Vaults", editButtonTitle: "Edit")
	private let viewModel: VaultListViewModelProtocol
	weak var coordinator: MainCoordinator?

	init(with viewModel: VaultListViewModelProtocol) {
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
		tableView.register(VaultCell.self, forCellReuseIdentifier: "VaultCell")
		viewModel.startListenForChanges { [weak self] error in
			guard let self = self else { return }
			self.coordinator?.handleError(error, for: self)
		} onChange: { [weak self] in
			guard let self = self else { return }
			self.tableView.reloadData()
			if self.viewModel.vaults.isEmpty {
				self.tableView.backgroundView = EmptyListMessage(message: "Tap here to add a vault")
				// Prevents the EmptyListMessageView from being placed under the navigation bar.
				self.tableView.contentInsetAdjustmentBehavior = .never
				self.tableView.separatorStyle = .none
			} else {
				self.tableView.backgroundView = nil
				self.tableView.separatorStyle = .singleLine
				self.tableView.contentInsetAdjustmentBehavior = .automatic
			}
		}
	}

	@objc func addNewVault() {
		coordinator?.addVault()
	}

	@objc func showSettings() {}

	@objc func editButtonToggled() {
		tableView.setEditing(!tableView.isEditing, animated: true)
		header.isEditing = tableView.isEditing
	}

	// MARK: TableView

	override func numberOfSections(in tableView: UITableView) -> Int {
		1
	}

	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		guard !viewModel.vaults.isEmpty else {
			return nil
		}
		return header
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return viewModel.vaults.count
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "VaultCell", for: indexPath) as! VaultCell
		let vault = viewModel.vaults[indexPath.row]
		if #available(iOS 14, *) {
			cell.vault = vault
			cell.setNeedsUpdateConfiguration()
		} else {
			cell.configure(with: vault)
		}
		return cell
	}

	override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
		do {
			try viewModel.moveRow(at: sourceIndexPath.row, to: destinationIndexPath.row)
		} catch {
			coordinator?.handleError(error, for: self)
		}
	}

	override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
		if editingStyle == .delete {
			let alertController = UIAlertController(title: "Remove Vault?",
			                                        message: "This will only remove the vault from the vault list. No encrypted data will be deleted. You can re-add the vault later.",
			                                        preferredStyle: .alert)
			let okAction = UIAlertAction(title: "Remove", style: .destructive) {
				_ in
				do {
					try self.viewModel.removeRow(at: indexPath.row)
					tableView.deleteRows(at: [indexPath], with: .automatic)
				} catch {
					self.coordinator?.handleError(error, for: self)
				}
			}

			alertController.addAction(okAction)
			alertController.addAction(UIAlertAction(title: "Cancle", style: .cancel))

			present(alertController, animated: true, completion: nil)
		}
	}
}

#if canImport(SwiftUI) && DEBUG
import CryptomatorCloudAccess
import SwiftUI

private class VaultListViewModelMock: VaultListViewModelProtocol {
	let vaults = [
		VaultInfo(vaultAccount: VaultAccount(vaultUID: "1", delegateAccountUID: "1", vaultPath: CloudPath("/Work")), cloudProviderAccount: CloudProviderAccount(accountUID: "1", cloudProviderType: .webDAV), vaultListPosition: VaultListPosition(position: 1, vaultUID: "1")),

		VaultInfo(vaultAccount: VaultAccount(vaultUID: "2", delegateAccountUID: "2", vaultPath: CloudPath("/Family")), cloudProviderAccount: CloudProviderAccount(accountUID: "2", cloudProviderType: .googleDrive), vaultListPosition: VaultListPosition(position: 2, vaultUID: "2"))
	]

	func refreshItems() throws {}
	func moveRow(at sourceIndex: Int, to destinationIndex: Int) throws {}
	func removeRow(at index: Int) throws {}
	func startListenForChanges(onError: @escaping (Error) -> Void, onChange: @escaping () -> Void) {}
}

@available(iOS 13, *)
struct VaultListVCPreview: PreviewProvider {
	static var previews: some View {
		VaultListViewController(with: VaultListViewModelMock()).toPreview()
	}
}
#endif
