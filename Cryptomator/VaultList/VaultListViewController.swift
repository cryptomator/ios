//
//  VaultListViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 04.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Foundation
import UIKit

class VaultListViewController: UITableViewController {
	weak var coordinator: MainCoordinator?

	private let viewModel: VaultListViewModelProtocol
	private let header = EditableTableViewHeader(title: NSLocalizedString("vaultList.header.title", comment: ""))

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
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = "Cryptomator"
		let settingsButton = UIBarButtonItem(image: UIImage(named: "740-gear"), style: .plain, target: self, action: #selector(showSettings))
		navigationItem.leftBarButtonItem = settingsButton
		let addNewVaulButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addNewVault))
		navigationItem.rightBarButtonItem = addNewVaulButton
		header.editButton.addTarget(self, action: #selector(editButtonToggled), for: .touchUpInside)
		tableView.register(VaultCell.self, forCellReuseIdentifier: "VaultCell")
		viewModel.startListenForChanges { [weak self] error in
			guard let self = self else { return }
			self.coordinator?.handleError(error, for: self)
		} onChange: { [weak self] in
			guard let self = self else { return }
			self.tableView.reloadData()
			if self.viewModel.vaults.isEmpty {
				self.tableView.backgroundView = EmptyListMessage(message: NSLocalizedString("vaultList.emptyList.message", comment: ""))
				// Prevents `EmptyListMessage` from being placed under the navigation bar
				self.tableView.contentInsetAdjustmentBehavior = .never
				self.tableView.separatorStyle = .none
			} else {
				self.tableView.backgroundView = nil
				self.tableView.separatorStyle = .singleLine
				self.tableView.contentInsetAdjustmentBehavior = .automatic
			}
		}
	}

	override func setEditing(_ editing: Bool, animated: Bool) {
		super.setEditing(editing, animated: animated)
		header.isEditing = editing
	}

	@objc func addNewVault() {
		setEditing(false, animated: true)
		coordinator?.addVault()
	}

	@objc func showSettings() {
		setEditing(false, animated: true)
		coordinator?.showSettings()
	}

	@objc func editButtonToggled() {
		setEditing(!isEditing, animated: true)
	}

	// MARK: - UITableViewDataSource

	override func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return viewModel.vaults.count
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		// swiftlint:disable:next force_cast
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

	override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
		if editingStyle == .delete {
			let alertController = UIAlertController(title: NSLocalizedString("vaultList.alert.remove.title", comment: ""), message: NSLocalizedString("vaultList.alert.remove.message", comment: ""), preferredStyle: .alert)
			let okAction = UIAlertAction(title: NSLocalizedString("common.button.remove", comment: ""), style: .destructive) { _ in
				do {
					try self.viewModel.removeRow(at: indexPath.row)
					tableView.deleteRows(at: [indexPath], with: .automatic)
				} catch {
					self.coordinator?.handleError(error, for: self)
				}
			}

			alertController.addAction(okAction)
			alertController.addAction(UIAlertAction(title: NSLocalizedString("common.button.cancel", comment: ""), style: .cancel))

			present(alertController, animated: true, completion: nil)
		}
	}

	override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
		do {
			try viewModel.moveRow(at: sourceIndexPath.row, to: destinationIndexPath.row)
		} catch {
			coordinator?.handleError(error, for: self)
		}
	}

	// MARK: - UITableViewDelegate

	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		guard !viewModel.vaults.isEmpty else {
			return nil
		}
		return header
	}
}

#if DEBUG
import CryptomatorCloudAccessCore
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

struct VaultListVCPreview: PreviewProvider {
	static var previews: some View {
		VaultListViewController(with: VaultListViewModelMock()).toPreview()
	}
}
#endif
