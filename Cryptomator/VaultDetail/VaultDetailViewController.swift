//
//  VaultDetailViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 29.07.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import CryptomatorCommonCore
import Promises
import UIKit

class VaultDetailViewController: UITableViewController {
	weak var coordinator: VaultDetailCoordinator?
	private let viewModel: VaultDetailViewModelProtocol
	private var observer: NSObjectProtocol?
	private lazy var subscriber = Set<AnyCancellable>()

	init(viewModel: VaultDetailViewModelProtocol) {
		self.viewModel = viewModel
		super.init(style: .grouped)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		viewModel.title.$value
			.receive(on: DispatchQueue.main)
			.sink { [weak self] title in
				self?.title = title
			}.store(in: &subscriber)
		title = viewModel.vaultName
		viewModel.actionPublisher
			.receive(on: DispatchQueue.main)
			.sink(receiveValue: { [weak self] result in
				self?.handleActionResult(result)
			}).store(in: &subscriber)
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
			let alertController = UIAlertController(title: LocalizedString.getValue("vaultList.remove.alert.title"), message: LocalizedString.getValue("vaultList.remove.alert.message"), preferredStyle: .alert)
			let okAction = UIAlertAction(title: LocalizedString.getValue("common.button.remove"), style: .destructive) { _ in
				do {
					try self.viewModel.removeVault()
					self.navigationController?.popViewController(animated: true)
				} catch {
					self.coordinator?.handleError(error, for: self)
				}
			}
			alertController.addAction(okAction)
			alertController.addAction(UIAlertAction(title: LocalizedString.getValue("common.button.cancel"), style: .cancel))
			present(alertController, animated: true, completion: nil)
		case let .showUnlockScreen(vault: vault, biometryTypeName: biometryType):
			coordinator?.unlockVault(vault, biometryTypeName: biometryType).recover { error -> Void in
				guard case VaultDetailUnlockError.userCanceled = error else {
					throw error
				}
			}.catch { [weak self] error in
				guard let self = self else {
					return
				}
				self.coordinator?.handleError(error, for: self)
			}.always { [weak self] in
				_ = self?.viewModel.refreshVaultStatus()
			}
		case .showRenameVault:
			coordinator?.renameVault()
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
