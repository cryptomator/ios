//
//  ChangePasswordViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 29.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import CryptomatorCommonCore
import UIKit

class ChangePasswordViewController: UITableViewController {
	private let viewModel: ChangePasswordViewModelProtocol
	private lazy var subscriber = Set<AnyCancellable>()
	private lazy var changePasswordButton = UIBarButtonItem(title: LocalizedString.getValue("common.button.change"), style: .done, target: self, action: #selector(changePassword))
	private var dataSource: UITableViewDiffableDataSource<ChangePasswordSection, TableViewCellViewModel>?
	weak var coordinator: (Coordinator & VaultPasswordChanging)?

	init(viewModel: ChangePasswordViewModelProtocol) {
		self.viewModel = viewModel
		super.init(style: .grouped)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = viewModel.title
		navigationItem.rightBarButtonItem = changePasswordButton
		setUpDataSource()
		applySnapshot(sections: viewModel.sections, cells: viewModel.cells)
	}

	@objc func changePassword() {
		do {
			try viewModel.validatePasswords()
		} catch {
			coordinator?.handleError(error, for: self)
			return
		}
		let alertController = UIAlertController(title: LocalizedString.getValue("addVault.createNewVault.password.confirmPassword.alert.title"), message: LocalizedString.getValue("addVault.createNewVault.password.confirmPassword.alert.message"), preferredStyle: .alert)
		let okAction = UIAlertAction(title: LocalizedString.getValue("common.button.confirm"), style: .default) { _ in
			self.userConfirmedPassword()
		}
		alertController.addAction(okAction)
		alertController.addAction(UIAlertAction(title: LocalizedString.getValue("common.button.cancel"), style: .cancel))
		present(alertController, animated: true, completion: nil)
	}

	private func userConfirmedPassword() {
		let hud = ProgressHUD()
		hud.text = LocalizedString.getValue("changePassword.progress")
		hud.show(presentingViewController: self)
		hud.showLoadingIndicator()
		viewModel.changePassword().then {
			hud.transformToSelfDismissingSuccess()
		}.then { [weak self] in
			self?.coordinator?.changedPassword()
		}.catch { [weak self] error in
			self?.handleError(error, coordinator: self?.coordinator, progressHUD: hud)
		}
	}

	override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
		// Prevents the header title from being displayed in uppercase
		guard let headerView = view as? UITableViewHeaderFooterView else {
			return
		}
		headerView.textLabel?.text = viewModel.getHeaderTitle(for: section)
	}

	// MARK: - UITableViewDiffableDataSource

	func setUpDataSource() {
		dataSource = DataSource<ChangePasswordSection>(viewModel: viewModel, tableView: tableView) { _, _, cellViewModel -> UITableViewCell? in
			let cell = cellViewModel.type.init()
			cell.configure(with: cellViewModel)
			return cell
		}
	}

	func applySnapshot(sections: [ChangePasswordSection], cells: [ChangePasswordSection: [TableViewCellViewModel]]) {
		var snapshot = NSDiffableDataSourceSnapshot<ChangePasswordSection, TableViewCellViewModel>()
		snapshot.appendSections(sections)
		for (section, items) in cells {
			snapshot.appendItems(items, toSection: section)
		}
		dataSource?.apply(snapshot, animatingDifferences: true)
	}
}

// swiftlint:disable:next generic_type_name
private class DataSource<SectionIdentifierType: Hashable>: UITableViewDiffableDataSource<SectionIdentifierType, TableViewCellViewModel> {
	private let viewModel: ChangePasswordViewModelProtocol

	init(viewModel: ChangePasswordViewModelProtocol, tableView: UITableView, cellProvider: @escaping UITableViewDiffableDataSource<SectionIdentifierType, TableViewCellViewModel>.CellProvider) {
		self.viewModel = viewModel
		super.init(tableView: tableView, cellProvider: cellProvider)
	}

	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		return viewModel.getHeaderTitle(for: section)
	}
}
