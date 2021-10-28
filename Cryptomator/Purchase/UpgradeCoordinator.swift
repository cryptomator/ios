//
//  UpgradeCoordinator.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 08.09.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Foundation
import Promises
import StoreKit
import UIKit

enum UpgradeError: Error {
	case unavailableProduct
}

class UpgradeCoordinator: Coordinator {
	var childCoordinators = [Coordinator]()
	var navigationController: UINavigationController

	private var products = [ProductIdentifier: SKProduct]()
	private var invalidProductIdentifiers = [String]()

	init(navigationController: UINavigationController) {
		self.navigationController = navigationController
	}

	func start() {
		let upgradeViewController = UpgradeViewController(viewModel: UpgradeViewModel())
		upgradeViewController.coordinator = self
		navigationController.pushViewController(upgradeViewController, animated: true)
		StoreManager.shared.fetchProducts(with: [.paidUpgrade, .freeUpgrade]).then { response in
			self.products = response.products.reduce(into: [ProductIdentifier: SKProduct]()) {
				guard let productIdentifier = ProductIdentifier(rawValue: $1.productIdentifier) else {
					self.invalidProductIdentifiers.append($1.productIdentifier)
					return
				}
				$0[productIdentifier] = $1
			}
			self.invalidProductIdentifiers.append(contentsOf: response.invalidProductIdentifiers)
		}
	}

	func purchaseUpgrade() {
		guard let product = products[.paidUpgrade] else {
			handleError(UpgradeError.unavailableProduct, for: navigationController)
			return
		}
		StoreObserver.shared.buy(product).then { _ in
			CryptomatorUserDefaults.shared.fullVersionUnlocked = true
			return self.showAlert(title: LocalizedString.getValue("upgrade.paidUpgrade.alert.title"), message: LocalizedString.getValue("upgrade.paidUpgrade.alert.message"))
		}.then {
			self.close()
		}.catch { error in
			self.handleError(error, for: self.navigationController)
		}
	}

	func getFreeUpgrade() {
		guard let product = products[.freeUpgrade] else {
			handleError(UpgradeError.unavailableProduct, for: navigationController)
			return
		}
		StoreObserver.shared.buy(product).then { _ in
			CryptomatorUserDefaults.shared.fullVersionUnlocked = true
			return self.showAlert(title: LocalizedString.getValue("upgrade.freeUpgrade.alert.title"), message: LocalizedString.getValue("upgrade.freeUpgrade.alert.message"))
		}.then {
			self.close()
		}.catch { error in
			self.handleError(error, for: self.navigationController)
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
