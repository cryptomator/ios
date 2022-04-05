//
//  XCTestCase+Promises.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 28.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import Foundation
import XCTest
@testable import Promises

extension XCTestCase {
	func XCTAssertRejects<T>(_ expression: Promise<T>, _ message: @autoclosure () -> String = "", timeout seconds: TimeInterval = 1.0, _ errorHandler: @escaping (_ error: Error) -> Void = { _ in }, file: StaticString = #filePath, line: UInt = #line) {
		let expectation = XCTestExpectation()
		expression.then { _ in
			XCTFail("Promise fulfilled", file: file, line: line)
		}.catch { error in
			errorHandler(error)
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: seconds)
	}

	func XCTAssertRejects<T>(_ expression: Promise<T>, with expectedError: Error, _ message: @escaping @autoclosure () -> String = "", timeout seconds: TimeInterval = 1.0, file: StaticString = #filePath, line: UInt = #line) {
		XCTAssertRejects(expression, timeout: seconds) { error in
			XCTAssertEqual(expectedError as NSError, error as NSError, message(), file: file, line: line)
		}
	}

	func wait<T>(for promise: Promise<T>, timeout seconds: TimeInterval = 1.0, file: StaticString = #filePath, line: UInt = #line) {
		let expectation = XCTestExpectation()
		promise.then { _ in
			expectation.fulfill()
		}.catch { error in
			XCTFail("Promise rejected with error: \(error)", file: file, line: line)
		}
		wait(for: [expectation], timeout: seconds)
	}

	func wait<T>(for promises: [Promise<T>], timeout seconds: TimeInterval = 1.0, enforceOrder enforceOrderOfFulfillment: Bool, file: StaticString = #filePath, line: UInt = #line) {
		let expectations = promises.map { promise -> XCTestExpectation in
			let expectation = XCTestExpectation()
			promise.then { _ in
				expectation.fulfill()
			}.catch { error in
				XCTFail("Promise rejected with error: \(error)", file: file, line: line)
			}
			return expectation
		}
		wait(for: expectations, timeout: seconds, enforceOrder: enforceOrderOfFulfillment)
	}

	func XCTAssertGetsNotExecuted<T>(_ promise: Promise<T>, timeout seconds: TimeInterval = 1.0, file: StaticString = #filePath, line: UInt = #line) {
		let expectation = XCTestExpectation()
		expectation.isInverted = true
		promise.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: seconds)
	}

	func XCTAssertGetsNotExecuted<T>(_ promises: [Promise<T>], timeout seconds: TimeInterval = 1.0, file: StaticString = #filePath, line: UInt = #line) {
		let expectation = XCTestExpectation()
		expectation.isInverted = true
		all(promises).always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: seconds)
	}
}
