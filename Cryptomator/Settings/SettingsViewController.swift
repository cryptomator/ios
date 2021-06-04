//
//  SettingsViewController.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 04.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation
import UIKit

class SettingsViewController: UITableViewController {
	weak var coordinator: SettingsCoordinator?

	private let viewModel: SettingsViewModel

	init(viewModel: SettingsViewModel) {
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

	override func viewDidLoad() {
		super.viewDidLoad()
		title = NSLocalizedString("settings.title", comment: "")
		let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
		navigationItem.rightBarButtonItem = doneButton
		tableView.register(ButtonCell.self, forCellReuseIdentifier: "ButtonCell")
		tableView.rowHeight = 44
	}

	@objc func done() {
		coordinator?.close()
	}

	@objc func exportLogs() {
		coordinator?.exportLogs()
	}

	// MARK: - UITableViewDataSource

	override func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return 1
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		// swiftlint:disable:next force_cast
		let cell = tableView.dequeueReusableCell(withIdentifier: "ButtonCell", for: indexPath) as! ButtonCell
		cell.button.setTitle(NSLocalizedString("settings.exportLogs", comment: ""), for: .normal)
		cell.button.addTarget(self, action: #selector(exportLogs), for: .touchUpInside)
		return cell
	}
}
