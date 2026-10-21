//
//  IAPStoreMock.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 07.12.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation
import StoreKit
@testable import Cryptomator

// swiftlint:disable all

final class IAPStoreMock: IAPStore {
	// MARK: - fetchProducts

	var fetchProductsWithThrowableError: Error?
	var fetchProductsWithCallsCount = 0
	var fetchProductsWithCalled: Bool {
		fetchProductsWithCallsCount > 0
	}

	var fetchProductsWithReceivedIdentifiers: [ProductIdentifier]?
	var fetchProductsWithReceivedInvocations: [[ProductIdentifier]] = []
	var fetchProductsWithReturnValue: SKProductsResponse!
	var fetchProductsWithClosure: (([ProductIdentifier]) async throws -> SKProductsResponse)?

	func fetchProducts(with identifiers: [ProductIdentifier]) async throws -> SKProductsResponse {
		if let error = fetchProductsWithThrowableError {
			throw error
		}
		fetchProductsWithCallsCount += 1
		fetchProductsWithReceivedIdentifiers = identifiers
		fetchProductsWithReceivedInvocations.append(identifiers)
		if let fetchProductsWithClosure = fetchProductsWithClosure {
			return try await fetchProductsWithClosure(identifiers)
		}
		return fetchProductsWithReturnValue
	}
}

// swiftlint:enable all
