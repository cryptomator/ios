//
//  IAPManagerMock.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 26.11.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation
import Promises
import StoreKit
@testable import Cryptomator

// MARK: - IAPManagerMock -

// swiftlint:disable all

final class IAPManagerMock: IAPManager {
	// MARK: - isAuthorizedForPayments

	var isAuthorizedForPayments: Bool {
		get { underlyingIsAuthorizedForPayments }
		set(value) { underlyingIsAuthorizedForPayments = value }
	}

	private var underlyingIsAuthorizedForPayments: Bool!

	// MARK: - buy

	var buyThrowableError: Error?
	var buyCallsCount = 0
	var buyCalled: Bool {
		buyCallsCount > 0
	}

	var buyReceivedProduct: SKProduct?
	var buyReceivedInvocations: [SKProduct] = []
	var buyReturnValue: Promise<PurchaseTransaction>!
	var buyClosure: ((SKProduct) -> Promise<PurchaseTransaction>)?

	func buy(_ product: SKProduct) -> Promise<PurchaseTransaction> {
		if let error = buyThrowableError {
			return Promise(error)
		}
		buyCallsCount += 1
		buyReceivedProduct = product
		buyReceivedInvocations.append(product)
		return buyClosure.map({ $0(product) }) ?? buyReturnValue
	}

	// MARK: - restore

	var restoreThrowableError: Error?
	var restoreCallsCount = 0
	var restoreCalled: Bool {
		restoreCallsCount > 0
	}

	var restoreReturnValue: Promise<RestoreTransactionsResult>!
	var restoreClosure: (() -> Promise<RestoreTransactionsResult>)?

	func restore() -> Promise<RestoreTransactionsResult> {
		if let error = restoreThrowableError {
			return Promise(error)
		}
		restoreCallsCount += 1
		return restoreClosure.map({ $0() }) ?? restoreReturnValue
	}
}

// swiftlint:enable all
