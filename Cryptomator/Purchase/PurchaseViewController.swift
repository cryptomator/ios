//
//  PurchaseViewController.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 08.09.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation
import UIKit

class PurchaseViewController: IAPViewController<PurchaseSection> {
	weak var coordinator: PurchaseCoordinator? {
		didSet {
			setCoordinator(coordinator)
		}
	}

	private let viewModel: PurchaseViewModel

	init(viewModel: PurchaseViewModel) {
		self.viewModel = viewModel
		super.init(viewModel: viewModel)
	}

	// MARK: - UITableViewDelegate

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)
		switch viewModel.buttonAction(for: indexPath) {
		case .showUpgrade:
			coordinator?.showUpgrade()
		case .beginFreeTrial:
			viewModel.beginFreeTrial().then { [weak self] trialExpirationDate in
				self?.coordinator?.freeTrialStarted(expirationDate: trialExpirationDate)
			}.catch { [weak self] error in
				self?.handleError(error)
			}
		case .purchaseFullVersion:
			viewModel.purchaseFullVersion().then { [weak self] in
				self?.coordinator?.fullVersionPurchased()
			}.catch { [weak self] error in
				self?.handleError(error)
			}
		case .restorePurchase:
			viewModel.restorePurchase().then { [weak self] result in
				self?.coordinator?.handleRestoreResult(result)
			}
		case .decideLater:
			coordinator?.close()
		case .refreshProducts:
			let viewModel = viewModel
			viewModel.replaceRetrySectionWithLoadingSection()
			applySnapshot(sections: viewModel.sections)
			viewModel.fetchProducts().then { [weak self] in
				self?.applySnapshot(sections: viewModel.sections)
			}
		case .unknown:
			break
		}
	}
}
