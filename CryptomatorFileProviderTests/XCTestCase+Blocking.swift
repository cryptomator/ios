//
//  XCTestCase+Blocking.swift
//  CryptomatorFileProviderTests
//
//  Created by Tobias Hagemann on 15.10.26.
//  Copyright © 2026 Skymatic GmbH. All rights reserved.
//

import Foundation
import XCTest

@MainActor
extension XCTestCase {
	/// Cancels `operation` once `duration` has passed.
	func assertStaysBlocked(_ operation: @escaping @MainActor () async throws -> Void, for duration: TimeInterval = 1.0) async {
		let finished = XCTestExpectation(description: "Operation finished")
		finished.isInverted = true
		let task = Task { @MainActor in
			try? await operation()
			if !Task.isCancelled {
				finished.fulfill()
			}
		}
		await fulfillment(of: [finished], timeout: duration)
		task.cancel()
	}

	func assertFinishes(_ operation: @escaping @MainActor () async throws -> Void, within duration: TimeInterval = 5.0) async {
		let finished = XCTestExpectation(description: "Operation finished")
		let task = Task { @MainActor in
			try? await operation()
			finished.fulfill()
		}
		await fulfillment(of: [finished], timeout: duration)
		task.cancel()
	}
}
