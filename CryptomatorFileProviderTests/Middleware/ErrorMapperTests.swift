//
//  ErrorMapperTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 01.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Promises
import XCTest
@testable import CryptomatorFileProvider

class ErrorMapperTests: XCTestCase {
	func testMapCloudProviderErrors() {
		compareCloudProviderErrorMapping(for: .itemNotFound, expectedMappedError: NSFileProviderError(.noSuchItem) as Error)
		compareCloudProviderErrorMapping(for: .itemAlreadyExists, expectedMappedError: NSFileProviderError(.filenameCollision) as Error)
		compareCloudProviderErrorMapping(for: .parentFolderDoesNotExist, expectedMappedError: NSFileProviderError(.noSuchItem) as Error)
		compareCloudProviderErrorMapping(for: .pageTokenInvalid, expectedMappedError: NSFileProviderError(.syncAnchorExpired) as Error)
		compareCloudProviderErrorMapping(for: .quotaInsufficient, expectedMappedError: NSFileProviderError(.insufficientQuota) as Error)
		compareCloudProviderErrorMapping(for: .unauthorized, expectedMappedError: NSFileProviderError(.notAuthenticated) as Error)
		compareCloudProviderErrorMapping(for: .noInternetConnection, expectedMappedError: NSFileProviderError(.serverUnreachable) as Error)
	}

	func compareErrorMapping(for error: Error, expectedMappedError: Error) {
		let expectation = XCTestExpectation()
		executeWorkflow(with: error).then {
			XCTFail("Promise fulfilled, although expected mapped error: \(expectedMappedError) for original error: \(error)")
		}.catch { actualMappedError in
			XCTAssertEqual(expectedMappedError as NSError, actualMappedError as NSError)
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 5.0)
	}

	func compareCloudProviderErrorMapping(for error: CloudProviderError, expectedMappedError: Error) {
		compareErrorMapping(for: error, expectedMappedError: expectedMappedError)
	}

	func executeWorkflow(with error: Error) -> Promise<Void> {
		let workflowMock = WorkflowMiddlewareMock<Void> { _ in
			return Promise(error)
		}
		let errorMapper = ErrorMapper<Void>()
		errorMapper.setNext(workflowMock.eraseToAnyWorkflowMiddleware())
		return errorMapper.execute(task: DummyTask())
	}

	// MARK: - isNoInternetConnectionError

	func testIsNoInternetConnectionErrorForCloudProviderError() {
		XCTAssertTrue(CloudProviderError.noInternetConnection.isNoInternetConnectionError)
	}

	func testIsNoInternetConnectionErrorForLocalizedCloudProviderError() {
		let error = LocalizedCloudProviderError.noInternetConnection
		XCTAssertTrue(error.isNoInternetConnectionError)
	}

	func testIsNoInternetConnectionErrorForNSFileProviderError() {
		let error = NSFileProviderError(.serverUnreachable)
		XCTAssertTrue(error.isNoInternetConnectionError)
	}

	func testIsNoInternetConnectionErrorReturnsFalseForUnrelatedError() {
		XCTAssertFalse(CloudProviderError.unauthorized.isNoInternetConnectionError)
	}

	// MARK: - isTransientConnectivityError

	func testIsTransientConnectivityErrorIncludesNoInternetConnectionErrors() {
		XCTAssertTrue(CloudProviderError.noInternetConnection.isTransientConnectivityError)
		XCTAssertTrue(NSFileProviderError(.serverUnreachable).isTransientConnectivityError)
	}

	func testIsTransientConnectivityErrorForNSURLErrors() {
		let transientCodes = [NSURLErrorTimedOut, NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost, NSURLErrorNetworkConnectionLost, NSURLErrorDNSLookupFailed, NSURLErrorNotConnectedToInternet]
		for code in transientCodes {
			let error = NSError(domain: NSURLErrorDomain, code: code)
			XCTAssertTrue(error.isTransientConnectivityError, "Expected NSURLError code \(code) to be transient")
		}
	}

	func testIsTransientConnectivityErrorReturnsFalseForNonTransientNSURLError() {
		let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorBadURL)
		XCTAssertFalse(error.isTransientConnectivityError)
	}

	func testIsTransientConnectivityErrorReturnsFalseForUnrelatedError() {
		XCTAssertFalse(CloudProviderError.unauthorized.isTransientConnectivityError)
	}

	// MARK: - Helpers

	private struct DummyTask: CloudTask {
		var itemMetadata: ItemMetadata {
			fatalError("not implemented")
		}
	}
}
