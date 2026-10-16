//
//  VaultKeepUnlockedViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 29.12.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import CryptomatorCommonCore
import UIKit

class VaultKeepUnlockedViewController: BaseUITableViewController {
	weak var coordinator: Coordinator?
	private var viewModel: VaultKeepUnlockedViewModelType
	private var subscribers = Set<AnyCancellable>()
	private let cellIdentifier = "CellIdentifier"

	init(viewModel: VaultKeepUnlockedViewModelType) {
		self.viewModel = viewModel
		super.init()
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = viewModel.title
		tableView.register(CheckMarkCell.self, forCellReuseIdentifier: cellIdentifier)
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		// swiftlint:disable:next force_cast
		let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier) as! CheckMarkCell
		let cellViewModel = viewModel.sections[indexPath.section].elements[indexPath.row]
		cell.configure(with: cellViewModel)
		return cell
	}

	override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
		guard let footerViewModel = viewModel.getFooterViewModel(forSection: section) else {
			return nil
		}
		let footerView = footerViewModel.viewType.init()
		footerView.configure(with: footerViewModel)
		footerView.tableView = tableView
		return footerView
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return viewModel.sections[section].elements.count
	}

	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		return viewModel.getHeaderTitle(for: section)
	}

	override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
		// Prevents the header title from being displayed in uppercase
		guard let headerView = view as? UITableViewHeaderFooterView else {
			return
		}
		headerView.textLabel?.text = viewModel.getHeaderTitle(for: section)
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		guard let keepUnlockedDurationItem = viewModel.sections[indexPath.section].elements[indexPath.row] as? KeepUnlockedDurationItem else {
			return
		}
		let selectedDuration = keepUnlockedDurationItem.duration
		Task {
			defer {
				// Workaround to animate row deselection (see https://stackoverflow.com/a/69165547 for more details)
				UIView.animate(withDuration: 0.3, animations: {
					tableView.deselectRow(at: indexPath, animated: true)
				})
			}
			do {
				try await viewModel.setKeepUnlockedDuration(to: selectedDuration)
			} catch VaultKeepUnlockedViewModelError.vaultIsUnlocked {
				await handleUnlockedVault(selectedDuration: selectedDuration)
			} catch {
				return
			}
		}
	}

	private func handleUnlockedVault(selectedDuration: KeepUnlockedDuration) async {
		guard await askForLockConfirmation() else {
			return
		}
		do {
			try await lockConfirmed(with: selectedDuration)
		} catch {
			handleError(error)
		}
	}

	private func askForLockConfirmation() async -> Bool {
		let confirmation = OneShotSignal<Bool>()
		let alertController = UIAlertController(title: LocalizedString.getValue("keepUnlocked.alert.title"), message: LocalizedString.getValue("keepUnlocked.alert.message"), preferredStyle: .alert)
		let okAction = UIAlertAction(title: LocalizedString.getValue("keepUnlocked.alert.confirm"), style: .default) { _ in
			confirmation.fulfill(true)
		}
		alertController.addAction(okAction)
		alertController.preferredAction = okAction
		alertController.addAction(UIAlertAction(title: LocalizedString.getValue("common.button.cancel"), style: .cancel) { _ in
			confirmation.fulfill(false)
		})
		present(alertController, animated: true)
		return (try? await confirmation.value) ?? false
	}

	private func lockConfirmed(with selectedDuration: KeepUnlockedDuration) async throws {
		try await viewModel.gracefulLockVault()
		try await viewModel.setKeepUnlockedDuration(to: selectedDuration)
	}

	private func handleError(_ error: Error) {
		coordinator?.handleError(error, for: self)
	}
}
