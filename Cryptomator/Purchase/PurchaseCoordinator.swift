//
//  PurchaseCoordinator.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 08.09.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCommonCore
import Foundation
import Promises
import StoreKit
import UIKit

class PurchaseCoordinator: Coordinator {
	var childCoordinators = [Coordinator]()
	var navigationController: UINavigationController

	init(navigationController: UINavigationController) {
		self.navigationController = navigationController
	}

	func start() {
		let purchaseViewController = PurchaseViewController(viewModel: PurchaseViewModel())
		purchaseViewController.coordinator = self
		navigationController.pushViewController(purchaseViewController, animated: true)
	}

	func showUpgrade() {
		if UpgradeChecker.shared.isEligibleForUpgrade() {
			let child = getUpgradeCoordinator()
			childCoordinators.append(child) // TODO: remove missing?
			child.start()
		} else if UIApplication.shared.canOpenURL(UpgradeChecker.upgradeURL) {
			UIApplication.shared.open(UpgradeChecker.upgradeURL)
		} else {
			DDLogError("Preconditions for showing upgrade screen are not met")
		}
	}

	func freeTrialStarted(expirationDate: Date) {
		PurchaseAlert.showForTrial(title: LocalizedString.getValue("purchase.beginFreeTrial.alert.title"), expirationDate: expirationDate, on: navigationController).then {
			self.unlockedPro()
		}
	}

	func fullVersionPurchased() {
		PurchaseAlert.showForFullVersion(title: LocalizedString.getValue("purchase.unlockedFullVersion.title"), on: navigationController).then {
			self.unlockedPro()
		}
	}

	func handleRestoreResult(_ result: RestoreTransactionsResult) {
		switch result {
		case .restoredFullVersion:
			PurchaseAlert.showForFullVersion(title: LocalizedString.getValue("purchase.restorePurchase.fullVersionFound.alert.title"), on: navigationController).then {
				self.unlockedPro()
			}
		case let .restoredFreeTrial(expiresOn):
			PurchaseAlert.showForTrial(title: LocalizedString.getValue("purchase.restorePurchase.validTrialFound.alert.title"),
			                           expirationDate: expiresOn,
			                           on: navigationController).then {
				self.unlockedPro()
			}
		case .noRestorablePurchases:
			_ = PurchaseAlert.showForNoRestorablePurchases(on: navigationController)
		}
	}

	func unlockedPro() {
		close()
	}

	func close() {
		navigationController.dismiss(animated: true)
//		parentCoordinator?.childDidFinish(self)
	}

	func getUpgradeCoordinator() -> UpgradeCoordinator {
		return UpgradeCoordinator(navigationController: navigationController)
	}
}
