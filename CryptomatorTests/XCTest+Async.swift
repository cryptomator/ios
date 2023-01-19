//
//  XCTest+Async.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 26.10.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import Foundation
import XCTest

extension XCTest {
	func XCTAssertThrowsAsyncError<T: Sendable>(
		_ expression: @autoclosure () async throws -> T,
		_ message: @autoclosure () -> String = "",
		file: StaticString = #filePath,
		line: UInt = #line,
		_ errorHandler: (_ error: Error) -> Void = { _ in }
	) async {
		do {
			_ = try await expression()
			XCTFail(message(), file: file, line: line)
		} catch {
			errorHandler(error)
		}
	}
}
