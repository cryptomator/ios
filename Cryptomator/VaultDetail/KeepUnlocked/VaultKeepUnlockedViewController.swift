//
//  VaultKeepUnlockedViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 29.12.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import CryptomatorCommonCore
import Promises
import UIKit

class VaultKeepUnlockedViewController: StaticUITableViewController<VaultKeepUnlockedSection> {
	weak var coordinator: Coordinator?
	private var viewModel: VaultKeepUnlockedViewModelType
	private var firstTimeLoading = true
	private var subscribers = Set<AnyCancellable>()

	init(viewModel: VaultKeepUnlockedViewModelType) {
		self.viewModel = viewModel
		super.init(viewModel: viewModel)
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		dataSource?.defaultRowAnimation = .fade
		viewModel.sectionsPublisher.receive(on: DispatchQueue.main).sink { [weak self] sections in
			self?.applySnapshot(sections: sections)
		}.store(in: &subscribers)
		viewModel.keepUnlockedIsEnabled.receive(on: DispatchQueue.main).sink { [weak self] keepUnlockIsEnabled in
			self?.handleKeepUnlockedIsEnabled(keepUnlockIsEnabled)
		}.store(in: &subscribers)
	}

	override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
		guard let footerViewModel = viewModel.getFooterViewModel(for: section) else {
			return nil
		}
		let footerView = footerViewModel.viewType.init()
		footerView.configure(with: footerViewModel)
		footerView.tableView = tableView
		return footerView
	}

	private func applySnapshot(sections: [Section<VaultKeepUnlockedSection>]) {
		super.applySnapshot(sections: sections, animatingDifferences: firstTimeLoading ? false : true)
		firstTimeLoading = false
	}

	private func handleKeepUnlockedIsEnabled(_ keepUnlockIsEnabled: Bool) {
		if keepUnlockIsEnabled {
			viewModel.enableKeepUnlocked().catch { [weak self] error in
				self?.handleError(error)
			}
		} else {
			do {
				try viewModel.disableKeepUnlocked()
			} catch {
				coordinator?.handleError(error, for: self)
			}
		}
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)
		guard let keepUnlockedDurationItem = dataSource?.itemIdentifier(for: indexPath) as? KeepUnlockedDurationItem else {
			return
		}
		do {
			try viewModel.setKeepUnlockedDuration(to: keepUnlockedDurationItem.duration)
		} catch {
			coordinator?.handleError(error, for: self)
			return
		}
	}

	private func handleError(_ error: Error) {
		if case VaultKeepUnlockedViewModelError.vaultIsUnlocked = error {
			askForLockConfirmation()
		}
		coordinator?.handleError(error, for: self)
	}

	private func askForLockConfirmation() {
		let alertController = UIAlertController(title: LocalizedString.getValue("vaultDetail.keepUnlocked.alert.title"), message: LocalizedString.getValue("vaultDetail.keepUnlocked.alert.message"), preferredStyle: .alert)
		let okAction = UIAlertAction(title: LocalizedString.getValue("common.button.confirm"), style: .default) { [weak self] _ in
			self?.lockConfirmed()
		}
		alertController.addAction(okAction)
		alertController.addAction(UIAlertAction(title: LocalizedString.getValue("common.button.cancel"), style: .cancel) { [weak self] _ in
			try? self?.viewModel.disableKeepUnlocked()
		})
		present(alertController, animated: true)
	}

	private func lockConfirmed() {
		let viewModel = viewModel
		viewModel.gracefulLockVault().then {
			viewModel.enableKeepUnlocked()
		}.catch { [weak self] error in
			self?.handleError(error)
		}
	}
}
