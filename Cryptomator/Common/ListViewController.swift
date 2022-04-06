//
//  ListViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 15.11.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import Combine
import CryptomatorCommonCore
import Promises
import UIKit

class ListViewController<T: TableViewCellViewModel>: BaseUITableViewController {
	enum Section {
		case main
	}

	lazy var header = EditableTableViewHeader(title: viewModel.headerTitle)
	lazy var subscribers = Set<AnyCancellable>()
	var dataSource: EditableDataSource<Section, T>?
	private let viewModel: ListViewModel
	private lazy var emptyListMessage = EmptyListMessage(message: viewModel.emptyListMessage)
	private var firstTimeLoading = true
	private var lastSelectedCellViewModel: T?

	init(viewModel: ListViewModel) {
		self.viewModel = viewModel
		super.init()
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		header.editButton.addTarget(self, action: #selector(editButtonToggled), for: .touchUpInside)
		registerCells()
		configureDataSource()
		dataSource?.moveRowAction = tableView(_:moveRowAt:to:)
		viewModel.startListenForChanges().sink { [weak self] result in
			switch result {
			case let .success(cellViewModels):
				self?.applySnapshot(cells: cellViewModels)
			case let .failure(error):
				self?.handleError(error)
			}
		}.store(in: &subscribers)
	}

	func registerCells() {
		tableView.register(TableViewCell.self, forCellReuseIdentifier: "Cell")
	}

	func configureDataSource() {}

	func handleError(_ error: Error) {
		DDLogError("Error: \(error)")
	}

	func applySnapshot(cells: [TableViewCellViewModel]) {
		var snapshot = NSDiffableDataSourceSnapshot<Section, T>()
		snapshot.appendSections([.main])
		snapshot.appendItems(cells.compactMap({ $0 as? T }))
		dataSource?.apply(snapshot, animatingDifferences: false) { [weak self] in
			if snapshot.numberOfItems == 0 {
				self?.hideHeaderAndShowEmptyListMessage()
			} else {
				self?.header.isHidden = false
				self?.tableView.backgroundView = nil
				self?.tableView.separatorStyle = .singleLine
				self?.tableView.contentInsetAdjustmentBehavior = .automatic
				self?.restoreSelection()
			}
			self?.firstTimeLoading = false
		}
	}

	override func setEditing(_ editing: Bool, animated: Bool) {
		super.setEditing(editing, animated: animated)
		header.isEditing = editing
		restoreSelection()
	}

	@objc func editButtonToggled() {
		setEditing(!isEditing, animated: true)
	}

	// MARK: - UITableViewDataSource

	override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
		do {
			try viewModel.moveRow(at: sourceIndexPath.row, to: destinationIndexPath.row)
		} catch {
			handleError(error)
			return
		}
	}

	// MARK: - UITableViewDelegate

	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		header.configure(with: tableView.traitCollection)
		return header
	}

	override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
		let deleteAction = UIContextualAction(style: .destructive, title: viewModel.removeAlert.confirmButtonText) { _, _, completion in
			let alertController = UIAlertController(title: self.viewModel.removeAlert.title, message: self.viewModel.removeAlert.message, preferredStyle: .alert)
			let okAction = UIAlertAction(title: self.viewModel.removeAlert.confirmButtonText, style: .destructive) { _ in
				do {
					try self.removeRow(at: indexPath)
					completion(true)
				} catch {
					completion(false)
					self.handleError(error)
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

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		lastSelectedCellViewModel = dataSource?.itemIdentifier(for: indexPath)
	}

	// MARK: - Internal

	func removeRow(at indexPath: IndexPath) throws {
		try viewModel.removeRow(at: indexPath.row)
		guard let itemIdentifier = dataSource?.itemIdentifier(for: indexPath), var snapshot = dataSource?.snapshot() else {
			return
		}
		snapshot.deleteItems([itemIdentifier])
		dataSource?.apply(snapshot) {
			if snapshot.numberOfItems == 0 {
				self.hideHeaderAnimated().then(self.showEmptyListMessageAnimated)
			}
		}
	}

	func hideHeaderAnimated() -> Promise<Void> {
		wrap { handler in
			UIView.animate(withDuration: 0.5, animations: ({
				self.header.alpha = 0
			}), completion: handler)
		}.then { _ in
			self.header.isHidden = true
		}
	}

	func showEmptyListMessageAnimated() -> Promise<Void> {
		let emptyListMessage = self.emptyListMessage
		emptyListMessage.alpha = 0.0
		return wrap { handler in
			UIView.animate(withDuration: 0.5, animations: ({
				emptyListMessage.alpha = 1.0
				self.tableView.backgroundView = emptyListMessage
				// Prevents `EmptyListMessage` from being placed under the navigation bar
				self.tableView.contentInsetAdjustmentBehavior = .never
				self.tableView.separatorStyle = .none
			}), completion: handler)
		}.then { _ in
			// no-op
		}
	}

	func hideHeaderAndShowEmptyListMessage() {
		hideHeaderAndShowEmptyListMessage(animated: !firstTimeLoading)
	}

	func hideHeaderAndShowEmptyListMessage(animated: Bool) {
		if animated {
			hideHeaderAnimated().then(showEmptyListMessageAnimated)
		} else {
			header.isHidden = true
			tableView.backgroundView = emptyListMessage
			// Prevents `EmptyListMessage` from being placed under the navigation bar
			tableView.contentInsetAdjustmentBehavior = .never
			tableView.separatorStyle = .none
		}
	}

	private func restoreSelection() {
		guard let splitViewController = splitViewController, !splitViewController.isCollapsed else {
			return
		}
		let snapshot = dataSource?.snapshot()
		let maybeLastSelectedCellViewModel = snapshot?.itemIdentifiers.first(where: { $0.hashValue == lastSelectedCellViewModel?.hashValue })
		if let lastSelectedCellViewModel = maybeLastSelectedCellViewModel, let lastSelectedIndexPath = dataSource?.indexPath(for: lastSelectedCellViewModel) {
			tableView.selectRow(at: lastSelectedIndexPath, animated: true, scrollPosition: .none)
		}
	}
}
