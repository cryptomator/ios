//
//  ErrorExtensionsTests.swift
//  CryptomatorCommonCoreTests
//
//  Created by Tobias Hagemann on 21.04.26.
//  Copyright © 2026 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import FileProvider
import XCTest

class ErrorExtensionsTests: XCTestCase {
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
}
