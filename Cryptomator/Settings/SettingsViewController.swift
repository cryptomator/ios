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
		tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SettingsCell")
		tableView.rowHeight = 44
	}

	@objc func done() {
		coordinator?.close()
	}

	func showAbout() {
		coordinator?.showAbout()
	}

	func sendLogFile(sender: UIView) {
		try? coordinator?.sendLogFile(sourceView: sender)
	}

	// MARK: - UITableViewDelegate

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)
		switch viewModel.buttonAction(for: indexPath) {
		case .showAbout:
			showAbout()
		case .sendLogFile:
			guard let cell = tableView.cellForRow(at: indexPath) else {
				return
			}
			sendLogFile(sender: cell)
		default:
			break
		}
	}

	// MARK: - UITableViewDataSource

	override func numberOfSections(in tableView: UITableView) -> Int {
		return viewModel.numberOfSections
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return viewModel.numberOfRows(in: section)
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsCell", for: indexPath)
		cell.textLabel?.textColor = UIColor(named: "primary")
		cell.textLabel?.text = viewModel.title(for: indexPath)
		cell.accessoryType = viewModel.accessoryType(for: indexPath)
		return cell
	}
}
