//
//  AccountListViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 19.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommon
import CryptomatorCommonCore
import Foundation
import Promises
import UIKit

class AccountListViewController: ListViewController<AccountCellContent> {
	weak var coordinator: (Coordinator & AccountListing)?
	private let viewModel: AccountListViewModelProtocol

	init(with viewModel: AccountListViewModelProtocol) {
		self.viewModel = viewModel
		super.init(viewModel: viewModel)
		header.editButton.addTarget(self, action: #selector(editButtonToggled), for: .touchUpInside)

		let addNewVaulButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addNewAccount))
		navigationItem.rightBarButtonItem = addNewVaulButton
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = viewModel.title
	}

	override func setEditing(_ editing: Bool, animated: Bool) {
		super.setEditing(editing, animated: animated)
		header.isEditing = editing
	}

	override func registerCells() {
		tableView.register(AccountCell.self, forCellReuseIdentifier: "AccountCell")
	}

	override func configureDataSource() {
		dataSource = EditableDataSource(tableView: tableView, cellProvider: { tableView, _, accountCellContent in
			let cell = tableView.dequeueReusableCell(withIdentifier: "AccountCell") as? AccountCell
			if #available(iOS 14, *) {
				cell?.account = accountCellContent
				cell?.setNeedsUpdateConfiguration()
			} else {
				cell?.configure(with: accountCellContent)
			}
			cell?.accessoryButton.primaryAction = self.showLogoutActionSheet
			return cell
		})
	}

	func showLogoutActionSheet(_ sender: UIButton) {
		guard let sender = sender as? AccountCellButton else {
			return
		}
		sender.setSelected(true)

		let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

		let removeAction = UIAlertAction(title: viewModel.removeAlert.confirmButtonText, style: .destructive, handler: { _ in
			self.presentUserConfirmationForLogout().then {
				self.handleLogout(sender)
			}.always {
				sender.setSelected(false)
			}
		})
		let cancelAction = UIAlertAction(title: LocalizedString.getValue("common.button.cancel"), style: .cancel, handler: { _ in
			sender.setSelected(false)
		})
		if let accountCellContent = sender.cell?.account, let indexPath = dataSource?.indexPath(for: accountCellContent), supportsEditing(viewModel.accountInfos[indexPath.row].cloudProviderType) {
			let accountInfo = viewModel.accountInfos[indexPath.row]
			let editAction = UIAlertAction(title: LocalizedString.getValue("common.button.edit"), style: .default) { [weak self] _ in
				sender.setSelected(false)
				self?.coordinator?.showEdit(for: accountInfo)
			}
			actionSheet.addAction(editAction)
		}
		actionSheet.addAction(removeAction)
		actionSheet.addAction(cancelAction)
		actionSheet.popoverPresentationController?.sourceView = sender
		actionSheet.popoverPresentationController?.sourceRect = sender.bounds
		present(actionSheet, animated: true)
	}

	@objc func addNewAccount() {
		setEditing(false, animated: true)
		coordinator?.showAddAccount(for: viewModel.cloudProviderType, from: self)
	}

	// MARK: - UITableViewDelegate

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)
		let accountInfo = viewModel.accountInfos[indexPath.row]
		do {
			try coordinator?.selectedAccont(accountInfo)
		} catch {
			coordinator?.handleError(error, for: self)
		}
	}

	// MARK: - Internal

	private func handleLogout(_ sender: AccountCellButton) {
		guard let accountCellContent = sender.cell?.account, let indexPath = dataSource?.indexPath(for: accountCellContent) else {
			return
		}
		do {
			try removeRow(at: indexPath)
		} catch {
			handleError(error)
		}
		sender.setSelected(false)
	}

	private func presentUserConfirmationForLogout() -> Promise<Void> {
		let pendingPromise = Promise<Void>.pending()
		let alertController = UIAlertController(title: viewModel.removeAlert.title, message: viewModel.removeAlert.message, preferredStyle: .alert)
		let logoutAction = UIAlertAction(title: viewModel.removeAlert.confirmButtonText, style: .destructive, handler: { _ in pendingPromise.fulfill(()) })
		let cancelAction = UIAlertAction(title: LocalizedString.getValue("common.button.cancel"), style: .cancel, handler: { _ in pendingPromise.reject(CocoaError(.userCancelled)) })
		alertController.addAction(logoutAction)
		alertController.addAction(cancelAction)
		present(alertController, animated: true)
		return pendingPromise
	}

	private func supportsEditing(_ cloudProviderType: CloudProviderType) -> Bool {
		switch cloudProviderType {
		case .dropbox, .googleDrive, .localFileSystem, .oneDrive, .pCloud:
			return false
		case .s3, .webDAV:
			return true
		}
	}
}

#if DEBUG

import Combine
import CryptomatorCommonCore
import Promises
import SwiftUI

private class AccountListViewModelMock: AccountListViewModelProtocol {
	let removeAlert = ListViewModelAlertContent(title: "", message: "", confirmButtonText: "")

	let headerTitle = "Accounts"

	let emptyListMessage = ""

	func startListenForChanges() -> AnyPublisher<Result<[TableViewCellViewModel], Error>, Never> {
		Just(.success(accounts)).eraseToAnyPublisher()
	}

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
