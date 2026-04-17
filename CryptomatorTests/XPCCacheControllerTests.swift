//
//  XPCCacheControllerTests.swift
//  CryptomatorTests
//

import Dependencies
import FileProvider
import Promises
import XCTest
@testable import Cryptomator
@testable import CryptomatorCommonCore

class XPCCacheControllerTests: XCTestCase {
	private static let serviceError = NSError(domain: "TestError", code: -42)

	private var fileProviderConnectorMock: FileProviderConnectorMock!
	private var xpcCacheManagingMock: CacheManagingMock!

	override func setUpWithError() throws {
		fileProviderConnectorMock = FileProviderConnectorMock()
		xpcCacheManagingMock = CacheManagingMock()
		xpcCacheManagingMock.clearCacheReplyClosure = { reply in
			reply(nil)
		}
	}

	func testClearCacheUsesXPCServiceAndInvalidatesConnection() {
		fileProviderConnectorMock.proxy = xpcCacheManagingMock

		_ = runExpectingSuccess { $0.clearCache() }

		XCTAssertEqual(1, xpcCacheManagingMock.clearCacheReplyCallsCount)
		XCTAssertEqual(NSFileProviderServiceName.cacheManaging, fileProviderConnectorMock.passedServiceName)
		XCTAssertNil(fileProviderConnectorMock.passedDomain)
		XCTAssertEqual(1, fileProviderConnectorMock.xpcInvalidationCallCount)
	}

	func testClearCacheRejectsWhenGetXPCFails() {
		// Leave fileProviderConnectorMock.proxy unset so getCastedProxy rejects with typeMismatch.
		let receivedError = runExpectingFailure { $0.clearCache() }

		XCTAssertEqual(FileProviderXPCConnectorError.typeMismatch, receivedError as? FileProviderXPCConnectorError)
		XCTAssertEqual(0, xpcCacheManagingMock.clearCacheReplyCallsCount)
		XCTAssertEqual(0, fileProviderConnectorMock.xpcInvalidationCallCount)
	}

	func testClearCacheRejectsWhenServiceRepliesWithError() {
		xpcCacheManagingMock.clearCacheReplyClosure = { reply in
			reply(Self.serviceError)
		}
		fileProviderConnectorMock.proxy = xpcCacheManagingMock

		let receivedError = runExpectingFailure { $0.clearCache() }

		XCTAssertEqual(Self.serviceError, receivedError as NSError?)
		XCTAssertEqual(1, xpcCacheManagingMock.clearCacheReplyCallsCount)
		XCTAssertEqual(1, fileProviderConnectorMock.xpcInvalidationCallCount)
	}

	func testGetLocalCacheSizeInBytesUsesXPCServiceAndInvalidatesConnection() {
		xpcCacheManagingMock.getLocalCacheSizeInBytesReplyClosure = { reply in
			reply(512 as NSNumber, nil)
		}
		fileProviderConnectorMock.proxy = xpcCacheManagingMock

		let value = runExpectingSuccess { $0.getLocalCacheSizeInBytes() }

		XCTAssertEqual(512, value)
		XCTAssertEqual(1, xpcCacheManagingMock.getLocalCacheSizeInBytesReplyCallsCount)
		XCTAssertEqual(NSFileProviderServiceName.cacheManaging, fileProviderConnectorMock.passedServiceName)
		XCTAssertNil(fileProviderConnectorMock.passedDomain)
		XCTAssertEqual(1, fileProviderConnectorMock.xpcInvalidationCallCount)
	}

	func testGetLocalCacheSizeInBytesRejectsWhenGetXPCFails() {
		// Leave fileProviderConnectorMock.proxy unset so getCastedProxy rejects with typeMismatch.
		let receivedError = runExpectingFailure { $0.getLocalCacheSizeInBytes() }

		XCTAssertEqual(FileProviderXPCConnectorError.typeMismatch, receivedError as? FileProviderXPCConnectorError)
		XCTAssertEqual(0, xpcCacheManagingMock.getLocalCacheSizeInBytesReplyCallsCount)
		XCTAssertEqual(0, fileProviderConnectorMock.xpcInvalidationCallCount)
	}

	func testGetLocalCacheSizeInBytesRejectsWhenServiceRepliesWithError() {
		xpcCacheManagingMock.getLocalCacheSizeInBytesReplyClosure = { reply in
			reply(nil, Self.serviceError)
		}
		fileProviderConnectorMock.proxy = xpcCacheManagingMock

		let receivedError = runExpectingFailure { $0.getLocalCacheSizeInBytes() }

		XCTAssertEqual(Self.serviceError, receivedError as NSError?)
		XCTAssertEqual(1, xpcCacheManagingMock.getLocalCacheSizeInBytesReplyCallsCount)
		XCTAssertEqual(1, fileProviderConnectorMock.xpcInvalidationCallCount)
	}

	func testGetLocalCacheSizeInBytesReturnsZeroWhenReplyIsNil() {
		xpcCacheManagingMock.getLocalCacheSizeInBytesReplyClosure = { reply in
			reply(nil, nil)
		}
		fileProviderConnectorMock.proxy = xpcCacheManagingMock

		let value = runExpectingSuccess { $0.getLocalCacheSizeInBytes() }

		XCTAssertEqual(0, value)
		XCTAssertEqual(1, xpcCacheManagingMock.getLocalCacheSizeInBytesReplyCallsCount)
		XCTAssertEqual(1, fileProviderConnectorMock.xpcInvalidationCallCount)
	}

	// MARK: Helpers

	private func runExpectingSuccess<T>(_ operation: @escaping (XPCCacheController) -> Promise<T>) -> T? {
		let expectation = XCTestExpectation()
		var value: T?
		withDependencies {
			$0.fileProviderConnector = fileProviderConnectorMock
		} operation: {
			operation(XPCCacheController()).then { v in
				value = v
			}.catch { error in
				XCTFail("Unexpected error: \(error)")
			}.always {
				expectation.fulfill()
			}
		}
		wait(for: [expectation], timeout: 5.0)
		return value
	}

	private func runExpectingFailure<T>(_ operation: @escaping (XPCCacheController) -> Promise<T>) -> Error? {
		let expectation = XCTestExpectation()
		var receivedError: Error?
		withDependencies {
			$0.fileProviderConnector = fileProviderConnectorMock
		} operation: {
			operation(XPCCacheController()).then { _ in
				XCTFail("Expected failure")
			}.catch { error in
				receivedError = error
			}.always {
				expectation.fulfill()
			}
		}
		wait(for: [expectation], timeout: 5.0)
		return receivedError
	}
}
