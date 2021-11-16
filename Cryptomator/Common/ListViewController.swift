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

class ListViewController<T: TableViewCellViewModel>: UITableViewController {
	enum Section {
		case main
	}

	lazy var header = EditableTableViewHeader(title: viewModel.headerTitle)
	lazy var subscribers = Set<AnyCancellable>()
	var dataSource: EditableDataSource<Section, T>?
	private let viewModel: ListViewModel
	private lazy var emptyListMessage = EmptyListMessage(message: viewModel.emptyListMessage)

	init(viewModel: ListViewModel) {
		self.viewModel = viewModel
		super.init(style: .insetGrouped)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
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
				self?.header.isHidden = true
				self?.tableView.backgroundView = self?.emptyListMessage
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

	override func setEditing(_ editing: Bool, animated: Bool) {
		super.setEditing(editing, animated: animated)
		header.isEditing = editing
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
}
