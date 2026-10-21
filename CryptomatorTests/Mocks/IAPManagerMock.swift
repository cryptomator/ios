//
//  IAPManagerMock.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 26.11.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation
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
	var buyReturnValue: PurchaseTransaction!
	var buyClosure: ((SKProduct) async throws -> PurchaseTransaction)?

	func buy(_ product: SKProduct) async throws -> PurchaseTransaction {
		if let error = buyThrowableError {
			throw error
		}
		buyCallsCount += 1
		buyReceivedProduct = product
		buyReceivedInvocations.append(product)
		if let buyClosure = buyClosure {
			return try await buyClosure(product)
		}
		return buyReturnValue
	}

	// MARK: - restore

	var restoreThrowableError: Error?
	var restoreCallsCount = 0
	var restoreCalled: Bool {
		restoreCallsCount > 0
	}

	var restoreReturnValue: RestoreTransactionsResult!
	var restoreClosure: (() async throws -> RestoreTransactionsResult)?

	func restore() async throws -> RestoreTransactionsResult {
		if let error = restoreThrowableError {
			throw error
		}
		restoreCallsCount += 1
		if let restoreClosure = restoreClosure {
			return try await restoreClosure()
		}
		return restoreReturnValue
	}
}

// swiftlint:enable all
