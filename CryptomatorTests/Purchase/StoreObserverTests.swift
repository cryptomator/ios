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

	func testBuyFreeTrial() async throws {
		let response = try await storeManager.fetchProducts(with: [.thirtyDayTrial]).getValue()
		XCTAssertEqual(1, response.products.count)

		let purchaseTransaction = try await storeObserver.buy(response.products[0]).getValue()
		try assertTrialStarted(purchaseTransaction: purchaseTransaction)
	}

	func testBuyFullVersion() async throws {
		try await assertFullVersionUnlockedWhenBuying(product: .fullVersion)
		try await assertFullVersionUnlockedWhenBuying(product: .paidUpgrade)
		try await assertFullVersionUnlockedWhenBuying(product: .freeUpgrade)
	}

	// MARK: Deferred Transactions (Ask to buy)

	// Only test the approved case as there is no transaction state changes if the transaction gets declined
	// see https://developer.apple.com/forums/thread/685183
	func testAskToBuy() async throws {
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

		try await assertBuyFailsWithDeferredTransactionError()
		try approveAskToBuyTransaction()

		await fulfillment(of: [fallbackCalledExpectation])
		XCTAssertEqual(1, fallbackDelegateMock.purchaseDidSucceedTransactionCallsCount)
	}

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

	private func assertFullVersionUnlockedWhenBuying(product: ProductIdentifier, file: StaticString = #filePath, line: UInt = #line) async throws {
		let response = try await storeManager.fetchProducts(with: [product]).getValue()
		XCTAssertEqual(1, response.products.count)

		let purchaseTransaction = try await storeObserver.buy(response.products[0]).getValue()

		XCTAssertEqual(.fullVersion, purchaseTransaction)
		XCTAssert(cryptomatorSettingsMock.fullVersionUnlocked)
	}

	private func assertTrialStarted(purchaseTransaction: PurchaseTransaction) throws {
		let expectedDate = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 30, to: Date()))
		guard case let PurchaseTransaction.freeTrial(expiresOn) = purchaseTransaction else {
			XCTFail("Wrong purchaseTransaction: \(purchaseTransaction)")
			return
		}

		// decrease the accuracy to 2 minutes to increase stability of the unit tests in the CI.
		XCTAssertEqual(expectedDate.timeIntervalSinceReferenceDate, expiresOn.timeIntervalSinceReferenceDate, accuracy: 120.0)

		let actualDate = try XCTUnwrap(cryptomatorSettingsMock.trialExpirationDate, "trialExpirationDate was not set")
		XCTAssertEqual(expectedDate.timeIntervalSinceReferenceDate, actualDate.timeIntervalSinceReferenceDate, accuracy: 120.0)
	}

	private func assertBuyFailsWithDeferredTransactionError(file: StaticString = #filePath, line: UInt = #line) async throws {
		let response = try await storeManager.fetchProducts(with: [.thirtyDayTrial]).getValue()

		XCTAssertEqual(1, response.products.count)

		do {
			_ = try await storeObserver.buy(response.products[0]).getValue()
			XCTFail("Buy did not fail", file: file, line: line)
		} catch {
			XCTAssertEqual(.deferredTransaction, error as? StoreObserverError)
		}
	}

	private func assertRestored(with expectedResult: RestoreTransactionsResult, cryptomatorSettings: CryptomatorSettings, file: StaticString = #filePath, line: UInt = #line) async throws {
		let premiumManagerMock = PremiumManagerTypeMock()
		let storeObserver = StoreObserver(cryptomatorSettings: cryptomatorSettings, premiumManager: premiumManagerMock)

		SKPaymentQueue.default().add(storeObserver)
		SKPaymentQueue.default().remove(self.storeObserver)

		let result = try await storeObserver.restore().getValue()
		XCTAssertEqual(expectedResult, result)
		XCTAssert(premiumManagerMock.refreshStatusCalled)
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
		for transactionObserver in transactionObservers {
			remove(transactionObserver)
		}
	}
}
