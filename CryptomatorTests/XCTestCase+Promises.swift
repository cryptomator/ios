//
//  XCTestCase+Promises.swift
//  CryptomatorTests
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
		XCTAssertRejects(expression) { error in
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
}
