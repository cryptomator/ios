//
//  VaultListViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 04.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import Combine
import CryptomatorCommonCore
import Foundation
import UIKit

class VaultListViewController: UITableViewController {
	enum Section {
		case main
	}

	weak var coordinator: MainCoordinator?

	private let viewModel: VaultListViewModelProtocol
	private let header = EditableTableViewHeader(title: LocalizedString.getValue("vaultList.header.title"))
	private var observer: NSObjectProtocol?
	private lazy var dataSource = EditableDataSource<Section, VaultCellViewModel>(tableView: tableView) { tableView, _, cellViewModel -> UITableViewCell? in
		let cell = tableView.dequeueReusableCell(withIdentifier: "VaultCell") as? VaultCell
		cell?.configure(with: cellViewModel)
		return cell
	}

	private lazy var subscribers = Set<AnyCancellable>()

	init(with viewModel: VaultListViewModelProtocol) {
		self.viewModel = viewModel
		super.init(style: .insetGrouped)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = "Cryptomator"
		let settingsSymbol: UIImage?
		if #available(iOS 14, *) {
			settingsSymbol = UIImage(systemName: "gearshape")
		} else {
			settingsSymbol = UIImage(systemName: "gear")
		}
		let settingsButton = UIBarButtonItem(image: settingsSymbol, style: .plain, target: self, action: #selector(showSettings))
		navigationItem.leftBarButtonItem = settingsButton
		let addNewVaulButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addNewVault))
		navigationItem.rightBarButtonItem = addNewVaulButton
		header.editButton.addTarget(self, action: #selector(editButtonToggled), for: .touchUpInside)
		tableView.register(VaultCell.self, forCellReuseIdentifier: "VaultCell")
		viewModel.startListenForChanges().sink { [weak self] result in
			switch result {
			case let .success(vaultCellViewModels):
				self?.applySnapshot(cells: vaultCellViewModels)
			case let .failure(error):
				guard let self = self else { return }
				self.coordinator?.handleError(error, for: self)
			}
		}.store(in: &subscribers)
		dataSource.moveRowAction = tableView(_:moveRowAt:to:)
		observer = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
			self?.viewModel.refreshVaultLockStates().catch { error in
				DDLogError("Refresh vault lock states failed with error: \(error)")
			}
		}
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		viewModel.refreshVaultLockStates().catch { error in
			DDLogError("Refresh vault lock states failed with error: \(error)")
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

	func applySnapshot(cells: [VaultCellViewModel]) {
		var snapshot = NSDiffableDataSourceSnapshot<Section, VaultCellViewModel>()
		snapshot.appendSections([.main])
		snapshot.appendItems(cells)
		dataSource.apply(snapshot, animatingDifferences: false) { [weak self] in
			if snapshot.numberOfItems == 0 {
				self?.header.isHidden = true
				self?.tableView.backgroundView = EmptyListMessage(message: LocalizedString.getValue("vaultList.emptyList.message"))
				// Prevents `EmptyListMessage` from being placed under the navigation bar
				self?.tableView.contentInsetAdjustmentBehavior = .never
				self?.tableView.separatorStyle = .none
			} else {
				self?.header.isHidden = false
				self?.tableView.backgroundView = nil
				self?.tableView.separatorStyle = .singleLine
				self?.tableView.contentInsetAdjustmentBehavior = .automatic
			}
		}
	}

	// MARK: - UITableViewDelegate

	override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
		let deleteAction = UIContextualAction(style: .destructive, title: LocalizedString.getValue("common.button.remove")) { _, _, completion in
			let alertController = UIAlertController(title: LocalizedString.getValue("vaultList.remove.alert.title"), message: LocalizedString.getValue("vaultList.remove.alert.message"), preferredStyle: .alert)
			let okAction = UIAlertAction(title: LocalizedString.getValue("common.button.remove"), style: .destructive) { _ in
				do {
					try self.viewModel.removeRow(at: indexPath.row)
					var snapshot = self.dataSource.snapshot()
					guard let itemIdentifier = self.dataSource.itemIdentifier(for: indexPath) else {
						return
					}
					snapshot.deleteItems([itemIdentifier])
					self.dataSource.apply(snapshot) {
						if snapshot.numberOfItems == 0 {
							UIView.animate(withDuration: 0.5) {
								self.header.alpha = 0
							} completion: { _ in
								self.header.isHidden = true
								let emptyListMessage = EmptyListMessage(message: LocalizedString.getValue("vaultList.emptyList.message"))
								emptyListMessage.alpha = 0.0
								UIView.animate(withDuration: 0.5) {
									emptyListMessage.alpha = 1.0
									self.tableView.backgroundView = emptyListMessage
									// Prevents `EmptyListMessage` from being placed under the navigation bar
									self.tableView.contentInsetAdjustmentBehavior = .never
									self.tableView.separatorStyle = .none
								}
							}
						}
					}
					completion(true)
				} catch {
					completion(false)
					self.coordinator?.handleError(error, for: self)
				}
			}
			alertController.addAction(okAction)
			alertController.addAction(UIAlertAction(title: LocalizedString.getValue("common.button.cancel"), style: .cancel) { _ in
				completion(false)
			})
			self.present(alertController, animated: true, completion: nil)
		}
		let configuration = UISwipeActionsConfiguration(actions: [deleteAction])
		return configuration
	}

	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		return header
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)
		if let vaultCellViewModel = dataSource.itemIdentifier(for: indexPath) {
			coordinator?.showVaultDetail(for: vaultCellViewModel.vault)
		}
	}

	// MARK: - UITableViewDataSource

	override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
		do {
			try viewModel.moveRow(at: sourceIndexPath.row, to: destinationIndexPath.row)
		} catch {
			coordinator?.handleError(error, for: self)
		}
	}
}
