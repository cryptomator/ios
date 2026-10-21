//
//  ConcurrencyLimiterTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Tobias Hagemann on 15.10.26.
//  Copyright © 2026 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import XCTest
@testable import CryptomatorFileProvider

@MainActor
class ConcurrencyLimiterTests: XCTestCase {
	private var order = [String]()

	func testWaitersAreServedInFIFOOrder() async throws {
		let limiter = ConcurrencyLimiter(label: "Test", maxConcurrentOperations: 1)
		let gate = OneShotSignal<Void>()

		let holderStarted = XCTestExpectation(description: "Holder acquired the permit")
		let holder = Task {
			try await limiter.withPermit {
				holderStarted.fulfill()
				try await gate.value
			}
		}
		await fulfillment(of: [holderStarted], timeout: 1.0)

		var waiters = [Task<Void, Error>]()
		for name in ["A", "B", "C"] {
			let enqueued = XCTestExpectation(description: "\(name) is waiting for a permit")
			waiters.append(Task {
				enqueued.fulfill()
				try await limiter.withPermit {
					self.order.append(name)
				}
			})
			await fulfillment(of: [enqueued], timeout: 1.0)
		}

		gate.fulfill(())
		try await holder.value
		for waiter in waiters {
			try await waiter.value
		}
		XCTAssertEqual(["A", "B", "C"], order)
	}

	func testPermitIsReleasedWhenWorkThrows() async {
		let limiter = ConcurrencyLimiter(label: "Test", maxConcurrentOperations: 1)
		await XCTAssertThrowsAsyncError(try await limiter.withPermit {
			throw CocoaError(.fileReadUnknown)
		})

		let acquired = XCTestExpectation(description: "Permit acquired after the throwing work")
		let task = Task {
			try await limiter.withPermit {
				acquired.fulfill()
			}
		}
		await fulfillment(of: [acquired], timeout: 1.0)
		task.cancel()
	}
}
