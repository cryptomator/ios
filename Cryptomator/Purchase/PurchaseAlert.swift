//
//  PurchaseAlert.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 03.12.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Promises
import StoreKit
import UIKit

enum PurchaseAlert {
	static func showForFullVersion(title: String, on presentingViewController: UIViewController) -> Promise<Void> {
		return showAlert(title: title, message: LocalizedString.getValue("purchase.unlockedFullVersion.message"), on: presentingViewController)
	}

	static func showForTrial(title: String, expirationDate: Date, on presentingViewController: UIViewController) -> Promise<Void> {
		let formatter = DateFormatter()
		formatter.dateStyle = .short
		let message = String(format: LocalizedString.getValue("purchase.restorePurchase.validTrialFound.alert.message"), formatter.string(from: expirationDate))
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

	static func showForSubscriptionWarning(on presentingViewController: UIViewController) -> Promise<Bool> {
		let alertController = UIAlertController(title: LocalizedString.getValue("purchase.lifetime.hasSubscription.alert.title"),
		                                        message: LocalizedString.getValue("purchase.lifetime.hasSubscription.alert.message"),
		                                        preferredStyle: .alert)
		let pendingPromise = Promise<Bool>.pending()
		alertController.addAction(UIAlertAction(title: LocalizedString.getValue("common.button.cancel"), style: .cancel) { _ in
			pendingPromise.fulfill(false)
		})
		let continueAction = UIAlertAction(title: LocalizedString.getValue("common.button.confirm"), style: .default) { _ in
			pendingPromise.fulfill(true)
		}
		alertController.addAction(continueAction)
		alertController.preferredAction = continueAction
		presentingViewController.present(alertController, animated: true)
		return pendingPromise
	}

	static func showForSubscriptionCancelGuide(on presentingViewController: UIViewController) -> Promise<Void> {
		let alertController = UIAlertController(title: LocalizedString.getValue("purchase.lifetime.subscriptionCancelGuide.alert.title"),
		                                        message: LocalizedString.getValue("purchase.lifetime.subscriptionCancelGuide.alert.message"),
		                                        preferredStyle: .alert)
		let pendingPromise = Promise<Void>.pending()
		let laterAction = UIAlertAction(title: LocalizedString.getValue("common.button.cancel"), style: .cancel) { _ in
			pendingPromise.fulfill(())
		}
		alertController.addAction(laterAction)
		let manageAction = UIAlertAction(title: LocalizedString.getValue("purchase.lifetime.subscriptionCancelGuide.alert.manageSubscriptions"), style: .default) { _ in
			if #available(iOS 15.0, *), let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
				Task {
					try? await AppStore.showManageSubscriptions(in: scene)
				}
			} else if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
				UIApplication.shared.open(url)
			}
			pendingPromise.fulfill(())
		}
		alertController.addAction(manageAction)
		alertController.preferredAction = manageAction
		presentingViewController.present(alertController, animated: true)
		return pendingPromise
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
