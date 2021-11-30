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

class SettingsViewController: StaticUITableViewController<SettingsSection> {
	weak var coordinator: SettingsCoordinator?

	private let viewModel: SettingsViewModel
	private var observer: NSObjectProtocol?

	init(viewModel: SettingsViewModel) {
		self.viewModel = viewModel
		super.init(viewModel: viewModel)
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
		navigationItem.rightBarButtonItem = doneButton
		refreshCacheSize()
		observer = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
			self?.refreshCacheSize()
		}
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		applySnapshot(sections: viewModel.sections, animatingDifferences: false)
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

	func showCloudServices() {
		coordinator?.showCloudServices()
	}

	func showContact() {
		coordinator?.openContact()
	}

	func showRateApp() {
		coordinator?.openRateApp()
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
		case .showCloudServices:
			showCloudServices()
		case .showContact:
			showContact()
		case .showRateApp:
			showRateApp()
		case .showUnlockFullVersion:
			coordinator?.showUnlockFullVersion()
		case .unknown:
			break
		}
	}
}
