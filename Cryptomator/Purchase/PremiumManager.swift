//
//  PremiumManager.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 09.02.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCommonCore
import Foundation
import Promises
import StoreKit
import TPInAppReceipt

protocol PremiumManagerType {
	/**
	 Updates the premium status by reading the local app store receipt.

	 The local app store receipt can only be read by the main app.
	 */
	func refreshStatus()
	/**
	 Returns the expiration date of the trial for a given purchase date by adding 30 days.

	 - Note: To obtain the correct expiration date of a trial, the original purchase date should be passed. Otherwise, a restored transaction could extend the trial period.
	 - Returns: The trial expiration date, or nil if a date could not be calculated with the given input
	 */
	func trialExpirationDate(for purchaseDate: Date) -> Date?
}

class PremiumManager: PremiumManagerType {
	#if ALWAYS_PREMIUM
	static let shared = AlwaysPremiumManager()
	#else
	static let shared = PremiumManager(cryptomatorSettings: CryptomatorUserDefaults.shared)
	#endif

	private var cryptomatorSettings: CryptomatorSettings

	init(cryptomatorSettings: CryptomatorSettings) {
		self.cryptomatorSettings = cryptomatorSettings
		refreshStatus()
	}

	func refreshStatus() {
		reloadReceipt()
	}

	func trialExpirationDate(for purchaseDate: Date) -> Date? {
		return Calendar.current.date(byAdding: .day, value: 30, to: purchaseDate)
	}

	private func reloadReceipt() {
		let receipt: InAppReceipt
		do {
			receipt = try InAppReceipt.localReceipt()
		} catch {
			DDLogError("PremiumManager.reloadReceipt failed with error: \(error)")
			return
		}
		let premiumHistory = createPremiumHistory(for: receipt)
		savePremiumHistory(premiumHistory)
	}

	private func savePremiumHistory(_ premiumHistory: PremiumHistory) {
		cryptomatorSettings.trialExpirationDate = premiumHistory.trialExpirationDate
		cryptomatorSettings.fullVersionUnlocked = premiumHistory.lifetimePremiumEnabled
		cryptomatorSettings.hasRunningSubscription = premiumHistory.hasRunningSubscription
	}

	private func createPremiumHistory(for receipt: InAppReceipt) -> PremiumHistory {
		return PremiumHistory(trialExpirationDate: getTrialExpirationDate(for: receipt),
		                      hasRunningSubscription: hasRunningSubscription(receipt: receipt),
		                      lifetimePremiumEnabled: hasLifetimePremium(receipt: receipt))
	}

	private func getActiveAutoRenewableSubscriptionExpirationDate(receipt: InAppReceipt) -> Date? {
		let activeAutoRenewableSubscription = receipt.activeAutoRenewableSubscriptionPurchases(ofProductIdentifier: .yearlySubscription, forDate: Date())
		return activeAutoRenewableSubscription?.subscriptionExpirationDate
	}

	private func hasRunningSubscription(receipt: InAppReceipt) -> Bool {
		return receipt.hasActiveAutoRenewableSubscription(ofProductIdentifier: .yearlySubscription, forDate: Date())
	}

	private func hasLifetimePremium(receipt: InAppReceipt) -> Bool {
		let freeUpgradePurchases = receipt.validPurchases(ofProductIdentifier: .freeUpgrade)
		let paidUpgradePurchases = receipt.validPurchases(ofProductIdentifier: .paidUpgrade)
		let fullVersionPurchases = receipt.validPurchases(ofProductIdentifier: .fullVersion)

		var premiumPurchases = [InAppPurchase]()
		premiumPurchases.append(contentsOf: freeUpgradePurchases)
		premiumPurchases.append(contentsOf: paidUpgradePurchases)
		premiumPurchases.append(contentsOf: fullVersionPurchases)
		return !premiumPurchases.isEmpty
	}

	private func hasRunningTrial(receipt: InAppReceipt) -> Bool {
		let trialPurchases = receipt.validPurchases(ofProductIdentifier: .thirtyDayTrial)
		for purchase in trialPurchases {
			guard let trialExpirationDate = trialExpirationDate(for: purchase) else {
				continue
			}
			if trialExpirationDate > Date() {
				return true
			}
		}
		return false
	}

	private func getTrialExpirationDate(for receipt: InAppReceipt) -> Date? {
		let trialPurchases = receipt.validPurchases(ofProductIdentifier: .thirtyDayTrial)
		let trialExpirationDates = trialPurchases.map { trialExpirationDate(for: $0) ?? .distantPast }
		let descendingSortedTrialExpirationDates = trialExpirationDates.sorted(by: { $0 > $1 })
		return descendingSortedTrialExpirationDates.first
	}

	private func trialExpirationDate(for purchase: InAppPurchase) -> Date? {
		let purchaseDate: Date
		if let originalPurchaseDate = purchase.originalPurchaseDate {
			purchaseDate = originalPurchaseDate
		} else {
			purchaseDate = purchase.purchaseDate
		}
		return trialExpirationDate(for: purchaseDate)
	}
}

private struct PremiumHistory: Codable {
	let trialExpirationDate: Date?
	let hasRunningSubscription: Bool
	let lifetimePremiumEnabled: Bool
}

extension InAppReceipt {
	/**
	 Returns all valid purchases of a given product identifier by filtering out cancelled purchases.

	 A cancellation date that is not nil means that the purchase has been refunded by Apple Support or the user has upgraded to a higher subscription plan.
	 Subscriptions canceled by the user but possibly not yet expired will continue to be returned.
	 */
	func validPurchases(ofProductIdentifier productIdentifier: ProductIdentifier) -> [InAppPurchase] {
		return purchases(ofProductIdentifier: productIdentifier).filter { $0.cancellationDate == nil }
	}

	// MARK: Convenience

	func purchases(ofProductIdentifier productIdentifier: ProductIdentifier,
	               sortedBy sort: ((InAppPurchase, InAppPurchase) -> Bool)? = nil) -> [InAppPurchase] {
		return purchases(ofProductIdentifier: productIdentifier.rawValue, sortedBy: sort)
	}

	func hasActiveAutoRenewableSubscription(ofProductIdentifier productIdentifier: ProductIdentifier, forDate date: Date) -> Bool {
		return hasActiveAutoRenewableSubscription(ofProductIdentifier: productIdentifier.rawValue, forDate: date)
	}

	func activeAutoRenewableSubscriptionPurchases(ofProductIdentifier productIdentifier: ProductIdentifier, forDate date: Date) -> InAppPurchase? {
		return activeAutoRenewableSubscriptionPurchases(ofProductIdentifier: productIdentifier.rawValue, forDate: date)
	}
}

class AlwaysPremiumManager: PremiumManagerType {
	func refreshStatus() {
		// no-op
	}

	func trialExpirationDate(for purchaseDate: Date) -> Date? {
		return nil
	}
}
