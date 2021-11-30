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
	func buy(_ product: SKProduct) -> Promise<Void>
	func restore() -> Promise<RestoreTransactionsResult>
}

enum StoreObserverError: Error {
	case deferredTransaction
	case missingTransactionError
}

protocol StoreObserverDelegate: AnyObject {
	func purchaseDidSucceed(product: ProductIdentifier)
}

enum RestoreTransactionsResult: Equatable {
	case restoredFullVersion
	case restoredFreeTrial(expiresOn: Date)
	case noRestorablePurchases
}

class StoreObserver: NSObject, IAPManager {
	static let shared = StoreObserver(cryptomatorSettings: CryptomatorUserDefaults.shared)

	var isAuthorizedForPayments: Bool {
		return SKPaymentQueue.canMakePayments()
	}

	weak var fallbackDelegate: StoreObserverDelegate?

	fileprivate var hasRestorablePurchases = false

	private var runningPayments = [String: Promise<Void>]()
	private var runningRestore: Promise<RestoreTransactionsResult>?
	private var cryptomatorSettings: CryptomatorSettings

	init(cryptomatorSettings: CryptomatorSettings) {
		self.cryptomatorSettings = cryptomatorSettings
	}

	func buy(_ product: SKProduct) -> Promise<Void> {
		DDLogInfo("Buy product: \(product.productIdentifier)")
		let payment = SKMutablePayment(product: product)
		let pendingPromise = Promise<Void>.pending()
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
		DDLogInfo("Purchased \(transaction.payment.productIdentifier) \(self) - Transaction: \(transaction)")

		let maybeProductIdentifier = ProductIdentifier(rawValue: transaction.payment.productIdentifier)
		switch maybeProductIdentifier {
		case .fullVersion:
			unlockFullVersion()
		case .thirtyDayTrial:
			beginFreeTrial(transaction: transaction)
		case .paidUpgrade:
			unlockFullVersion()
		case .freeUpgrade:
			unlockFullVersion()
		case .none:
			break
		}
		SKPaymentQueue.default().finishTransaction(transaction)
		guard let promise = runningPayments.removeValue(forKey: transaction.payment.productIdentifier) else {
			if let productIdentifier = maybeProductIdentifier {
				fallbackDelegate?.purchaseDidSucceed(product: productIdentifier)
			}
			return
		}
		promise.fulfill(())
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

		if transactionsContainFullVersion(transactions) {
			unlockFullVersion()
		} else if transactionsContainValidTrial(transactions) {
			let trialExpirationDate = trialExpirationDate(transactions)
			cryptomatorSettings.trialExpirationDate = trialExpirationDate
		}
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

	private func transactionsContainFullVersion(_ transactions: [SKPaymentTransaction]) -> Bool {
		return transactions.contains(where: { $0.payment.productIdentifier == ProductIdentifier.fullVersion.rawValue || $0.payment.productIdentifier == ProductIdentifier.paidUpgrade.rawValue || $0.payment.productIdentifier == ProductIdentifier.freeUpgrade.rawValue })
	}

	private func transactionsContainValidTrial(_ transactions: [SKPaymentTransaction]) -> Bool {
		guard let trialExpirationDate = trialExpirationDate(transactions) else {
			return false
		}
		return Date() < trialExpirationDate
	}

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
		return Calendar.current.date(byAdding: .day, value: 30, to: transactionDate)
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

	private func unlockFullVersion() {
		cryptomatorSettings.fullVersionUnlocked = true
	}

	private func beginFreeTrial(transaction: SKPaymentTransaction) {
		cryptomatorSettings.trialExpirationDate = trialExpirationDate(transaction)
	}
}

// MARK: - SKPaymentTransactionObserver

extension StoreObserver: SKPaymentTransactionObserver {
	func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
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
		if let error = error as? SKError, error.code != .paymentCancelled {
			promise.reject(error)
		}
	}

	func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
		DDLogInfo("Restoring completed transactions finished")
		if !hasRestorablePurchases {
			guard let promise = runningRestore else {
				DDLogError("Missing running restore for fulfilling promise")
				return
			}
			promise.fulfill(.noRestorablePurchases)
		}
	}
}
