//
//  StoreObserver.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 30.08.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import Foundation
import Promises
import StoreKit

enum StoreObserverError: Error {
	case deferredTransaction
	case missingTransactionError
}

class StoreObserver: NSObject {
	static let shared = StoreObserver()

	var isAuthorizedForPayments: Bool {
		return SKPaymentQueue.canMakePayments()
	}

	fileprivate var hasRestorablePurchases = false

	private var runningPayments = [String: Promise<SKPaymentTransaction>]()
	private var runningRestore: Promise<[SKPaymentTransaction]>?

	override private init() {}

	func buy(_ product: SKProduct) -> Promise<SKPaymentTransaction> {
		let payment = SKMutablePayment(product: product)
		let pendingPromise = Promise<SKPaymentTransaction>.pending()
		runningPayments[payment.productIdentifier] = pendingPromise
		SKPaymentQueue.default().add(payment)
		return pendingPromise
	}

	func restore() -> Promise<[SKPaymentTransaction]> {
		let pendingPromise = Promise<[SKPaymentTransaction]>.pending()
		runningRestore = pendingPromise
		SKPaymentQueue.default().restoreCompletedTransactions()
		return pendingPromise
	}

	fileprivate func handlePurchased(_ transaction: SKPaymentTransaction) {
		DDLogInfo("Purchased \(transaction.payment.productIdentifier)")
		guard let promise = runningPayments.removeValue(forKey: transaction.payment.productIdentifier) else {
			DDLogError("Missing running payment for fulfilling SKPayment promise")
			return
		}
		promise.fulfill(transaction)
		SKPaymentQueue.default().finishTransaction(transaction)
	}

	fileprivate func handleFailed(_ transaction: SKPaymentTransaction) {
		if let error = transaction.error {
			DDLogError("Purchase of \(transaction.payment.productIdentifier) failed with error: \(error)")
		} else {
			DDLogError("Purchase of \(transaction.payment.productIdentifier) failed")
		}
		guard let promise = runningPayments.removeValue(forKey: transaction.payment.productIdentifier) else {
			DDLogError("Missing running payment for rejecting SKPayment promise")
			return
		}
		if (transaction.error as? SKError)?.code != .paymentCancelled {
			promise.reject(transaction.error ?? StoreObserverError.missingTransactionError)
		}
		SKPaymentQueue.default().finishTransaction(transaction)
	}

	fileprivate func handleRestored(_ transactions: [SKPaymentTransaction]) {
		DDLogInfo("Restored \(transactions.map { $0.payment.productIdentifier }.joined(separator: ", "))")
		hasRestorablePurchases = true
		guard let promise = runningRestore else {
			DDLogError("Missing running restore for fulfilling promise")
			return
		}
		promise.fulfill(transactions)
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
			promise.fulfill([])
		}
	}
}
