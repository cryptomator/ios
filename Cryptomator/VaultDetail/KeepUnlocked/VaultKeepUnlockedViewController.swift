//
//  VaultKeepUnlockedViewController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 29.12.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
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
		do {
			if keepUnlockIsEnabled {
				try viewModel.enableKeepUnlocked()
			} else {
				try viewModel.disableKeepUnlocked()
			}
		} catch {
			coordinator?.handleError(error, for: self)
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
}
