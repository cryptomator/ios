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
		showAlert(title: LocalizedString.getValue("upgrade.paidUpgrade.alert.title"), message: LocalizedString.getValue("upgrade.paidUpgrade.alert.message")).then {
			self.close()
		}
	}

	func freeUpgradePurchased() {
		showAlert(title: LocalizedString.getValue("upgrade.freeUpgrade.alert.title"), message: LocalizedString.getValue("upgrade.freeUpgrade.alert.message")).then {
			self.close()
		}
	}

	func close() {
		navigationController.dismiss(animated: true)
//		parentCoordinator?.childDidFinish(self)
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
