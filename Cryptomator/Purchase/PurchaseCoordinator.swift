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
		purchaseViewController.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonTapped))
		navigationController.pushViewController(purchaseViewController, animated: true)
	}

	func showUpgrade(onAlertDismiss execute: (() -> Void)? = nil) {
		if UpgradeChecker.shared.isEligibleForUpgrade() {
			let upgradeViewController = IAPViewController(viewModel: UpgradeViewModel())
			upgradeViewController.coordinator = getUpgradeCoordinator()
			upgradeViewController.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonTapped))
			navigationController.pushViewController(upgradeViewController, animated: true)
		} else if UIApplication.shared.canOpenURL(UpgradeChecker.upgradeURL) {
			UIApplication.shared.open(UpgradeChecker.upgradeURL)
		} else {
			showUpgradeFailedAlert(onAlertDismiss: execute)
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
			_ = PurchaseAlert.showForNoRestorablePurchases(on: navigationController, eligibleForUpgrade: UpgradeChecker.shared.isEligibleForUpgrade())
		}
	}

	func unlockedPro() {
		close()
	}

	func close() {
		navigationController.dismiss(animated: true)
//		parentCoordinator?.childDidFinish(self)
	}

	func getUpgradeCoordinator() -> PurchaseCoordinator {
		return self
	}

	private func showUpgradeFailedAlert(onAlertDismiss execute: (() -> Void)? = nil) {
		let alertController = UIAlertController(title: LocalizedString.getValue("upgrade.notEligible.alert.title"),
		                                        message: LocalizedString.getValue("upgrade.notEligible.alert.message"),
		                                        preferredStyle: .alert)
		let okAction = UIAlertAction(title: LocalizedString.getValue("common.button.download"), style: .default) { _ in
			self.showCryptomatorLegacyAppInAppStore()
			execute?()
		}
		alertController.addAction(okAction)
		let cancelAction = UIAlertAction(title: LocalizedString.getValue("common.button.cancel"), style: .cancel) { _ in
			execute?()
		}
		alertController.addAction(cancelAction)
		alertController.preferredAction = okAction
		navigationController.present(alertController, animated: true)
	}

	private func showCryptomatorLegacyAppInAppStore() {
		let cryptomatorLegacyAppStoreURL = URL(string: "itms-apps://apple.com/app/id953086535")!
		UIApplication.shared.open(cryptomatorLegacyAppStoreURL)
	}

	@objc func doneButtonTapped() {
		showContinueInReadOnlyModeAlert()
	}

	private func showContinueInReadOnlyModeAlert() {
		let alertController = UIAlertController(title: LocalizedString.getValue("purchase.readOnlyMode.alert.title"),
		                                        message: LocalizedString.getValue("purchase.readOnlyMode.alert.message"),
		                                        preferredStyle: .alert)
		let okAction = UIAlertAction(title: LocalizedString.getValue("common.button.ok"), style: .default) { _ in
			self.close()
		}
		alertController.addAction(okAction)
		alertController.addAction(UIAlertAction(title: LocalizedString.getValue("common.button.cancel"), style: .cancel))
		alertController.preferredAction = okAction
		navigationController.present(alertController, animated: true)
	}
}
