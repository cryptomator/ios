//
//  UploadRetryingTests.swift
//  CryptomatorCommonCoreTests
//
//  Created by Tobias Hagemann on 16.10.26.
//  Copyright © 2026 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import FileProvider
import XCTest

class UploadRetryingTests: XCTestCase {
	private let itemIdentifier = NSFileProviderItemIdentifier("1")

	func testRetryUploadThrowsReplyError() async {
		let uploadRetrying = UploadRetryingFake(retryUploadError: CocoaError(.fileReadUnknown))

		await XCTAssertThrowsAsyncError(try await uploadRetrying.retryUpload(for: [itemIdentifier])) { error in
			XCTAssertEqual(CocoaError(.fileReadUnknown), error as? CocoaError)
		}
	}

	func testRetryUploadSucceedsWithoutReplyError() async throws {
		let uploadRetrying = UploadRetryingFake(retryUploadError: nil)

		try await uploadRetrying.retryUpload(for: [itemIdentifier])
	}

	func testGetCurrentFractionalUploadProgress() async throws {
		let uploadRetrying = UploadRetryingFake(fractionalUploadProgress: NSNumber(value: 0.25))

		let progress = try await uploadRetrying.getCurrentFractionalUploadProgress(for: itemIdentifier)
		XCTAssertEqual(0.25, progress)
	}

	func testGetCurrentFractionalUploadProgressWithoutProgress() async throws {
		let uploadRetrying = UploadRetryingFake(fractionalUploadProgress: nil)

		let progress = try await uploadRetrying.getCurrentFractionalUploadProgress(for: itemIdentifier)
		XCTAssertNil(progress)
	}
}

private final class UploadRetryingFake: UploadRetrying {
	let serviceName = NSFileProviderServiceName.uploadRetryingService
	private let retryUploadError: Error?
	private let fractionalUploadProgress: NSNumber?

	init(retryUploadError: Error? = nil, fractionalUploadProgress: NSNumber? = nil) {
		self.retryUploadError = retryUploadError
		self.fractionalUploadProgress = fractionalUploadProgress
	}

	func makeListenerEndpoint() throws -> NSXPCListenerEndpoint {
		throw NSError(domain: "MockError", code: -100)
	}

	func retryUpload(for itemIdentifiers: [NSFileProviderItemIdentifier], reply: @escaping (Error?) -> Void) {
		reply(retryUploadError)
	}

	func getCurrentFractionalUploadProgress(for itemIdentifier: NSFileProviderItemIdentifier, reply: @escaping (NSNumber?) -> Void) {
		reply(fractionalUploadProgress)
	}
}
