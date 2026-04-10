//
//  XPCCacheControllerTests.swift
//  CryptomatorTests
//

import FileProvider
import XCTest
@testable import Cryptomator
@testable import CryptomatorCommonCore
@testable import Dependencies

class XPCCacheControllerTests: XCTestCase {
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
		let expectation = XCTestExpectation()
		fileProviderConnectorMock.proxy = xpcCacheManagingMock

		withDependencies {
			$0.fileProviderConnector = fileProviderConnectorMock
		} operation: {
			XPCCacheController().clearCache().always {
				expectation.fulfill()
			}
		}
		wait(for: [expectation], timeout: 5.0)

		XCTAssertEqual(1, xpcCacheManagingMock.clearCacheReplyCallsCount)
		XCTAssertEqual(NSFileProviderServiceName.cacheManaging, fileProviderConnectorMock.passedServiceName)
		XCTAssertNil(fileProviderConnectorMock.passedDomain)
		XCTAssertEqual(1, fileProviderConnectorMock.xpcInvalidationCallCount)
	}

	func testGetLocalCacheSizeInBytesUsesXPCServiceAndInvalidatesConnection() {
		let expectation = XCTestExpectation()
		xpcCacheManagingMock.getLocalCacheSizeInBytesReplyClosure = { reply in
			reply(512 as NSNumber, nil)
		}
		fileProviderConnectorMock.proxy = xpcCacheManagingMock

		withDependencies {
			$0.fileProviderConnector = fileProviderConnectorMock
		} operation: {
			XPCCacheController().getLocalCacheSizeInBytes().then { value in
				XCTAssertEqual(512, value)
				expectation.fulfill()
			}
		}
		wait(for: [expectation], timeout: 5.0)

		XCTAssertEqual(1, xpcCacheManagingMock.getLocalCacheSizeInBytesReplyCallsCount)
		XCTAssertEqual(NSFileProviderServiceName.cacheManaging, fileProviderConnectorMock.passedServiceName)
		XCTAssertNil(fileProviderConnectorMock.passedDomain)
		XCTAssertEqual(1, fileProviderConnectorMock.xpcInvalidationCallCount)
	}
}
