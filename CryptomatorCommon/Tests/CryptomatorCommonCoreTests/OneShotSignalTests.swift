//
//  OneShotSignalTests.swift
//  CryptomatorCommonCoreTests
//
//  Created by Tobias Hagemann on 15.10.26.
//  Copyright © 2026 Skymatic GmbH. All rights reserved.
//

import XCTest
@testable import CryptomatorCommonCore

class OneShotSignalTests: XCTestCase {
	func testFirstSettleWins() async throws {
		let signal = OneShotSignal<Int>()
		let waiter = Task {
			try await signal.value
		}

		signal.fulfill(1)
		signal.fulfill(2)
		signal.reject(CocoaError(.fileReadUnknown))

		let waiterValue = try await waiter.value
		XCTAssertEqual(1, waiterValue)
		let value = try await signal.value
		XCTAssertEqual(1, value)
	}

	func testLateWaiterGetsResult() async {
		let signal = OneShotSignal<Int>()
		signal.reject(CocoaError(.fileReadUnknown))

		await XCTAssertThrowsAsyncError(try await signal.value) { error in
			XCTAssertEqual(CocoaError(.fileReadUnknown), error as? CocoaError)
		}
	}

	func testCancelledWaiterThrowsWithoutSettling() async throws {
		let signal = OneShotSignal<Int>()
		let waiter = Task {
			try await signal.value
		}
		try await Task.sleep(for: .milliseconds(100))

		waiter.cancel()

		await XCTAssertThrowsAsyncError(try await waiter.value) { error in
			XCTAssert(error is CancellationError, "Expected CancellationError, got: \(error)")
		}
		signal.fulfill(3)
		let value = try await signal.value
		XCTAssertEqual(3, value)
	}
}
