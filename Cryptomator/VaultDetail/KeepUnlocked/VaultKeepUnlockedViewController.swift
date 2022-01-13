//
//  VaultKeepUnlockedViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 29.12.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import UIKit

class VaultKeepUnlockedViewController: BaseUITableViewController {
	enum Section {
		case main
	}

	weak var coordinator: Coordinator?
	private var dataSource: UITableViewDiffableDataSource<Section, AutoLockItem>?
	private var viewModel: VaultAutoLockViewModelType

	init(viewModel: VaultAutoLockViewModelType) {
		self.viewModel = viewModel
		super.init()
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		configureDataSource()
		applySnapshot(items: viewModel.items)
		title = viewModel.title
	}

	func configureDataSource() {
		let cellIdentifier = "Cell"
		tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellIdentifier)
		dataSource = UITableViewDiffableDataSource(tableView: tableView, cellProvider: { tableView, _, itemIdentifier in
			let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier)
			cell?.accessoryType = itemIdentifier.selected ? .checkmark : .none
			let text = itemIdentifier.timeout.description
			if #available(iOS 14, *) {
				var content = cell?.defaultContentConfiguration()
				content?.text = text
				cell?.contentConfiguration = content
			} else {
				cell?.textLabel?.text = text
			}
			return cell
		})
	}

	func applySnapshot(items: [AutoLockItem]) {
		var snapshot = NSDiffableDataSourceSnapshot<Section, AutoLockItem>()
		snapshot.appendSections([.main])
		snapshot.appendItems(items)
		dataSource?.apply(snapshot, animatingDifferences: false)
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)
		guard let itemIdentifier = dataSource?.itemIdentifier(for: indexPath) else {
			return
		}
		var previousSelectedIndexPath: IndexPath?
		if let previousSelectedItem = viewModel.items.first(where: { $0.selected }) {
			previousSelectedIndexPath = dataSource?.indexPath(for: previousSelectedItem)
		}
		do {
			try viewModel.setKeepUnlockedSetting(to: itemIdentifier.timeout)
		} catch {
			coordinator?.handleError(error, for: self)
			return
		}
		if let previousSelectedIndexPath = previousSelectedIndexPath, let previousSelectedCell = tableView.cellForRow(at: previousSelectedIndexPath) {
			previousSelectedCell.accessoryType = .none
		}
		guard let cell = tableView.cellForRow(at: indexPath) else {
			return
		}
		cell.accessoryType = itemIdentifier.selected ? .checkmark : .none
	}
}
