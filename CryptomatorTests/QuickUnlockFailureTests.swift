//
//  QuickUnlockFailureTests.swift
//  CryptomatorTests
//
//  Created by Tobias Hagemann on 01.09.26.
//  Copyright © 2026 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import LocalAuthentication
import XCTest

class QuickUnlockFailureTests: XCTestCase {
	// MARK: - Fall back to the password

	func testFallBackToPasswordForUserFallback() {
		XCTAssertEqual(.fallBackToPassword, QuickUnlockFailure(error: laError(.userFallback)))
	}

	/**
	 Biometric authentication is unavailable in these cases, so closing the screen would leave the user without a way to unlock.
	 */
	func testFallBackToPasswordForUnavailableBiometry() {
		let unavailableCodes: [LAError.Code] = [.biometryLockout, .biometryNotAvailable, .biometryNotEnrolled, .passcodeNotSet, .notInteractive, .invalidContext]
		for code in unavailableCodes {
			XCTAssertEqual(.fallBackToPassword, QuickUnlockFailure(error: laError(code)), "Expected \(code) to fall back to the password")
		}
	}

	// MARK: - Dismiss

	func testDismissForCanceledOrFailedAuthentication() {
		let canceledCodes: [LAError.Code] = [.userCancel, .appCancel, .systemCancel, .authenticationFailed]
		for code in canceledCodes {
			XCTAssertEqual(.dismiss, QuickUnlockFailure(error: laError(code)), "Expected \(code) to dismiss")
		}
	}

	// MARK: - Report

	/**
	 Every error that biometric authentication did not raise is reported, whatever it is.
	 */
	func testReportForEveryNonBiometricError() {
		let errors: [Error] = [
			CloudProviderError.unauthorized,
			LocalizedCloudProviderError.unauthorized,
			NSError(domain: "TestDomain", code: 42),
			NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
		]
		for error in errors {
			XCTAssertEqual(.report, QuickUnlockFailure(error: error), "Expected \(error) to be reported")
		}
	}

	// MARK: - Helpers

	/**
	 Builds the error the way `LAContext` delivers it, thus the tests exercise the real bridged cast instead of a hand-built `LAError`.
	 */
	private func laError(_ code: LAError.Code) -> Error {
		return NSError(domain: LAErrorDomain, code: code.rawValue)
	}
}
