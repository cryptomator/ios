//
//  AccountListViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 19.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation
import UIKit
	private let header = TableViewHeader(title: "Authentications".uppercased(), editButtonTitle: "Edit")
class AccountListViewController: SingleSectionTableViewController {
	private let viewModel: AccountListViewModelProtocol
	weak var coordinator: (Coordinator & AccountListing)?

	init(with viewModel: AccountListViewModelProtocol) {
		self.viewModel = viewModel
		super.init()
		header.editButton.addTarget(self, action: #selector(editButtonToggled), for: .touchUpInside)

		let addNewVaulButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addNewAccount))
		navigationItem.rightBarButtonItem = addNewVaulButton
	}

	override func loadView() {
		super.loadView()
		title = viewModel.title
	}

	override func viewDidLoad() {
		tableView.register(AccountCell.self, forCellReuseIdentifier: "AccountCell")
		viewModel.startListenForChanges { [weak self] error in
			guard let self = self else { return }
			self.coordinator?.handleError(error, for: self)
		} onChange: { [weak self] in
			guard let self = self else { return }
			self.tableView.reloadData()
			if self.viewModel.accounts.isEmpty {
				self.tableView.backgroundView = EmptyListMessage(message: "Tap here to add an account")
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

	// TODO: Refactor this & VaultListVC and subclass
	@objc func editButtonToggled() {
		tableView.setEditing(!tableView.isEditing, animated: true)
		UIView.performWithoutAnimation {
			header.editButton.setTitle(tableView.isEditing ? "Done" : "Edit", for: .normal)
			header.editButton.layoutIfNeeded()
		}
	}

	@objc func showLogoutActionSheet(sender: AccountCellButton) {
		guard let cell = sender.cell, let indexpath = tableView.indexPath(for: cell) else {
			return
		}
		sender.setSelected(true)
		#warning("TODO: Add Coordinator")
	}

	@objc func addNewAccount() {
		coordinator?.showAddAccount(for: viewModel.cloudProviderType, from: self)
	}

	// MARK: TableView

	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		guard !viewModel.accounts.isEmpty else {
			return nil
		}
		return header
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return viewModel.accounts.count
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
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

	override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
		do {
			try viewModel.moveRow(at: sourceIndexPath.row, to: destinationIndexPath.row)
		} catch {
			coordinator?.handleError(error, for: self)
		}
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let accountInfo = viewModel.accountInfos[indexPath.row]
		do {
			try coordinator?.selectedAccont(accountInfo)
		} catch {
			coordinator?.handleError(error, for: self)
		}
	}
}

#if canImport(SwiftUI) && DEBUG
import CloudAccessPrivateCore
import CryptomatorCloudAccess
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

@available(iOS 13, *)
struct AccountListVCPreview: PreviewProvider {
	static var previews: some View {
		AccountListViewController(with: AccountListViewModelMock()).toPreview()
	}
}
#endif
