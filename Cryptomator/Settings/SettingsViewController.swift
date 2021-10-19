//
//  SettingsViewController.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 04.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCommonCore
import Foundation
import UIKit

class SettingsViewController: UITableViewController {
	weak var coordinator: SettingsCoordinator?

	private let viewModel: SettingsViewModel
	private var dataSource: UITableViewDiffableDataSource<SettingsSection, TableViewCellViewModel>?
	private var observer: NSObjectProtocol?

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
		title = LocalizedString.getValue("settings.title")
		let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
		navigationItem.rightBarButtonItem = doneButton
		tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SettingsCell")
		tableView.register(LoadingWithLabelCell.self, forCellReuseIdentifier: "LoadingWithLabelCell")
		tableView.rowHeight = 44
		setUpDataSource()
		applySnapshot(sections: viewModel.sections, cells: viewModel.cells)
		refreshCacheSize()
		observer = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
			self?.refreshCacheSize()
		}
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
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

	func clearCache() {
		viewModel.clearCache().catch { error in
			DDLogError("Settings: clear cache failed with error: \(error)")
		}
	}

	func refreshCacheSize() {
		viewModel.refreshCacheSize().catch { error in
			DDLogError("Settings: refresh cache size failed with error: \(error)")
		}
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
		case .clearCache:
			clearCache()
		case .unknown:
			break
		}
	}

	// MARK: - UITableViewDiffableDataSource

	func setUpDataSource() {
		dataSource = UITableViewDiffableDataSource<SettingsSection, TableViewCellViewModel>(tableView: tableView) { _, _, cellViewModel -> UITableViewCell? in
			let cell = cellViewModel.type.init()
			cell.configure(with: cellViewModel)
			return cell
		}
	}

	func applySnapshot(sections: [SettingsSection], cells: [SettingsSection: [TableViewCellViewModel]]) {
		var snapshot = NSDiffableDataSourceSnapshot<SettingsSection, TableViewCellViewModel>()
		snapshot.appendSections(sections)
		for (section, items) in cells {
			snapshot.appendItems(items, toSection: section)
		}
		dataSource?.apply(snapshot, animatingDifferences: true)
	}
}
