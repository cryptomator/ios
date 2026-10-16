//
//  XPCCacheControllerTests.swift
//  CryptomatorTests
//

import Dependencies
import FileProvider
import XCTest
@testable import Cryptomator
@testable import CryptomatorCommonCore

@MainActor
class XPCCacheControllerTests: XCTestCase {
	private static let serviceError = NSError(domain: "TestError", code: -42)

	private var fileProviderConnectorMock: FileProviderConnectorMock!
	private var xpcCacheManagingMock: CacheManagingMock!

	override func setUp() async throws {
		try await super.setUp()
		fileProviderConnectorMock = FileProviderConnectorMock()
		xpcCacheManagingMock = CacheManagingMock()
		xpcCacheManagingMock.clearCacheReplyClosure = { reply in
			reply(nil)
		}
	}

	func testClearCacheUsesXPCServiceAndInvalidatesConnection() async throws {
		fileProviderConnectorMock.proxy = xpcCacheManagingMock

		try await makeXPCCacheController().clearCache()

		XCTAssertEqual(1, xpcCacheManagingMock.clearCacheReplyCallsCount)
		XCTAssertEqual(NSFileProviderServiceName.cacheManaging, fileProviderConnectorMock.passedServiceName)
		XCTAssertNil(fileProviderConnectorMock.passedDomain)
		XCTAssertEqual(1, fileProviderConnectorMock.xpcInvalidationCallCount)
	}

	func testClearCacheRejectsWhenGetXPCFails() async {
		// Leave fileProviderConnectorMock.proxy unset so getCastedProxy throws typeMismatch.
		await XCTAssertThrowsAsyncError(try await makeXPCCacheController().clearCache()) { error in
			XCTAssertEqual(FileProviderXPCConnectorError.typeMismatch, error as? FileProviderXPCConnectorError)
		}

		XCTAssertEqual(0, xpcCacheManagingMock.clearCacheReplyCallsCount)
		XCTAssertEqual(0, fileProviderConnectorMock.xpcInvalidationCallCount)
	}

	func testClearCacheRejectsWhenServiceRepliesWithError() async {
		xpcCacheManagingMock.clearCacheReplyClosure = { reply in
			reply(Self.serviceError)
		}
		fileProviderConnectorMock.proxy = xpcCacheManagingMock

		await XCTAssertThrowsAsyncError(try await makeXPCCacheController().clearCache()) { error in
			XCTAssertEqual(Self.serviceError, error as NSError)
		}

		XCTAssertEqual(1, xpcCacheManagingMock.clearCacheReplyCallsCount)
		XCTAssertEqual(1, fileProviderConnectorMock.xpcInvalidationCallCount)
	}

	func testGetLocalCacheSizeInBytesUsesXPCServiceAndInvalidatesConnection() async throws {
		xpcCacheManagingMock.getLocalCacheSizeInBytesReplyClosure = { reply in
			reply(512 as NSNumber, nil)
		}
		fileProviderConnectorMock.proxy = xpcCacheManagingMock

		let value = try await makeXPCCacheController().getLocalCacheSizeInBytes()

		XCTAssertEqual(512, value)
		XCTAssertEqual(1, xpcCacheManagingMock.getLocalCacheSizeInBytesReplyCallsCount)
		XCTAssertEqual(NSFileProviderServiceName.cacheManaging, fileProviderConnectorMock.passedServiceName)
		XCTAssertNil(fileProviderConnectorMock.passedDomain)
		XCTAssertEqual(1, fileProviderConnectorMock.xpcInvalidationCallCount)
	}

	func testGetLocalCacheSizeInBytesRejectsWhenGetXPCFails() async {
		// Leave fileProviderConnectorMock.proxy unset so getCastedProxy throws typeMismatch.
		await XCTAssertThrowsAsyncError(try await makeXPCCacheController().getLocalCacheSizeInBytes()) { error in
			XCTAssertEqual(FileProviderXPCConnectorError.typeMismatch, error as? FileProviderXPCConnectorError)
		}

		XCTAssertEqual(0, xpcCacheManagingMock.getLocalCacheSizeInBytesReplyCallsCount)
		XCTAssertEqual(0, fileProviderConnectorMock.xpcInvalidationCallCount)
	}

	func testGetLocalCacheSizeInBytesRejectsWhenServiceRepliesWithError() async {
		xpcCacheManagingMock.getLocalCacheSizeInBytesReplyClosure = { reply in
			reply(nil, Self.serviceError)
		}
		fileProviderConnectorMock.proxy = xpcCacheManagingMock

		await XCTAssertThrowsAsyncError(try await makeXPCCacheController().getLocalCacheSizeInBytes()) { error in
			XCTAssertEqual(Self.serviceError, error as NSError)
		}

		XCTAssertEqual(1, xpcCacheManagingMock.getLocalCacheSizeInBytesReplyCallsCount)
		XCTAssertEqual(1, fileProviderConnectorMock.xpcInvalidationCallCount)
	}

	func testGetLocalCacheSizeInBytesReturnsZeroWhenReplyIsNil() async throws {
		xpcCacheManagingMock.getLocalCacheSizeInBytesReplyClosure = { reply in
			reply(nil, nil)
		}
		fileProviderConnectorMock.proxy = xpcCacheManagingMock

		let value = try await makeXPCCacheController().getLocalCacheSizeInBytes()

		XCTAssertEqual(0, value)
		XCTAssertEqual(1, xpcCacheManagingMock.getLocalCacheSizeInBytesReplyCallsCount)
		XCTAssertEqual(1, fileProviderConnectorMock.xpcInvalidationCallCount)
	}

	// MARK: Helpers

	private func makeXPCCacheController() -> XPCCacheController {
		withDependencies {
			$0.fileProviderConnector = fileProviderConnectorMock
		} operation: {
			XPCCacheController()
		}
	}
}
