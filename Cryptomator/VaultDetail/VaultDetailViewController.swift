//
//  VaultDetailViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 29.07.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import Promises
import UIKit

class VaultDetailViewController: UITableViewController {
	weak var coordinator: MainCoordinator?
	private let viewModel: VaultDetailViewModelProtocol
	private var observer: NSObjectProtocol?
	private var viewModelSubscriber: AnyCancellable?

	init(viewModel: VaultDetailViewModelProtocol) {
		self.viewModel = viewModel
		super.init(style: .grouped)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		title = viewModel.vaultName
		viewModelSubscriber = viewModel.actionPublisher
			.receive(on: DispatchQueue.main)
			.sink(receiveValue: { [weak self] result in
				self?.handleActionResult(result)
			})
		refreshVaultLockStatus()
		observer = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
			self?.refreshVaultLockStatus()
		}
	}

	private func refreshVaultLockStatus() {
		viewModel.refreshVaultStatus().catch { [weak self] error in
			guard let self = self else { return }
			self.coordinator?.handleError(error, for: self)
		}
	}

	private func handleActionResult(_ result: Result<VaultDetailButtonAction, Error>) {
		switch result {
		case let .success(action):
			handleAction(action)
		case let .failure(error):
			coordinator?.handleError(error, for: self)
		}
	}

	private func handleAction(_ action: VaultDetailButtonAction) {
		switch action {
		case .openVaultInFilesApp:
			FilesAppUtil.showFilesApp(forVaultUID: viewModel.vaultUID)
		case .lockVault:
			viewModel.lockVault().then {
				let feedbackGenerator = UINotificationFeedbackGenerator()
				feedbackGenerator.notificationOccurred(.success)
			}.catch { error in
				self.coordinator?.handleError(error, for: self)
			}
		case .removeVault:
			let alertController = UIAlertController(title: NSLocalizedString("vaultList.remove.alert.title", comment: ""), message: NSLocalizedString("vaultList.remove.alert.message", comment: ""), preferredStyle: .alert)
			let okAction = UIAlertAction(title: NSLocalizedString("common.button.remove", comment: ""), style: .destructive) { _ in
				do {
					try self.viewModel.removeVault()
					self.navigationController?.popViewController(animated: true)
				} catch {
					self.coordinator?.handleError(error, for: self)
				}
			}
			alertController.addAction(okAction)
			alertController.addAction(UIAlertAction(title: NSLocalizedString("common.button.cancel", comment: ""), style: .cancel))
			present(alertController, animated: true, completion: nil)
		case let .showUnlockScreen(vault: vault, biometryTypeName: biometryType):
			coordinator?.unlockVault(vault, biometryTypeName: biometryType).recover { [weak self] error -> Promise<Void> in
				guard case VaultDetailUnlockError.userCanceled = error, let viewModel = self?.viewModel else {
					return Promise(error)
				}
				return viewModel.refreshVaultStatus()
			}.catch { [weak self] error in
				guard let self = self else {
					return
				}
				self.coordinator?.handleError(error, for: self)
			}
		}
	}

	// MARK: - UITableViewDelegate

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		if let cellViewModel = viewModel.cellViewModel(for: indexPath) as? ButtonCellViewModel<VaultDetailButtonAction>, !cellViewModel.isEnabled.value {
			return
		}
		tableView.deselectRow(at: indexPath, animated: true)
		viewModel.didSelectRow(at: indexPath)
	}

	// MARK: - UITableViewDataSource

	override func numberOfSections(in tableView: UITableView) -> Int {
		return viewModel.numberOfSections
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return viewModel.numberOfRows(in: section)
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cellViewModel = viewModel.cellViewModel(for: indexPath)
		let cell = cellViewModel.type.init()
		cell.configure(with: cellViewModel)
		return cell
	}

	override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
		guard let footerViewModel = viewModel.footerViewModel(for: section) else {
			return nil
		}
		let footerView = footerViewModel.viewType.init()
		footerView.configure(with: footerViewModel)
		footerView.tableView = tableView
		return footerView
	}
}
