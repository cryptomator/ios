//
//  SingleSectionHeaderTableViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 01.02.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import UIKit
protocol SingleSectionHeaderTableViewModelProtocol {
	var headerTitle: String { get }
	var headerUppercased: Bool { get }
}

class SingleSectionHeaderTableViewController: SingleSectionTableViewController {
	private let viewModel: SingleSectionHeaderTableViewModelProtocol

	init(with viewModel: SingleSectionHeaderTableViewModelProtocol) {
		self.viewModel = viewModel
		super.init()
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
