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

	func wait<Input, Failure>(for recorder: Recorder<Input, Failure>, timeout: TimeInterval = 1) {
		wait(for: [recorder.completed], timeout: timeout)
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

extension Publisher {
	func recordNext(_ count: Int) -> Recorder<Output, Failure> {
		let recorder = Recorder<Output, Failure>(expectedElementCount: count)
		subscribe(recorder)
		return recorder
	}
}

class Recorder<Input, Failure: Error> {
	let completed = XCTestExpectation()
	private var elements = [Input]()
	private let lock = NSLock()
	private let expectedElementCount: Int

	init(expectedElementCount: Int) {
		self.expectedElementCount = expectedElementCount
	}

	func getElements() -> [Input] {
		return synchronized {
			elements
		}
	}

	private func synchronized<T>(_ execute: () throws -> T) rethrows -> T {
		lock.lock()
		defer { lock.unlock() }
		return try execute()
	}
}

extension Recorder: Subscriber {
	func receive(subscription: Subscription) {
		subscription.request(.unlimited)
	}

	func receive(_ input: Input) -> Subscribers.Demand {
		synchronized {
			elements.append(input)
			if elements.count == expectedElementCount {
				completed.fulfill()
			}
		}
		return .none
	}

	func receive(completion: Subscribers.Completion<Failure>) {}
}
