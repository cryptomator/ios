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

enum PurchaseError: Error {
	case unavailableProduct
}

class PurchaseCoordinator: Coordinator {
	var childCoordinators = [Coordinator]()
	var navigationController: UINavigationController

	private let upgradeURL = URL(string: "cryptomator-legacy:upgrade")!
	private var products = [ProductIdentifier: SKProduct]()
	private var invalidProductIdentifiers = [String]()

	init(navigationController: UINavigationController) {
		self.navigationController = navigationController
	}

	func start() {
		let purchaseViewController = PurchaseViewController(viewModel: PurchaseViewModel())
		purchaseViewController.coordinator = self
		navigationController.pushViewController(purchaseViewController, animated: true)
		StoreManager.shared.fetchProducts(with: [.thirtyDayTrial, .fullVersion]).then { response in
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

	func showUpgrade() {
		if UpgradeChecker.isEligibleForUpgrade() {
			let child = UpgradeCoordinator(navigationController: navigationController)
			childCoordinators.append(child) // TODO: remove missing?
			child.start()
		} else if UIApplication.shared.canOpenURL(upgradeURL) {
			UIApplication.shared.open(upgradeURL)
		} else {
			DDLogError("Preconditions for showing upgrade screen are not met")
		}
	}

	func beginFreeTrial() {
		guard let product = products[.thirtyDayTrial] else {
			handleError(PurchaseError.unavailableProduct, for: navigationController)
			return
		}
		StoreObserver.shared.buy(product).then { transaction in
			CryptomatorSettings.shared.trialExpirationDate = self.trialExpirationDate(transaction)
			return self.showAlert(title: LocalizedString.getValue("purchase.beginFreeTrial.alert.title"), message: LocalizedString.getValue("purchase.beginFreeTrial.alert.message"))
		}.then {
			self.close()
		}.catch { error in
			self.handleError(error, for: self.navigationController)
		}
	}

	func purchaseFullVersion() {
		guard let product = products[.fullVersion] else {
			handleError(PurchaseError.unavailableProduct, for: navigationController)
			return
		}
		StoreObserver.shared.buy(product).then { _ in
			CryptomatorSettings.shared.fullVersionUnlocked = true
			return self.showAlert(title: LocalizedString.getValue("purchase.purchaseFullVersion.alert.title"), message: LocalizedString.getValue("purchase.purchaseFullVersion.alert.message"))
		}.then {
			self.close()
		}.catch { error in
			self.handleError(error, for: self.navigationController)
		}
	}

	func restorePurchase() {
		StoreObserver.shared.restore().then { transactions in
			self.handleRestoredTransactions(transactions)
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

	private func handleRestoredTransactions(_ transactions: [SKPaymentTransaction]) {
		if transactionsContainFullVersion(transactions) {
			CryptomatorSettings.shared.fullVersionUnlocked = true
			showAlert(title: LocalizedString.getValue("purchase.restorePurchase.fullVersionFound.alert.title"), message: LocalizedString.getValue("purchase.restorePurchase.fullVersionFound.alert.message")).then {
				self.close()
			}
		} else if transactionsContainValidTrial(transactions) {
			CryptomatorSettings.shared.trialExpirationDate = trialExpirationDate(transactions)
			showAlert(title: LocalizedString.getValue("purchase.restorePurchase.validTrialFound.alert.title"), message: String(format: LocalizedString.getValue("purchase.restorePurchase.validTrialFound.alert.message"), numberOfDaysLeftForTrial(transactions))).then {
				self.close()
			}
		} else {
			_ = showAlert(title: LocalizedString.getValue("purchase.restorePurchase.fullVersionNotFound.alert.title"), message: LocalizedString.getValue("purchase.restorePurchase.fullVersionNotFound.alert.message"))
		}
	}

	private func transactionsContainFullVersion(_ transactions: [SKPaymentTransaction]) -> Bool {
		return transactions.contains(where: { $0.payment.productIdentifier == ProductIdentifier.fullVersion.rawValue || $0.payment.productIdentifier == ProductIdentifier.paidUpgrade.rawValue || $0.payment.productIdentifier == ProductIdentifier.freeUpgrade.rawValue })
	}

	private func transactionsContainValidTrial(_ transactions: [SKPaymentTransaction]) -> Bool {
		guard let trialExpirationDate = trialExpirationDate(transactions) else {
			return false
		}
		return Date() < trialExpirationDate
	}

	private func numberOfDaysLeftForTrial(_ transactions: [SKPaymentTransaction]) -> Int {
		guard let trialExpirationDate = trialExpirationDate(transactions) else {
			return 0
		}
		let difference = Calendar.current.dateComponents([.day], from: Date(), to: trialExpirationDate)
		return difference.day ?? 0
	}

	private func trialExpirationDate(_ transactions: [SKPaymentTransaction]) -> Date? {
		guard let transaction = transactions.first(where: { $0.payment.productIdentifier == ProductIdentifier.thirtyDayTrial.rawValue }) else {
			return nil
		}
		return trialExpirationDate(transaction)
	}

	private func trialExpirationDate(_ transaction: SKPaymentTransaction) -> Date? {
		guard let original = transaction.original, let transactionDate = original.transactionDate else {
			return nil
		}
		return Calendar.current.date(byAdding: .day, value: 30, to: transactionDate)
	}
}
