//
//  XCTest+Combine.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 29.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import Foundation
import XCTest

extension XCTestCase {
	// from: https://www.swiftbysundell.com/articles/unit-testing-combine-based-swift-code/
	func awaitPublisher<T: Publisher>(
		_ publisher: T,
		timeout: TimeInterval = 1,
		file: StaticString = #file,
		line: UInt = #line
	) throws -> T.Output {
		var result: Result<T.Output, Error>?
		let expectation = self.expectation(description: "Awaiting publisher")

		let cancellable = publisher.sink(
			receiveCompletion: { completion in
				switch completion {
				case let .failure(error):
					result = .failure(error)
				case .finished:
					break
				}

				expectation.fulfill()
			},
			receiveValue: { value in
				result = .success(value)
			}
		)

		waitForExpectations(timeout: timeout)
		cancellable.cancel()

		let unwrappedResult = try XCTUnwrap(
			result,
			"Awaited publisher did not produce any output",
			file: file,
			line: line
		)

		return try unwrappedResult.get()
	}
}

extension Published.Publisher {
	// from: https://www.swiftbysundell.com/articles/unit-testing-combine-based-swift-code/
	func collectNext(_ count: Int) -> AnyPublisher<[Output], Never> {
		dropFirst()
			.collect(count)
			.first()
			.eraseToAnyPublisher()
	}
}
