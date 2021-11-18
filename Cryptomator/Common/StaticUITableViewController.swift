//
//  StaticUITableViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 17.11.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import UIKit

class StaticUITableViewController<SectionType: Hashable>: BaseUITableViewController {
	var dataSource: BaseDiffableDataSource<SectionType, TableViewCellViewModel>?
	private let viewModel: TableViewModel<SectionType>

	init(viewModel: TableViewModel<SectionType>) {
		self.viewModel = viewModel
		super.init()
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = viewModel.title
		configureDataSource()
		applySnapshot(sections: viewModel.sections, animatingDifferences: false)
	}

	func configureDataSource() {
		dataSource = BaseDiffableDataSource<SectionType, TableViewCellViewModel>(viewModel: viewModel, tableView: tableView) { _, _, cellViewModel -> UITableViewCell? in
			let cell = cellViewModel.type.init()
			cell.configure(with: cellViewModel)
			return cell
		}
	}

	func applySnapshot(sections: [Section<SectionType>], animatingDifferences: Bool = true) {
		var snapshot = NSDiffableDataSourceSnapshot<SectionType, TableViewCellViewModel>()
		snapshot.appendSections(sections.map { $0.id })
		sections.forEach { section in
			snapshot.appendItems(section.elements, toSection: section.id)
		}
		dataSource?.apply(snapshot, animatingDifferences: animatingDifferences)
	}

	override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
		// Prevents the header title from being displayed in uppercase
		guard let headerView = view as? UITableViewHeaderFooterView else {
			return
		}
		headerView.textLabel?.text = viewModel.getHeaderTitle(for: section)
	}
}

class SingleSectionStaticUITableViewController: StaticUITableViewController<SingleSection> {}

class BaseDiffableDataSource<SectionType: Hashable, ItemType: Hashable>: UITableViewDiffableDataSource<SectionType, ItemType> {
	private weak var viewModel: TableViewModel<SectionType>?

	init(viewModel: TableViewModel<SectionType>, tableView: UITableView, cellProvider: @escaping UITableViewDiffableDataSource<SectionType, ItemType>.CellProvider) {
		self.viewModel = viewModel
		super.init(tableView: tableView, cellProvider: cellProvider)
	}

	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		return viewModel?.getHeaderTitle(for: section)
	}

	override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
		return viewModel?.getFooterTitle(for: section)
	}
}
