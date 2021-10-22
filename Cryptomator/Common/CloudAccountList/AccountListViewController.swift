//
//  AccountListViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 19.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Foundation
import UIKit

class AccountListViewController: SingleSectionTableViewController {
	weak var coordinator: (Coordinator & AccountListing)?

	private let viewModel: AccountListViewModelProtocol
	private let header = EditableTableViewHeader(title: LocalizedString.getValue("accountList.header.title"))

	init(with viewModel: AccountListViewModelProtocol) {
		self.viewModel = viewModel
		super.init()
		header.editButton.addTarget(self, action: #selector(editButtonToggled), for: .touchUpInside)

		let addNewVaulButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addNewAccount))
		navigationItem.rightBarButtonItem = addNewVaulButton
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = viewModel.title
		tableView.register(AccountCell.self, forCellReuseIdentifier: "AccountCell")
		viewModel.startListenForChanges { [weak self] error in
			guard let self = self else { return }
			self.coordinator?.handleError(error, for: self)
		} onChange: { [weak self] in
			guard let self = self else { return }
			self.tableView.reloadData()
			if self.viewModel.accounts.isEmpty {
				self.tableView.backgroundView = EmptyListMessage(message: LocalizedString.getValue("accountList.emptyList.message"))
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

	// TODO: Refactor this & VaultListVC and subclass
	@objc func editButtonToggled() {
		setEditing(!isEditing, animated: true)
	}

	@objc func showLogoutActionSheet(sender: AccountCellButton) {
		// swiftlint:disable:next unused_optional_binding
		guard let cell = sender.cell, let _ = tableView.indexPath(for: cell) else {
			return
		}
		sender.setSelected(true)
		#warning("TODO: Add Coordinator")
	}

	@objc func addNewAccount() {
		setEditing(false, animated: true)
		coordinator?.showAddAccount(for: viewModel.cloudProviderType, from: self)
	}

	// MARK: - UITableViewDataSource

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return viewModel.accounts.count
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		// swiftlint:disable:next force_cast
		let cell = tableView.dequeueReusableCell(withIdentifier: "AccountCell", for: indexPath) as! AccountCell
		let account = viewModel.accounts[indexPath.row]
		if #available(iOS 14, *) {
			cell.account = account
			cell.setNeedsUpdateConfiguration()
		} else {
			cell.configure(with: account)
		}
		cell.accessoryButton.addTarget(self, action: #selector(showLogoutActionSheet), for: .touchUpInside)
		return cell
	}

	override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
		if editingStyle == .delete {
			let alertController = UIAlertController(title: LocalizedString.getValue("accountList.signOut.alert.title"), message: LocalizedString.getValue("accountList.signOut.alert.message"), preferredStyle: .alert)
			let okAction = UIAlertAction(title: LocalizedString.getValue("common.button.signOut"), style: .destructive) { _ in
				do {
					try self.viewModel.removeRow(at: indexPath.row)
					tableView.deleteRows(at: [indexPath], with: .automatic)
				} catch {
					self.coordinator?.handleError(error, for: self)
				}
			}
			alertController.addAction(okAction)
			alertController.addAction(UIAlertAction(title: LocalizedString.getValue("common.button.cancel"), style: .cancel))
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
		guard !viewModel.accounts.isEmpty else {
			return nil
		}
		return header
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)
		let accountInfo = viewModel.accountInfos[indexPath.row]
		do {
			try coordinator?.selectedAccont(accountInfo)
		} catch {
			coordinator?.handleError(error, for: self)
		}
	}
}

#if DEBUG
import CryptomatorCommonCore
import Promises
import SwiftUI

private class AccountListViewModelMock: AccountListViewModelProtocol {
	let cloudProviderType = CloudProviderType.googleDrive

	let accounts = [AccountCellContent(mainLabelText: "John AppleSeed", detailLabelText: "j.appleseed@icloud.com")]
	let accountInfos = [AccountInfo]()
	let title = "Google Drive"

	func refreshItems() -> Promise<Void> { return Promise(()) }
	func moveRow(at sourceIndex: Int, to destinationIndex: Int) throws {}
	func removeRow(at index: Int) throws {}
	func startListenForChanges(onError: @escaping (Error) -> Void, onChange: @escaping () -> Void) {}
}

struct AccountListVCPreview: PreviewProvider {
	static var previews: some View {
		AccountListViewController(with: AccountListViewModelMock()).toPreview()
	}
}
#endif
