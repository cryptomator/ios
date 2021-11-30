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
		storeObserver = StoreObserver(cryptomatorSettings: cryptomatorSettingsMock)

		SKPaymentQueue.default().remove(StoreObserver.shared)
		SKPaymentQueue.default().add(storeObserver)
	}

	override func tearDownWithError() throws {
		session.resetToDefaultState()
		session.clearTransactions()
	}

	// MARK: Buy Product

	func testBuyFreeTrial() throws {
		let expectation = XCTestExpectation()
		storeManager.fetchProducts(with: [.thirtyDayTrial]).then { response -> Promise<Void> in
			XCTAssertEqual(1, response.products.count)
			return self.storeObserver.buy(response.products[0])
		}.then {
			self.assertTrialStarted()
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
		fallbackDelegateMock.purchaseDidSucceedProductClosure = { product in
			XCTAssertEqual(.thirtyDayTrial, product)
			fallbackCalledExpectation.fulfill()
		}
		storeObserver.fallbackDelegate = fallbackDelegateMock

		assertBuyFailsWithDeferredTransactionError()
		try approveAskToBuyTransaction()

		wait(for: [fallbackCalledExpectation], timeout: 1.0)
		XCTAssertEqual(1, fallbackDelegateMock.purchaseDidSucceedProductCallsCount)
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
		storeManager.fetchProducts(with: [product]).then { response -> Promise<Void> in
			XCTAssertEqual(1, response.products.count)
			return self.storeObserver.buy(response.products[0])
		}.then {
			XCTAssert(self.cryptomatorSettingsMock.fullVersionUnlocked)
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	private func assertTrialStarted() {
		guard let excpectedDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) else {
			XCTFail("Could not create excpectedDate")
			return
		}
		guard let actualDate = cryptomatorSettingsMock.trialExpirationDate else {
			XCTFail("trialExpirationDate is nil")
			return
		}
		XCTAssertEqual(excpectedDate.timeIntervalSinceReferenceDate, actualDate.timeIntervalSinceReferenceDate, accuracy: 2.0)
	}

	private func assertBuyFailsWithDeferredTransactionError() {
		let askToBuyExpectation = XCTestExpectation()
		let fetchProductPromise = storeManager.fetchProducts(with: [.thirtyDayTrial])
		fetchProductPromise.then { response -> Promise<Void> in
			XCTAssertEqual(1, response.products.count)
			return self.storeObserver.buy(response.products[0])
		}.then {
			XCTFail("Promise fulfilled")
		}.catch { error in
			XCTAssertEqual(.deferredTransaction, error as? StoreObserverError)
		}.always {
			askToBuyExpectation.fulfill()
		}
		wait(for: [askToBuyExpectation], timeout: 1.0)
	}
}

private class StoreObserverDelegateMock: StoreObserverDelegate {
	// MARK: - purchaseDidSucceed

	var purchaseDidSucceedProductCallsCount = 0
	var purchaseDidSucceedProductCalled: Bool {
		purchaseDidSucceedProductCallsCount > 0
	}

	var purchaseDidSucceedProductReceivedProduct: ProductIdentifier?
	var purchaseDidSucceedProductReceivedInvocations: [ProductIdentifier] = []
	var purchaseDidSucceedProductClosure: ((ProductIdentifier) -> Void)?

	func purchaseDidSucceed(product: ProductIdentifier) {
		purchaseDidSucceedProductCallsCount += 1
		purchaseDidSucceedProductReceivedProduct = product
		purchaseDidSucceedProductReceivedInvocations.append(product)
		purchaseDidSucceedProductClosure?(product)
	}
}
