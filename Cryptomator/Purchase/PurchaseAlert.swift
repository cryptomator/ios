//
//  PurchaseAlert.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 03.12.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import StoreKit
import UIKit

enum PurchaseAlert {
	static func showForFullVersion(title: String, on presentingViewController: UIViewController) async {
		await showAlert(title: title, message: LocalizedString.getValue("purchase.unlockedFullVersion.message"), on: presentingViewController)
	}

	static func showForTrial(title: String, expirationDate: Date, on presentingViewController: UIViewController) async {
		let formatter = DateFormatter()
		formatter.dateStyle = .short
		let message = String(format: LocalizedString.getValue("purchase.restorePurchase.validTrialFound.alert.message"), formatter.string(from: expirationDate))
		await showAlert(title: title, message: message, on: presentingViewController)
	}

	static func showForNoRestorablePurchases(on presentingViewController: UIViewController, eligibleForUpgrade: Bool) async {
		if eligibleForUpgrade {
			await showAlert(title: LocalizedString.getValue("purchase.restorePurchase.eligibleForUpgrade.alert.title"),
			                message: LocalizedString.getValue("purchase.restorePurchase.eligibleForUpgrade.alert.message"),
			                on: presentingViewController)
		} else {
			await showAlert(title: LocalizedString.getValue("purchase.restorePurchase.fullVersionNotFound.alert.title"),
			                message: LocalizedString.getValue("purchase.restorePurchase.fullVersionNotFound.alert.message"),
			                on: presentingViewController)
		}
	}

	static func showForSubscriptionWarning(on presentingViewController: UIViewController) async -> Bool {
		let alertController = UIAlertController(title: LocalizedString.getValue("purchase.lifetime.hasSubscription.alert.title"),
		                                        message: LocalizedString.getValue("purchase.lifetime.hasSubscription.alert.message"),
		                                        preferredStyle: .alert)
		let shouldContinue = OneShotSignal<Bool>()
		alertController.addAction(UIAlertAction(title: LocalizedString.getValue("common.button.cancel"), style: .cancel) { _ in
			shouldContinue.fulfill(false)
		})
		let continueAction = UIAlertAction(title: LocalizedString.getValue("common.button.confirm"), style: .default) { _ in
			shouldContinue.fulfill(true)
		}
		alertController.addAction(continueAction)
		alertController.preferredAction = continueAction
		presentingViewController.present(alertController, animated: true)
		return (try? await shouldContinue.value) ?? false
	}

	static func showForSubscriptionCancelGuide(on presentingViewController: UIViewController) async {
		let alertController = UIAlertController(title: LocalizedString.getValue("purchase.lifetime.subscriptionCancelGuide.alert.title"),
		                                        message: LocalizedString.getValue("purchase.lifetime.subscriptionCancelGuide.alert.message"),
		                                        preferredStyle: .alert)
		let dismissed = OneShotSignal<Void>()
		let laterAction = UIAlertAction(title: LocalizedString.getValue("common.button.cancel"), style: .cancel) { _ in
			dismissed.fulfill(())
		}
		alertController.addAction(laterAction)
		let manageAction = UIAlertAction(title: LocalizedString.getValue("purchase.lifetime.subscriptionCancelGuide.alert.manageSubscriptions"), style: .default) { _ in
			if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
				Task {
					do {
						try await AppStore.showManageSubscriptions(in: scene)
					} catch {
						if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
							await MainActor.run {
								UIApplication.shared.open(url)
							}
						}
					}
				}
			} else if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
				UIApplication.shared.open(url)
			}
			dismissed.fulfill(())
		}
		alertController.addAction(manageAction)
		alertController.preferredAction = manageAction
		presentingViewController.present(alertController, animated: true)
		try? await dismissed.value
	}

	private static func showAlert(title: String, message: String, on presentingViewController: UIViewController) async {
		let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
		let dismissed = OneShotSignal<Void>()
		let okAction = UIAlertAction(title: LocalizedString.getValue("common.button.ok"), style: .default) { _ in
			dismissed.fulfill(())
		}
		alertController.addAction(okAction)
		presentingViewController.present(alertController, animated: true)
		try? await dismissed.value
	}
}
