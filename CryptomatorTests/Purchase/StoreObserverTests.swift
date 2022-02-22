//
//  StoreObserverTests.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 29.11.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Promises
import StoreKitTest
import XCTest
@testable import Cryptomator
@testable import CryptomatorCommonCore

@available(iOS 14.0, *)
class StoreObserverTests: XCTestCase {
	var session: SKTestSession!
	var storeManager: StoreManager!
	var storeObserver: StoreObserver!
	var cryptomatorSettingsMock: CryptomatorSettingsMock!

	override func setUpWithError() throws {
		session = try SKTestSession(configurationFileNamed: "Configuration")
		session.resetToDefaultState()
		session.disableDialogs = true
		session.clearTransactions()

		cryptomatorSettingsMock = CryptomatorSettingsMock()
		storeManager = StoreManager.shared
		storeObserver = StoreObserver(cryptomatorSettings: cryptomatorSettingsMock, premiumManager: PremiumManager(cryptomatorSettings: cryptomatorSettingsMock))

		SKPaymentQueue.default().removeAllObservers()
		SKPaymentQueue.default().add(storeObserver)
		XCTAssertEqual(1, SKPaymentQueue.default().transactionObservers.count)
		XCTAssert(SKPaymentQueue.default().transactionObservers.contains(where: { $0 === storeObserver }))
	}

	override func tearDownWithError() throws {
		session.resetToDefaultState()
		session.clearTransactions()
	}

	// MARK: Buy Product

	func testBuyFreeTrial() throws {
		let expectation = XCTestExpectation()
		storeManager.fetchProducts(with: [.thirtyDayTrial]).then { response -> Promise<PurchaseTransaction> in
			XCTAssertEqual(1, response.products.count)
			return self.storeObserver.buy(response.products[0])
		}.then { purchaseTransaction in
			try self.assertTrialStarted(purchaseTransaction: purchaseTransaction)
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testBuyFullVersion() throws {
		assertFullVersionUnlockedWhenBuying(product: .fullVersion)
		assertFullVersionUnlockedWhenBuying(product: .paidUpgrade)
		assertFullVersionUnlockedWhenBuying(product: .freeUpgrade)
	}

	// MARK: Deferred Transactions (Ask to buy)

	// Only test the approved case as there is no transaction state changes if the transaction gets declined
	// see https://developer.apple.com/forums/thread/685183
	func testAskToBuy() throws {
		session.askToBuyEnabled = true
		XCTAssert(session.allTransactions().isEmpty)

		let fallbackCalledExpectation = XCTestExpectation()
		let fallbackDelegateMock = StoreObserverDelegateMock()
		fallbackDelegateMock.purchaseDidSucceedTransactionClosure = { transaction in
			do {
				try self.assertTrialStarted(purchaseTransaction: transaction)
			} catch {
				XCTFail("assertTrialStarted failed with error: \(error)")
			}

			fallbackCalledExpectation.fulfill()
		}
		storeObserver.fallbackDelegate = fallbackDelegateMock

		assertBuyFailsWithDeferredTransactionError()
		try approveAskToBuyTransaction()

		wait(for: [fallbackCalledExpectation], timeout: 1.0)
		XCTAssertEqual(1, fallbackDelegateMock.purchaseDidSucceedTransactionCallsCount)
	}

	func testRestoreRunningSubscription() {
		let cryptomatorSettingsMock = CryptomatorSettingsMock()
		cryptomatorSettingsMock.hasRunningSubscription = true
		assertRestored(with: .restoredFullVersion, cryptomatorSettings: cryptomatorSettingsMock)
	}

	func testRestoreLifetimePremium() {
		let cryptomatorSettingsMock = CryptomatorSettingsMock()
		cryptomatorSettingsMock.fullVersionUnlocked = true
		assertRestored(with: .restoredFullVersion, cryptomatorSettings: cryptomatorSettingsMock)
	}

	func testRestoreTrial() {
		let cryptomatorSettingsMock = CryptomatorSettingsMock()
		let trialExpirationDate = Date.distantFuture
		cryptomatorSettingsMock.trialExpirationDate = trialExpirationDate
		assertRestored(with: .restoredFreeTrial(expiresOn: trialExpirationDate), cryptomatorSettings: cryptomatorSettingsMock)
	}

	func testRestoreExpiredTrial() {
		let cryptomatorSettingsMock = CryptomatorSettingsMock()
		let trialExpirationDate = Date.distantPast
		cryptomatorSettingsMock.trialExpirationDate = trialExpirationDate
		assertRestored(with: .noRestorablePurchases, cryptomatorSettings: cryptomatorSettingsMock)
	}

	func testRestoreNothing() {
		let cryptomatorSettingsMock = CryptomatorSettingsMock()
		assertRestored(with: .noRestorablePurchases, cryptomatorSettings: cryptomatorSettingsMock)
	}

	// MARK: - Internal

	private func approveAskToBuyTransaction() throws {
		let transactions = session.allTransactions()
		XCTAssertEqual(1, transactions.count)
		guard let deferredTransaction = transactions.first else {
			XCTFail("StoreKit session transactions are empty")
			return
		}
		try session.approveAskToBuyTransaction(identifier: deferredTransaction.identifier)
	}

	private func assertFullVersionUnlockedWhenBuying(product: ProductIdentifier) {
		let expectation = XCTestExpectation()
		storeManager.fetchProducts(with: [product]).then { response -> Promise<PurchaseTransaction> in
			XCTAssertEqual(1, response.products.count)
			return self.storeObserver.buy(response.products[0])
		}.then { purchaseTransaction in
			XCTAssertEqual(.fullVersion, purchaseTransaction)
			XCTAssert(self.cryptomatorSettingsMock.fullVersionUnlocked)
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	private func assertTrialStarted(purchaseTransaction: PurchaseTransaction) throws {
		let expectedDate = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 30, to: Date()))
		guard case let PurchaseTransaction.freeTrial(expiresOn) = purchaseTransaction else {
			XCTFail("Wrong purchaseTransaction: \(purchaseTransaction)")
			return
		}
		XCTAssertEqual(expectedDate.timeIntervalSinceReferenceDate, expiresOn.timeIntervalSinceReferenceDate, accuracy: 2.0)

		let actualDate = try XCTUnwrap(cryptomatorSettingsMock.trialExpirationDate, "trialExpirationDate was not set")
		XCTAssertEqual(expectedDate.timeIntervalSinceReferenceDate, actualDate.timeIntervalSinceReferenceDate, accuracy: 2.0)
	}

	private func assertBuyFailsWithDeferredTransactionError() {
		let askToBuyExpectation = XCTestExpectation()
		let fetchProductPromise = storeManager.fetchProducts(with: [.thirtyDayTrial])
		fetchProductPromise.then { response -> Promise<PurchaseTransaction> in
			XCTAssertEqual(1, response.products.count)
			return self.storeObserver.buy(response.products[0])
		}.then { _ in
			XCTFail("Promise fulfilled")
		}.catch { error in
			XCTAssertEqual(.deferredTransaction, error as? StoreObserverError)
		}.always {
			askToBuyExpectation.fulfill()
		}
		wait(for: [askToBuyExpectation], timeout: 1.0)
	}

	private func assertRestored(with expectedResult: RestoreTransactionsResult, cryptomatorSettings: CryptomatorSettings) {
		let expectation = XCTestExpectation()
		let premiumManagerMock = PremiumManagerTypeMock()
		let storeObserver = StoreObserver(cryptomatorSettings: cryptomatorSettings, premiumManager: premiumManagerMock)

		SKPaymentQueue.default().add(storeObserver)
		SKPaymentQueue.default().remove(self.storeObserver)

		storeObserver.restore().then { result in
			XCTAssertEqual(expectedResult, result)
			XCTAssert(premiumManagerMock.refreshStatusCalled)
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
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

@available(iOS 14.0, *)
extension SKPaymentQueue {
	func removeAllObservers() {
		transactionObservers.forEach {
			remove($0)
		}
	}
}
