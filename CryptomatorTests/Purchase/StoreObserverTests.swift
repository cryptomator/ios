//
//  StoreObserverTests.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 29.11.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Promises
import StoreKit
import XCTest
@testable import Cryptomator
@testable import CryptomatorCommonCore

class StoreObserverTests: XCTestCase {
	var queue: PaymentQueuingMock!
	var storeObserver: StoreObserver!
	var cryptomatorSettingsMock: CryptomatorSettingsMock!
	var premiumManagerMock: PremiumManagerTypeMock!
	let dummyQueue = SKPaymentQueue()

	override func setUpWithError() throws {
		cryptomatorSettingsMock = CryptomatorSettingsMock()
		premiumManagerMock = PremiumManagerTypeMock()
		queue = PaymentQueuingMock()
		storeObserver = StoreObserver(queue: queue, cryptomatorSettings: cryptomatorSettingsMock, premiumManager: premiumManagerMock)
	}

	// MARK: Buy Product

	func testBuyFreeTrial() async throws {
		let product = makeSKProduct(identifier: .thirtyDayTrial, price: 0)
		let expectedDate = Date(timeIntervalSinceNow: 30 * 24 * 60 * 60)
		premiumManagerMock.trialExpirationDateForReturnValue = expectedDate

		queue.addPaymentClosure = { [unowned self] payment in
			let txn = PaymentTransactionMock(state: .purchased, payment: payment, transactionDate: Date())
			storeObserver.paymentQueue(dummyQueue, updatedTransactions: [txn])
		}

		let purchaseTransaction = try await storeObserver.buy(product).getValue()

		guard case let PurchaseTransaction.freeTrial(expiresOn) = purchaseTransaction else {
			XCTFail("Wrong purchaseTransaction: \(purchaseTransaction)")
			return
		}
		XCTAssertEqual(expectedDate.timeIntervalSinceReferenceDate, expiresOn.timeIntervalSinceReferenceDate, accuracy: 120.0)
		XCTAssertEqual(1, queue.addPaymentCallsCount)
		XCTAssertEqual(1, queue.finishTransactionCallsCount)
		XCTAssertEqual(1, premiumManagerMock.refreshStatusCallsCount)
	}

	func testBuyFullVersion() async throws {
		try await assertFullVersionUnlockedWhenBuying(product: .fullVersion)
		try await assertFullVersionUnlockedWhenBuying(product: .paidUpgrade)
		try await assertFullVersionUnlockedWhenBuying(product: .freeUpgrade)
	}

	// MARK: Deferred Transactions (Ask to buy)

	/// Only test the approved case as there is no transaction state changes if the transaction gets declined
	/// see https://developer.apple.com/forums/thread/685183
	func testAskToBuy() async throws {
		let product = makeSKProduct(identifier: .thirtyDayTrial, price: 0)
		let expectedDate = Date(timeIntervalSinceNow: 30 * 24 * 60 * 60)
		premiumManagerMock.trialExpirationDateForReturnValue = expectedDate

		queue.addPaymentClosure = { [unowned self] payment in
			let txn = PaymentTransactionMock(state: .deferred, payment: payment)
			storeObserver.paymentQueue(dummyQueue, updatedTransactions: [txn])
		}

		do {
			_ = try await storeObserver.buy(product).getValue()
			XCTFail("Buy did not fail")
		} catch {
			XCTAssertEqual(.deferredTransaction, error as? StoreObserverError)
		}

		XCTAssertEqual(0, queue.finishTransactionCallsCount)

		// Simulate the later approval via fallback delegate
		let fallbackCalledExpectation = XCTestExpectation()
		let fallbackDelegateMock = StoreObserverDelegateMock()
		fallbackDelegateMock.purchaseDidSucceedTransactionClosure = { transaction in
			guard case let PurchaseTransaction.freeTrial(expiresOn) = transaction else {
				XCTFail("Wrong purchaseTransaction: \(transaction)")
				return
			}
			XCTAssertEqual(expectedDate.timeIntervalSinceReferenceDate, expiresOn.timeIntervalSinceReferenceDate, accuracy: 120.0)
			fallbackCalledExpectation.fulfill()
		}
		storeObserver.fallbackDelegate = fallbackDelegateMock

		let payment = SKPayment(product: product)
		let approvedTxn = PaymentTransactionMock(state: .purchased, payment: payment, transactionDate: Date())
		storeObserver.paymentQueue(dummyQueue, updatedTransactions: [approvedTxn])

		await fulfillment(of: [fallbackCalledExpectation])
		XCTAssertEqual(1, fallbackDelegateMock.purchaseDidSucceedTransactionCallsCount)
		XCTAssertEqual(1, queue.finishTransactionCallsCount)
	}

	// MARK: Failed Transactions

	func testBuyFailedWithError() async throws {
		let product = makeSKProduct(identifier: .fullVersion, price: 11.99)
		let expectedError = NSError(domain: SKErrorDomain, code: SKError.paymentCancelled.rawValue)

		queue.addPaymentClosure = { [unowned self] payment in
			let txn = PaymentTransactionMock(state: .failed, payment: payment, error: expectedError)
			storeObserver.paymentQueue(dummyQueue, updatedTransactions: [txn])
		}

		do {
			_ = try await storeObserver.buy(product).getValue()
			XCTFail("Buy did not fail")
		} catch {
			XCTAssertEqual(expectedError, error as NSError)
		}
		XCTAssertEqual(1, queue.finishTransactionCallsCount)
		XCTAssertEqual(1, premiumManagerMock.refreshStatusCallsCount)
	}

	func testBuyFailedWithoutError() async throws {
		let product = makeSKProduct(identifier: .fullVersion, price: 11.99)

		queue.addPaymentClosure = { [unowned self] payment in
			let txn = PaymentTransactionMock(state: .failed, payment: payment)
			storeObserver.paymentQueue(dummyQueue, updatedTransactions: [txn])
		}

		do {
			_ = try await storeObserver.buy(product).getValue()
			XCTFail("Buy did not fail")
		} catch {
			XCTAssertEqual(.missingTransactionError, error as? StoreObserverError)
		}
		XCTAssertEqual(1, queue.finishTransactionCallsCount)
		XCTAssertEqual(1, premiumManagerMock.refreshStatusCallsCount)
	}

	// MARK: Buy Product Variants

	func testBuyYearlySubscription() async throws {
		let product = makeSKProduct(identifier: .yearlySubscription, price: 11.99)

		queue.addPaymentClosure = { [unowned self] payment in
			let txn = PaymentTransactionMock(state: .purchased, payment: payment)
			storeObserver.paymentQueue(dummyQueue, updatedTransactions: [txn])
		}

		let purchaseTransaction = try await storeObserver.buy(product).getValue()

		XCTAssertEqual(.yearlySubscription, purchaseTransaction)
		XCTAssertEqual(1, queue.addPaymentCallsCount)
		XCTAssertEqual(1, queue.finishTransactionCallsCount)
		XCTAssertEqual(1, premiumManagerMock.refreshStatusCallsCount)
	}

	func testBuyUnknownProduct() async throws {
		let product = SKProduct()
		product.setValue("com.unknown.product", forKey: "productIdentifier")
		product.setValue(NSDecimalNumber(value: 9.99), forKey: "price")
		product.setValue(Locale(identifier: "en_US"), forKey: "priceLocale")

		queue.addPaymentClosure = { [unowned self] payment in
			let txn = PaymentTransactionMock(state: .purchased, payment: payment)
			storeObserver.paymentQueue(dummyQueue, updatedTransactions: [txn])
		}

		let purchaseTransaction = try await storeObserver.buy(product).getValue()

		XCTAssertEqual(.unknown, purchaseTransaction)
		XCTAssertEqual(1, queue.addPaymentCallsCount)
		XCTAssertEqual(1, queue.finishTransactionCallsCount)
		XCTAssertEqual(1, premiumManagerMock.refreshStatusCallsCount)
	}

	func testBuyFreeTrialWithNilTransactionDate() async throws {
		let product = makeSKProduct(identifier: .thirtyDayTrial, price: 0)

		queue.addPaymentClosure = { [unowned self] payment in
			let txn = PaymentTransactionMock(state: .purchased, payment: payment)
			storeObserver.paymentQueue(dummyQueue, updatedTransactions: [txn])
		}

		let purchaseTransaction = try await storeObserver.buy(product).getValue()

		XCTAssertEqual(.unknown, purchaseTransaction)
		XCTAssertEqual(1, queue.addPaymentCallsCount)
		XCTAssertEqual(1, queue.finishTransactionCallsCount)
		XCTAssertEqual(1, premiumManagerMock.refreshStatusCallsCount)
	}

	func testBuyFreeTrialWithOriginalTransaction() async throws {
		let product = makeSKProduct(identifier: .thirtyDayTrial, price: 0)
		let originalDate = Date(timeIntervalSinceNow: -7 * 24 * 60 * 60)
		let expectedDate = Date(timeIntervalSinceNow: 23 * 24 * 60 * 60)
		premiumManagerMock.trialExpirationDateForReturnValue = expectedDate

		queue.addPaymentClosure = { [unowned self] payment in
			let originalTxn = PaymentTransactionMock(state: .purchased, payment: payment, transactionDate: originalDate)
			let txn = PaymentTransactionMock(state: .purchased, payment: payment, transactionDate: Date(), original: originalTxn)
			storeObserver.paymentQueue(dummyQueue, updatedTransactions: [txn])
		}

		let purchaseTransaction = try await storeObserver.buy(product).getValue()

		guard case let PurchaseTransaction.freeTrial(expiresOn) = purchaseTransaction else {
			XCTFail("Wrong purchaseTransaction: \(purchaseTransaction)")
			return
		}
		XCTAssertEqual(expectedDate.timeIntervalSinceReferenceDate, expiresOn.timeIntervalSinceReferenceDate, accuracy: 120.0)
		XCTAssertEqual(originalDate.timeIntervalSinceReferenceDate, try XCTUnwrap(premiumManagerMock.trialExpirationDateForReceivedPurchaseDate?.timeIntervalSinceReferenceDate), accuracy: 1.0)
		XCTAssertEqual(1, queue.addPaymentCallsCount)
		XCTAssertEqual(1, queue.finishTransactionCallsCount)
		XCTAssertEqual(1, premiumManagerMock.refreshStatusCallsCount)
	}

	// MARK: Restore Transactions

	func testRestoreRunningSubscription() async throws {
		let cryptomatorSettingsMock = CryptomatorSettingsMock()
		cryptomatorSettingsMock.hasRunningSubscription = true
		try await assertRestored(with: .restoredFullVersion, cryptomatorSettings: cryptomatorSettingsMock)
	}

	func testRestoreLifetimePremium() async throws {
		let cryptomatorSettingsMock = CryptomatorSettingsMock()
		cryptomatorSettingsMock.fullVersionUnlocked = true
		try await assertRestored(with: .restoredFullVersion, cryptomatorSettings: cryptomatorSettingsMock)
	}

	func testRestoreTrial() async throws {
		let cryptomatorSettingsMock = CryptomatorSettingsMock()
		let trialExpirationDate = Date.distantFuture
		cryptomatorSettingsMock.trialExpirationDate = trialExpirationDate
		try await assertRestored(with: .restoredFreeTrial(expiresOn: trialExpirationDate), cryptomatorSettings: cryptomatorSettingsMock)
	}

	func testRestoreExpiredTrial() async throws {
		let cryptomatorSettingsMock = CryptomatorSettingsMock()
		let trialExpirationDate = Date.distantPast
		cryptomatorSettingsMock.trialExpirationDate = trialExpirationDate
		try await assertRestored(with: .noRestorablePurchases, cryptomatorSettings: cryptomatorSettingsMock)
	}

	func testRestoreNothing() async throws {
		let cryptomatorSettingsMock = CryptomatorSettingsMock()
		try await assertRestored(with: .noRestorablePurchases, cryptomatorSettings: cryptomatorSettingsMock)
	}

	func testRestoreFailedWithError() async throws {
		let expectedError = NSError(domain: SKErrorDomain, code: SKError.unknown.rawValue)
		let premiumManagerMock = PremiumManagerTypeMock()
		let queue = PaymentQueuingMock()
		let storeObserver = StoreObserver(queue: queue, cryptomatorSettings: cryptomatorSettingsMock, premiumManager: premiumManagerMock)

		queue.restoreCompletedTransactionsClosure = {
			storeObserver.paymentQueue(self.dummyQueue, restoreCompletedTransactionsFailedWithError: expectedError)
		}

		do {
			_ = try await storeObserver.restore().getValue()
			XCTFail("Restore did not fail")
		} catch {
			XCTAssertEqual(expectedError, error as NSError)
		}
		XCTAssertEqual(0, premiumManagerMock.refreshStatusCallsCount)
	}

	func testRestoredTransactionsViaUpdatedTransactions() {
		let product1 = makeSKProduct(identifier: .fullVersion, price: 11.99)
		let product2 = makeSKProduct(identifier: .yearlySubscription, price: 11.99)
		let txn1 = PaymentTransactionMock(state: .restored, payment: SKPayment(product: product1))
		let txn2 = PaymentTransactionMock(state: .restored, payment: SKPayment(product: product2))

		storeObserver.paymentQueue(dummyQueue, updatedTransactions: [txn1, txn2])

		XCTAssertEqual(2, queue.finishTransactionCallsCount)
		XCTAssertTrue(queue.finishTransactionReceivedInvocations.contains(where: { $0 === txn1 }))
		XCTAssertTrue(queue.finishTransactionReceivedInvocations.contains(where: { $0 === txn2 }))
		XCTAssertEqual(1, premiumManagerMock.refreshStatusCallsCount)
	}

	func testRestoreFailedWithNilRunningRestore() {
		let error = NSError(domain: SKErrorDomain, code: SKError.unknown.rawValue)
		storeObserver.paymentQueue(dummyQueue, restoreCompletedTransactionsFailedWithError: error)
		XCTAssertEqual(0, premiumManagerMock.refreshStatusCallsCount)
	}

	// MARK: Entitlement Revocation

	func testDidRevokeEntitlements() {
		storeObserver.paymentQueue(dummyQueue, didRevokeEntitlementsForProductIdentifiers: [ProductIdentifier.fullVersion.rawValue])
		XCTAssertEqual(1, premiumManagerMock.refreshStatusCallsCount)
	}

	// MARK: Unsolicited Transaction Callbacks

	func testFailedTransactionWithoutRunningPayment() {
		let product = makeSKProduct(identifier: .fullVersion, price: 11.99)
		let txn = PaymentTransactionMock(state: .failed, payment: SKPayment(product: product))
		storeObserver.paymentQueue(dummyQueue, updatedTransactions: [txn])
		XCTAssertEqual(1, queue.finishTransactionCallsCount)
		XCTAssertEqual(1, premiumManagerMock.refreshStatusCallsCount)
	}

	func testDeferredTransactionWithoutRunningPayment() {
		let product = makeSKProduct(identifier: .fullVersion, price: 11.99)
		let txn = PaymentTransactionMock(state: .deferred, payment: SKPayment(product: product))
		storeObserver.paymentQueue(dummyQueue, updatedTransactions: [txn])
		XCTAssertEqual(0, queue.finishTransactionCallsCount)
		XCTAssertEqual(1, premiumManagerMock.refreshStatusCallsCount)
	}

	func testRemovedTransactions() {
		let product = makeSKProduct(identifier: .fullVersion, price: 11.99)
		let txn = PaymentTransactionMock(state: .purchased, payment: SKPayment(product: product))
		storeObserver.paymentQueue(dummyQueue, removedTransactions: [txn])
		XCTAssertEqual(0, queue.finishTransactionCallsCount)
		XCTAssertEqual(0, premiumManagerMock.refreshStatusCallsCount)
	}

	func testPurchasingTransactionIsNoOp() {
		let product = makeSKProduct(identifier: .fullVersion, price: 11.99)
		let txn = PaymentTransactionMock(state: .purchasing, payment: SKPayment(product: product))
		storeObserver.paymentQueue(dummyQueue, updatedTransactions: [txn])
		XCTAssertEqual(0, queue.finishTransactionCallsCount)
		XCTAssertEqual(1, premiumManagerMock.refreshStatusCallsCount)
	}

	// MARK: - Internal

	private func makeSKProduct(identifier: ProductIdentifier, price: NSDecimalNumber, locale: Locale = Locale(identifier: "en_US")) -> SKProduct {
		let product = SKProduct()
		product.setValue(identifier.rawValue, forKey: "productIdentifier")
		product.setValue(price, forKey: "price")
		product.setValue(locale, forKey: "priceLocale")
		return product
	}

	private func assertFullVersionUnlockedWhenBuying(product identifier: ProductIdentifier, file: StaticString = #filePath, line: UInt = #line) async throws {
		let product = makeSKProduct(identifier: identifier, price: 11.99)
		let premiumManagerMock = PremiumManagerTypeMock()
		let queue = PaymentQueuingMock()
		let storeObserver = StoreObserver(queue: queue, cryptomatorSettings: cryptomatorSettingsMock, premiumManager: premiumManagerMock)

		queue.addPaymentClosure = { payment in
			let txn = PaymentTransactionMock(state: .purchased, payment: payment)
			storeObserver.paymentQueue(self.dummyQueue, updatedTransactions: [txn])
		}

		let purchaseTransaction = try await storeObserver.buy(product).getValue()

		XCTAssertEqual(.fullVersion, purchaseTransaction, file: file, line: line)
		XCTAssertEqual(1, queue.addPaymentCallsCount, file: file, line: line)
		XCTAssertEqual(1, queue.finishTransactionCallsCount, file: file, line: line)
		XCTAssertEqual(1, premiumManagerMock.refreshStatusCallsCount, file: file, line: line)
	}

	private func assertRestored(with expectedResult: RestoreTransactionsResult, cryptomatorSettings: CryptomatorSettings, file: StaticString = #filePath, line: UInt = #line) async throws {
		let premiumManagerMock = PremiumManagerTypeMock()
		let queue = PaymentQueuingMock()
		let storeObserver = StoreObserver(queue: queue, cryptomatorSettings: cryptomatorSettings, premiumManager: premiumManagerMock)

		queue.restoreCompletedTransactionsClosure = {
			storeObserver.paymentQueueRestoreCompletedTransactionsFinished(self.dummyQueue)
		}

		let result = try await storeObserver.restore().getValue()
		XCTAssertEqual(expectedResult, result, file: file, line: line)
		XCTAssert(premiumManagerMock.refreshStatusCalled, file: file, line: line)
	}
}

private class StoreObserverDelegateMock: StoreObserverDelegate {
	// MARK: - purchaseDidSucceed

	var purchaseDidSucceedTransactionCallsCount = 0
	var purchaseDidSucceedTransactionCalled: Bool {
		purchaseDidSucceedTransactionCallsCount > 0
	}

	var purchaseDidSucceedTransactionReceivedTransaction: PurchaseTransaction?
	var purchaseDidSucceedTransactionReceivedInvocations: [PurchaseTransaction] = []
	var purchaseDidSucceedTransactionClosure: ((PurchaseTransaction) -> Void)?

	func purchaseDidSucceed(transaction: PurchaseTransaction) {
		purchaseDidSucceedTransactionCallsCount += 1
		purchaseDidSucceedTransactionReceivedTransaction = transaction
		purchaseDidSucceedTransactionReceivedInvocations.append(transaction)
		purchaseDidSucceedTransactionClosure?(transaction)
	}
}
