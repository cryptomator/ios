//
//  UpgradeCoordinator.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 08.09.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Promises
import UIKit

enum UpgradeError: Error {
	case unavailableProduct
}

class UpgradeCoordinator: Coordinator {
	var childCoordinators = [Coordinator]()
	var navigationController: UINavigationController

	init(navigationController: UINavigationController) {
		self.navigationController = navigationController
	}

	func start() {
		let upgradeViewController = UpgradeViewController(viewModel: UpgradeViewModel())
		upgradeViewController.coordinator = self
		navigationController.pushViewController(upgradeViewController, animated: true)
	}

	func paidUpgradePurchased() {
		showAlert().then {
			self.close()
		}
	}

	func freeUpgradePurchased() {
		showAlert().then {
			self.close()
		}
	}

	func close() {
		navigationController.dismiss(animated: true)
//		parentCoordinator?.childDidFinish(self)
	}

	private func showAlert() -> Promise<Void> {
		return PurchaseAlert.showForFullVersion(title: LocalizedString.getValue("purchase.unlockedFullVersion.title"), on: navigationController)
	}
}
