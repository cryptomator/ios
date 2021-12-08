//
//  UpgradeViewController.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 08.09.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation
import UIKit

class UpgradeViewController: IAPViewController<UpgradeSection, UpgradeButtonAction> {
	weak var coordinator: UpgradeCoordinator? {
		didSet {
			setCoordinator(coordinator)
		}
	}

	private let viewModel: UpgradeViewModel

	init(viewModel: UpgradeViewModel) {
		self.viewModel = viewModel
		super.init(viewModel: viewModel)
	}

	// MARK: - UITableViewDelegate

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)
		let cellViewModel = dataSource?.itemIdentifier(for: indexPath) as? ButtonCellViewModel<UpgradeButtonAction>
		switch cellViewModel?.action {
		case .paidUpgrade:
			viewModel.purchaseUpgrade().then { [weak self] in
				self?.coordinator?.paidUpgradePurchased()
			}.catch { [weak self] error in
				self?.handleError(error)
			}
		case .freeUpgrade:
			viewModel.getFreeUpgrade().then { [weak self] in
				self?.coordinator?.freeUpgradePurchased()
			}.catch { [weak self] error in
				self?.handleError(error)
			}
		case .refreshProducts:
			viewModel.replaceRetrySectionWithLoadingSection()
			applySnapshot(sections: viewModel.sections)
		case .decideLater:
			coordinator?.close()
		case .none:
			break
		}
	}
}
