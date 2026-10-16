//
//  XCTest+Async.swift
//  CryptomatorCommonCoreTests
//
//  Created by Tobias Hagemann on 15.10.26.
//  Copyright © 2026 Skymatic GmbH. All rights reserved.
//

import Foundation
import XCTest

extension XCTest {
	func XCTAssertThrowsAsyncError<T>(
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
