//
//  Promise+AllIgnoringResultsTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 31.03.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import Promises
import XCTest
@testable import CryptomatorFileProvider

class Promise_AllIgnoringResultsTests: XCTestCase {
	func testWaitForAll() throws {
		let pending = Promise<Void>.pending()
		let fulfilled = Promise(())

		let ignoringResultPromise = all(ignoringResult: [pending, fulfilled])
		XCTAssertGetsNotExecuted(ignoringResultPromise)
		pending.fulfill(())
		wait(for: ignoringResultPromise)
	}

	func testWaitForAllWithRejectedPromise() throws {
		let pending = Promise<Void>.pending()
		let rejected: Promise<Void> = Promise(NSError(domain: "Test", code: -100))

		let ignoringResultPromise = all(ignoringResult: [pending, rejected])
		XCTAssertGetsNotExecuted(ignoringResultPromise)
		pending.fulfill(())
		wait(for: ignoringResultPromise)
	}
}
