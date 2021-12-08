//
//  IAPStoreMock.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 07.12.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation
import Promises
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
	var fetchProductsWithReturnValue: Promise<SKProductsResponse>!
	var fetchProductsWithClosure: (([ProductIdentifier]) -> Promise<SKProductsResponse>)?

	func fetchProducts(with identifiers: [ProductIdentifier]) -> Promise<SKProductsResponse> {
		if let error = fetchProductsWithThrowableError {
			return Promise(error)
		}
		fetchProductsWithCallsCount += 1
		fetchProductsWithReceivedIdentifiers = identifiers
		fetchProductsWithReceivedInvocations.append(identifiers)
		return fetchProductsWithClosure.map({ $0(identifiers) }) ?? fetchProductsWithReturnValue
	}
}

// swiftlint:enable all
