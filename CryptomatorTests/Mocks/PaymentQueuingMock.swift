//
//  PaymentQueuingMock.swift
//  CryptomatorTests
//
//  Created by Tobias Hagemann on 03.04.26.
//  Copyright © 2026 Skymatic GmbH. All rights reserved.
//

import Foundation
import StoreKit
@testable import Cryptomator

// swiftlint:disable all

final class PaymentQueuingMock: PaymentQueuing {
	// MARK: - add (observer)

	var addObserverCallsCount = 0
	var addObserverCalled: Bool {
		addObserverCallsCount > 0
	}

	var addObserverReceivedObserver: SKPaymentTransactionObserver?
	var addObserverReceivedInvocations: [SKPaymentTransactionObserver] = []
	var addObserverClosure: ((SKPaymentTransactionObserver) -> Void)?

	func add(_ observer: SKPaymentTransactionObserver) {
		addObserverCallsCount += 1
		addObserverReceivedObserver = observer
		addObserverReceivedInvocations.append(observer)
		addObserverClosure?(observer)
	}

	// MARK: - remove (observer)

	var removeCallsCount = 0
	var removeCalled: Bool {
		removeCallsCount > 0
	}

	var removeReceivedObserver: SKPaymentTransactionObserver?
	var removeReceivedInvocations: [SKPaymentTransactionObserver] = []
	var removeClosure: ((SKPaymentTransactionObserver) -> Void)?

	func remove(_ observer: SKPaymentTransactionObserver) {
		removeCallsCount += 1
		removeReceivedObserver = observer
		removeReceivedInvocations.append(observer)
		removeClosure?(observer)
	}

	// MARK: - add (payment)

	var addPaymentCallsCount = 0
	var addPaymentCalled: Bool {
		addPaymentCallsCount > 0
	}

	var addPaymentReceivedPayment: SKPayment?
	var addPaymentReceivedInvocations: [SKPayment] = []
	var addPaymentClosure: ((SKPayment) -> Void)?

	func add(_ payment: SKPayment) {
		addPaymentCallsCount += 1
		addPaymentReceivedPayment = payment
		addPaymentReceivedInvocations.append(payment)
		addPaymentClosure?(payment)
	}

	// MARK: - restoreCompletedTransactions

	var restoreCompletedTransactionsCallsCount = 0
	var restoreCompletedTransactionsCalled: Bool {
		restoreCompletedTransactionsCallsCount > 0
	}

	var restoreCompletedTransactionsClosure: (() -> Void)?

	func restoreCompletedTransactions() {
		restoreCompletedTransactionsCallsCount += 1
		restoreCompletedTransactionsClosure?()
	}

	// MARK: - finishTransaction

	var finishTransactionCallsCount = 0
	var finishTransactionCalled: Bool {
		finishTransactionCallsCount > 0
	}

	var finishTransactionReceivedTransaction: SKPaymentTransaction?
	var finishTransactionReceivedInvocations: [SKPaymentTransaction] = []
	var finishTransactionClosure: ((SKPaymentTransaction) -> Void)?

	func finishTransaction(_ transaction: SKPaymentTransaction) {
		finishTransactionCallsCount += 1
		finishTransactionReceivedTransaction = transaction
		finishTransactionReceivedInvocations.append(transaction)
		finishTransactionClosure?(transaction)
	}
}

// swiftlint:enable all
