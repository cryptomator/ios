//
//  SingleSectionTableViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 25.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import UIKit
protocol SingleSectionTableViewModelProtocol {
	var headerTitle: String { get }
	var headerUppercased: Bool { get }
}

class SingleSectionTableViewController: UITableViewController {
	private let viewModel: SingleSectionTableViewModelProtocol

	init(with viewModel: SingleSectionTableViewModelProtocol) {
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

	override func numberOfSections(in tableView: UITableView) -> Int {
		1
	}

	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		return viewModel.headerTitle
	}

	override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
		guard !viewModel.headerUppercased else {
			return
		}
		guard let headerView = view as? UITableViewHeaderFooterView else {
			return
		}
		// Prevents the Header Title from being displayed in uppercase
		headerView.textLabel?.text = viewModel.headerTitle
	}
}
