//
//  SettingsViewController.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 04.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import Combine
import CryptomatorCommonCore
import Foundation
import UIKit

class SettingsViewController: StaticUITableViewController<SettingsSection> {
	weak var coordinator: SettingsCoordinator?

	private let viewModel: SettingsViewModel
	private var observer: NSObjectProtocol?
	private var subscriber: AnyCancellable?

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
		subscriber = viewModel.showDebugModeWarning.sink { [weak self] in
			self?.showDebugModeAlert()
		}
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		refreshRows()
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

	func showDebugModeAlert() {
		let alertController = UIAlertController(title: LocalizedString.getValue("common.alert.attention.title"), message: LocalizedString.getValue("settings.debugMode.alert.message"), preferredStyle: .alert)
		let okAction = UIAlertAction(title: LocalizedString.getValue("common.button.enable"), style: .default) { _ in
			self.viewModel.enableDebugMode()
		}
		let cancelAction = UIAlertAction(title: LocalizedString.getValue("common.button.cancel"), style: .cancel) { _ in
			self.viewModel.disableDebugMode()
		}
		alertController.addAction(okAction)
		alertController.addAction(cancelAction)

		present(alertController, animated: true, completion: nil)
	}

	// MARK: - UITableViewDelegate

	// swiftlint:disable:next cyclomatic_complexity
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let cellViewModel = dataSource?.itemIdentifier(for: indexPath) as? ButtonCellViewModel<SettingsButtonAction>
		if cellViewModel?.accessoryType.value != .disclosureIndicator {
			tableView.deselectRow(at: indexPath, animated: true)
		}
		switch cellViewModel?.action {
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
		case .showManageSubscriptions:
			coordinator?.showManageSubscriptions()
		case .restorePurchase:
			viewModel.restorePurchase().then { [weak self] _ in
				self?.refreshRows()
			}
		case .showShortcutsGuide:
			coordinator?.openShortcutsGuide()
		case .none:
			break
		}
	}

	private func refreshRows() {
		PremiumManager.shared.refreshStatus()
		applySnapshot(sections: viewModel.sections, animatingDifferences: false)
	}
}
