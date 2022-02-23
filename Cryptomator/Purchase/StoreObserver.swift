//
//  StoreObserver.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 30.08.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import Combine
import CryptomatorCommonCore
import Foundation
import Promises
import StoreKit

protocol IAPManager {
	var isAuthorizedForPayments: Bool { get }
	func buy(_ product: SKProduct) -> Promise<PurchaseTransaction>
	func restore() -> Promise<RestoreTransactionsResult>
}

enum StoreObserverError: Error {
	case deferredTransaction
	case missingTransactionError
}

protocol StoreObserverDelegate: AnyObject {
	func purchaseDidSucceed(transaction: PurchaseTransaction)
}

enum RestoreTransactionsResult: Equatable {
	case restoredFullVersion
	case restoredFreeTrial(expiresOn: Date)
	case noRestorablePurchases
}

enum PurchaseTransaction: Equatable {
	case fullVersion
	case freeTrial(expiresOn: Date)
	case yearlySubscription
	case unknown
}

class StoreObserver: NSObject, IAPManager {
	static let shared = StoreObserver(cryptomatorSettings: CryptomatorUserDefaults.shared, premiumManager: PremiumManager.shared)

	var isAuthorizedForPayments: Bool {
		return SKPaymentQueue.canMakePayments()
	}

	weak var fallbackDelegate: StoreObserverDelegate?

	fileprivate var hasRestorablePurchases = false

	private var runningPayments = [String: Promise<PurchaseTransaction>]()
	private var runningRestore: Promise<RestoreTransactionsResult>?
	private var cryptomatorSettings: CryptomatorSettings
	private let premiumManager: PremiumManagerType

	init(cryptomatorSettings: CryptomatorSettings, premiumManager: PremiumManagerType) {
		self.cryptomatorSettings = cryptomatorSettings
		self.premiumManager = premiumManager
	}

	func buy(_ product: SKProduct) -> Promise<PurchaseTransaction> {
		DDLogInfo("Buy product: \(product.productIdentifier)")
		let payment = SKMutablePayment(product: product)
		let pendingPromise = Promise<PurchaseTransaction>.pending()
		runningPayments[payment.productIdentifier] = pendingPromise
		SKPaymentQueue.default().add(payment)
		return pendingPromise
	}

	func restore() -> Promise<RestoreTransactionsResult> {
		let pendingPromise = Promise<RestoreTransactionsResult>.pending()
		runningRestore = pendingPromise
		hasRestorablePurchases = false
		SKPaymentQueue.default().restoreCompletedTransactions()
		return pendingPromise
	}

	fileprivate func handlePurchased(_ transaction: SKPaymentTransaction) {
		DDLogInfo("Purchased \(transaction.payment.productIdentifier)")

		let maybeProductIdentifier = ProductIdentifier(rawValue: transaction.payment.productIdentifier)
		let transactionType: PurchaseTransaction
		switch maybeProductIdentifier {
		case .fullVersion, .paidUpgrade, .freeUpgrade:
			transactionType = .fullVersion
		case .yearlySubscription:
			transactionType = .yearlySubscription
		case .thirtyDayTrial:
			if let expirationDate = trialExpirationDate(transaction) {
				transactionType = .freeTrial(expiresOn: expirationDate)
			} else {
				transactionType = .unknown
				DDLogError("Purchased a free trial without a transaction date - this should never happen!")
			}
		case .none:
			transactionType = .unknown
		}
		SKPaymentQueue.default().finishTransaction(transaction)
		guard let promise = runningPayments.removeValue(forKey: transaction.payment.productIdentifier) else {
			fallbackDelegate?.purchaseDidSucceed(transaction: transactionType)
			return
		}
		promise.fulfill(transactionType)
	}

	fileprivate func handleFailed(_ transaction: SKPaymentTransaction) {
		if let error = transaction.error {
			DDLogError("Purchase of \(transaction.payment.productIdentifier) failed with error: \(error)")
		} else {
			DDLogError("Purchase of \(transaction.payment.productIdentifier) failed")
		}
		SKPaymentQueue.default().finishTransaction(transaction)
		guard let promise = runningPayments.removeValue(forKey: transaction.payment.productIdentifier) else {
			return
		}
		promise.reject(transaction.error ?? StoreObserverError.missingTransactionError)
	}

	fileprivate func handleRestored(_ transactions: [SKPaymentTransaction]) {
		DDLogInfo("Restored \(transactions.map { $0.payment.productIdentifier }.joined(separator: ", "))")
		for transaction in transactions {
			SKPaymentQueue.default().finishTransaction(transaction)
		}
	}

	fileprivate func handleDeferred(_ transaction: SKPaymentTransaction) {
		DDLogInfo("Deferred purchase of \(transaction.payment.productIdentifier)")
		guard let promise = runningPayments.removeValue(forKey: transaction.payment.productIdentifier) else {
			DDLogError("Missing running payment for rejecting SKPayment promise")
			return
		}
		// https://stackoverflow.com/q/26187148/1759462
		promise.reject(StoreObserverError.deferredTransaction)
	}

	// MARK: - Store Logic

	private func trialExpirationDate(_ transactions: [SKPaymentTransaction]) -> Date? {
		guard let transaction = transactions.first(where: { $0.payment.productIdentifier == ProductIdentifier.thirtyDayTrial.rawValue }) else {
			return nil
		}
		return trialExpirationDate(transaction)
	}

	private func trialExpirationDate(_ transaction: SKPaymentTransaction) -> Date? {
		guard let transactionDate = getOriginalTrialTransactionDate(transaction) else {
			return nil
		}
		return premiumManager.trialExpirationDate(for: transactionDate)
	}

	/**
	 Returns the original transaction date for the trial.

	 When the trial is restored, it is ensured that it does not extend the trial period by using the original transaction date.
	 If the transaction is executed for the first time, i. e. it does not have an original transaction date, the current transaction date will be used.
	 */
	private func getOriginalTrialTransactionDate(_ transaction: SKPaymentTransaction) -> Date? {
		if let original = transaction.original {
			return original.transactionDate
		}
		return transaction.transactionDate
	}
}

// MARK: - SKPaymentTransactionObserver

extension StoreObserver: SKPaymentTransactionObserver {
	func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
		premiumManager.refreshStatus()
		var restoredTransactions = [SKPaymentTransaction]()
		for transaction in transactions {
			switch transaction.transactionState {
			case .purchasing:
				break
			case .purchased:
				handlePurchased(transaction)
			case .failed:
				handleFailed(transaction)
			case .restored:
				restoredTransactions.append(transaction) // handled below in bulk
			case .deferred:
				handleDeferred(transaction)
			@unknown default:
				fatalError("Unknown payment transaction case")
			}
		}
		if !restoredTransactions.isEmpty {
			handleRestored(restoredTransactions)
		}
	}

	func paymentQueue(_ queue: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction]) {
		for transaction in transactions {
			DDLogInfo("Removed \(transaction.payment.productIdentifier) from the payment queue")
		}
	}

	func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
		DDLogError("Restoring completed transactions failed with error: \(error)")
		guard let promise = runningRestore else {
			DDLogError("Missing running restore for rejecting promise")
			return
		}
		promise.reject(error)
	}

	func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
		DDLogInfo("Restoring completed transactions finished")
		premiumManager.refreshStatus()
		if cryptomatorSettings.hasRunningSubscription || cryptomatorSettings.fullVersionUnlocked {
			runningRestore?.fulfill(.restoredFullVersion)
		} else if let trialExpirationDate = cryptomatorSettings.trialExpirationDate, trialExpirationDate > Date() {
			runningRestore?.fulfill(.restoredFreeTrial(expiresOn: trialExpirationDate))
		} else {
			runningRestore?.fulfill(.noRestorablePurchases)
		}
	}

	func paymentQueue(_ queue: SKPaymentQueue, didRevokeEntitlementsForProductIdentifiers productIdentifiers: [String]) {
		DDLogInfo("Revoke entitlements for product identifiers: \(productIdentifiers)")
		premiumManager.refreshStatus()
	}
}
