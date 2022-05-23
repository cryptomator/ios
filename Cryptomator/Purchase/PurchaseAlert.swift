//
//  PurchaseAlert.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 03.12.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Promises
import UIKit

enum PurchaseAlert {
	static func showForFullVersion(title: String, on presentingViewController: UIViewController) -> Promise<Void> {
		return showAlert(title: title, message: LocalizedString.getValue("purchase.unlockedFullVersion.message"), on: presentingViewController)
	}

	static func showForTrial(title: String, expirationDate: Date, on presentingViewController: UIViewController) -> Promise<Void> {
		let formatter = DateFormatter()
		formatter.dateStyle = .short
		let formattedExpireDate = formatter.string(for: expirationDate) ?? "Invalid Date"
		let message = String(format: LocalizedString.getValue("purchase.restorePurchase.validTrialFound.alert.message"), formattedExpireDate)
		return showAlert(title: title, message: message, on: presentingViewController)
	}

	static func showForNoRestorablePurchases(on presentingViewController: UIViewController, eligibleForUpgrade: Bool) -> Promise<Void> {
		if eligibleForUpgrade {
			return showAlert(title: LocalizedString.getValue("purchase.restorePurchase.eligibleForUpgrade.alert.title"),
			                 message: LocalizedString.getValue("purchase.restorePurchase.eligibleForUpgrade.alert.message"),
			                 on: presentingViewController)
		} else {
			return showAlert(title: LocalizedString.getValue("purchase.restorePurchase.fullVersionNotFound.alert.title"),
			                 message: LocalizedString.getValue("purchase.restorePurchase.fullVersionNotFound.alert.message"),
			                 on: presentingViewController)
		}
	}

	private static func showAlert(title: String, message: String, on presentingViewController: UIViewController) -> Promise<Void> {
		let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
		let pendingPromise = Promise<Void>.pending()
		let okAction = UIAlertAction(title: LocalizedString.getValue("common.button.ok"), style: .default) { _ in
			pendingPromise.fulfill(())
		}
		alertController.addAction(okAction)
		presentingViewController.present(alertController, animated: true)
		return pendingPromise
	}
}
