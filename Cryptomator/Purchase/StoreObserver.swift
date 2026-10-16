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
import StoreKit

protocol PaymentQueuing {
	func add(_ observer: SKPaymentTransactionObserver)
	func remove(_ observer: SKPaymentTransactionObserver)
	func add(_ payment: SKPayment)
	func restoreCompletedTransactions()
	func finishTransaction(_ transaction: SKPaymentTransaction)
}

extension SKPaymentQueue: PaymentQueuing {}

protocol IAPManager {
	var isAuthorizedForPayments: Bool { get }
	func buy(_ product: SKProduct) async throws -> PurchaseTransaction
	func restore() async throws -> RestoreTransactionsResult
}

enum StoreObserverError: Error {
	case deferredTransaction
	case missingTransactionError
}

protocol StoreObserverDelegate: AnyObject {
	func purchaseDidSucceed(transaction: PurchaseTransaction)
}

enum RestoreTransactionsResult: Equatable, Sendable {
	case restoredFullVersion
	case restoredFreeTrial(expiresOn: Date)
	case noRestorablePurchases
}

enum PurchaseTransaction: Equatable, Sendable {
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

	private var runningPayments = [String: OneShotSignal<PurchaseTransaction>]()
	private var runningRestore: OneShotSignal<RestoreTransactionsResult>?
	private var cryptomatorSettings: CryptomatorSettings
	private let premiumManager: PremiumManagerType
	private let queue: PaymentQueuing

	init(queue: PaymentQueuing = SKPaymentQueue.default(), cryptomatorSettings: CryptomatorSettings, premiumManager: PremiumManagerType) {
		self.queue = queue
		self.cryptomatorSettings = cryptomatorSettings
		self.premiumManager = premiumManager
	}

	func buy(_ product: SKProduct) async throws -> PurchaseTransaction {
		DDLogInfo("Buy product: \(product.productIdentifier)")
		let payment = SKMutablePayment(product: product)
		let transaction = OneShotSignal<PurchaseTransaction>()
		runningPayments[payment.productIdentifier] = transaction
		queue.add(payment)
		return try await transaction.value
	}

	func restore() async throws -> RestoreTransactionsResult {
		let result = OneShotSignal<RestoreTransactionsResult>()
		runningRestore = result
		queue.restoreCompletedTransactions()
		return try await result.value
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
		queue.finishTransaction(transaction)
		guard let runningPayment = runningPayments.removeValue(forKey: transaction.payment.productIdentifier) else {
			fallbackDelegate?.purchaseDidSucceed(transaction: transactionType)
			return
		}
		runningPayment.fulfill(transactionType)
	}

	fileprivate func handleFailed(_ transaction: SKPaymentTransaction) {
		if let error = transaction.error {
			DDLogError("Purchase of \(transaction.payment.productIdentifier) failed with error: \(error)")
		} else {
			DDLogError("Purchase of \(transaction.payment.productIdentifier) failed")
		}
		queue.finishTransaction(transaction)
		guard let runningPayment = runningPayments.removeValue(forKey: transaction.payment.productIdentifier) else {
			return
		}
		runningPayment.reject(transaction.error ?? StoreObserverError.missingTransactionError)
	}

	fileprivate func handleRestored(_ transactions: [SKPaymentTransaction]) {
		DDLogInfo("Restored \(transactions.map { $0.payment.productIdentifier }.joined(separator: ", "))")
		for transaction in transactions {
			queue.finishTransaction(transaction)
		}
	}

	fileprivate func handleDeferred(_ transaction: SKPaymentTransaction) {
		DDLogInfo("Deferred purchase of \(transaction.payment.productIdentifier)")
		guard let runningPayment = runningPayments.removeValue(forKey: transaction.payment.productIdentifier) else {
			DDLogError("Missing running payment for rejecting SKPayment")
			return
		}
		// https://stackoverflow.com/q/26187148/1759462
		runningPayment.reject(StoreObserverError.deferredTransaction)
	}

	// MARK: - Store Logic

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
	nonisolated func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
		DispatchQueue.main.async {
			self.handleUpdatedTransactions(transactions)
		}
	}

	nonisolated func paymentQueue(_ queue: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction]) {
		for transaction in transactions {
			DDLogInfo("Removed \(transaction.payment.productIdentifier) from the payment queue")
		}
	}

	nonisolated func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
		DDLogError("Restoring completed transactions failed with error: \(error)")
		DispatchQueue.main.async {
			guard let runningRestore = self.runningRestore else {
				DDLogError("Missing running restore to reject")
				return
			}
			runningRestore.reject(error)
		}
	}

	nonisolated func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
		DDLogInfo("Restoring completed transactions finished")
		DispatchQueue.main.async {
			self.handleRestoreCompletedTransactionsFinished()
		}
	}

	nonisolated func paymentQueue(_ queue: SKPaymentQueue, didRevokeEntitlementsForProductIdentifiers productIdentifiers: [String]) {
		DDLogInfo("Revoke entitlements for product identifiers: \(productIdentifiers)")
		DispatchQueue.main.async {
			self.premiumManager.refreshStatus()
		}
	}

	private func handleUpdatedTransactions(_ transactions: [SKPaymentTransaction]) {
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

	private func handleRestoreCompletedTransactionsFinished() {
		premiumManager.refreshStatus()
		if cryptomatorSettings.hasRunningSubscription || cryptomatorSettings.fullVersionUnlocked {
			runningRestore?.fulfill(.restoredFullVersion)
		} else if let trialExpirationDate = cryptomatorSettings.trialExpirationDate, trialExpirationDate > Date() {
			runningRestore?.fulfill(.restoredFreeTrial(expiresOn: trialExpirationDate))
		} else {
			runningRestore?.fulfill(.noRestorablePurchases)
		}
	}
}
