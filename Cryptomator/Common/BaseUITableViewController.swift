//
//  BaseUITableViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 16.11.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import UIKit

class BaseUITableViewController: UITableViewController {
	init() {
		super.init(style: .insetGrouped)
	}

	override init(style: UITableView.Style) {
		super.init(style: style)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		tableView.backgroundColor = .cryptomatorBackground
		tableView.cellLayoutMarginsFollowReadableWidth = true
	}
}
