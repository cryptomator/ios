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

	func freeTrialStarted() {
		showAlert(title: LocalizedString.getValue("purchase.beginFreeTrial.alert.title"), message: LocalizedString.getValue("purchase.beginFreeTrial.alert.message")).then {
			self.unlockedPro()
		}
	}

	func fullVersionPurchased() {
		showAlert(title: LocalizedString.getValue("purchase.purchaseFullVersion.alert.title"), message: LocalizedString.getValue("purchase.purchaseFullVersion.alert.message")).then {
			self.unlockedPro()
		}
	}

	func handleRestoreResult(_ result: RestoreTransactionsResult) {
		switch result {
		case .restoredFullVersion:
			showAlert(title: LocalizedString.getValue("purchase.restorePurchase.fullVersionFound.alert.title"), message: LocalizedString.getValue("purchase.restorePurchase.fullVersionFound.alert.message")).then {
				self.unlockedPro()
			}
		case let .restoredFreeTrial(expiresOn):
			let formatter = DateFormatter()
			formatter.dateStyle = .short
			let formattedExpireDate = formatter.string(for: expiresOn) ?? "Invalid Date"
			showAlert(
				title: LocalizedString.getValue("purchase.restorePurchase.validTrialFound.alert.title"),
				message: String(format: LocalizedString.getValue("purchase.restorePurchase.validTrialFound.alert.message"), formattedExpireDate)
			).then {
				self.unlockedPro()
			}
		case .noRestorablePurchases:
			_ = showAlert(title: LocalizedString.getValue("purchase.restorePurchase.fullVersionNotFound.alert.title"), message: LocalizedString.getValue("purchase.restorePurchase.fullVersionNotFound.alert.message"))
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

	private func showAlert(title: String, message: String) -> Promise<Void> {
		let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
		let pendingPromise = Promise<Void>.pending()
		let okAction = UIAlertAction(title: LocalizedString.getValue("common.button.ok"), style: .default) { _ in
			pendingPromise.fulfill(())
		}
		alertController.addAction(okAction)
		navigationController.present(alertController, animated: true)
		return pendingPromise
	}
}
