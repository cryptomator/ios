//
//  PaymentTransactionMock.swift
//  CryptomatorTests
//
//  Created by Tobias Hagemann on 03.04.26.
//  Copyright © 2026 Skymatic GmbH. All rights reserved.
//

import Foundation
import StoreKit

// swiftlint:disable all

final class PaymentTransactionMock: SKPaymentTransaction {
	private let _transactionState: SKPaymentTransactionState
	private let _payment: SKPayment
	private let _transactionIdentifier: String?
	private let _transactionDate: Date?
	private let _original: SKPaymentTransaction?
	private let _error: Error?

	init(state: SKPaymentTransactionState, payment: SKPayment, transactionIdentifier: String? = nil, transactionDate: Date? = nil, original: SKPaymentTransaction? = nil, error: Error? = nil) {
		self._transactionState = state
		self._payment = payment
		self._transactionIdentifier = transactionIdentifier
		self._transactionDate = transactionDate
		self._original = original
		self._error = error
	}

	override var transactionState: SKPaymentTransactionState {
		return _transactionState
	}

	override var payment: SKPayment {
		return _payment
	}

	override var transactionIdentifier: String? {
		return _transactionIdentifier
	}

	override var transactionDate: Date? {
		return _transactionDate
	}

	override var original: SKPaymentTransaction? {
		return _original
	}

	override var error: Error? {
		return _error
	}
}

// swiftlint:enable all
