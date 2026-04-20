//
//  FullVersionCheckerTests.swift
//
//
//  Created by Philipp Schmid on 21.02.22.
//

import Dependencies
import XCTest
@testable import CryptomatorCommonCore

class FullVersionCheckerTests: XCTestCase {
	var settingsMock: CryptomatorSettingsMock!

	override func setUpWithError() throws {
		settingsMock = CryptomatorSettingsMock()
		settingsMock.fullVersionUnlocked = false
		settingsMock.hasRunningSubscription = false
		settingsMock.trialExpirationDate = nil
	}

	// MARK: Is Full Version

	func testIsFullVersionWithLifetime() {
		settingsMock.fullVersionUnlocked = true
		withDependencies {
			$0.cryptomatorSettings = settingsMock
		} operation: {
			XCTAssert(UserDefaultsFullVersionChecker().isFullVersion)
		}
	}

	func testIsFullVersionWithRunningSubscription() {
		settingsMock.fullVersionUnlocked = true
		withDependencies {
			$0.cryptomatorSettings = settingsMock
		} operation: {
			XCTAssert(UserDefaultsFullVersionChecker().isFullVersion)
		}
	}

	func testIsFullVersionWithTrialExpirationDateInTheFuture() {
		settingsMock.trialExpirationDate = .distantFuture
		withDependencies {
			$0.cryptomatorSettings = settingsMock
		} operation: {
			XCTAssert(UserDefaultsFullVersionChecker().isFullVersion)
		}
	}

	func testIsNotFullVersionWithTrialExpirationDateInThePast() {
		settingsMock.trialExpirationDate = .distantPast
		withDependencies {
			$0.cryptomatorSettings = settingsMock
		} operation: {
			XCTAssertFalse(UserDefaultsFullVersionChecker().isFullVersion)
		}
	}

	func testIsNotFullVersionWithNothingSet() {
		withDependencies {
			$0.cryptomatorSettings = settingsMock
		} operation: {
			XCTAssertFalse(UserDefaultsFullVersionChecker().isFullVersion)
		}
	}

	// MARK: Has Expired Trial

	func testHasExpiredTrialWithTrialExpirationDateNotSet() {
		withDependencies {
			$0.cryptomatorSettings = settingsMock
		} operation: {
			XCTAssertFalse(UserDefaultsFullVersionChecker().hasExpiredTrial)
		}
	}

	func testHasExpiredTrialWithExpirationDateInTheFuture() {
		settingsMock.trialExpirationDate = .distantFuture
		withDependencies {
			$0.cryptomatorSettings = settingsMock
		} operation: {
			XCTAssertFalse(UserDefaultsFullVersionChecker().hasExpiredTrial)
		}
	}

	func testHasExpiredTrialWithExpirationDateInThePast() {
		settingsMock.trialExpirationDate = .distantPast
		withDependencies {
			$0.cryptomatorSettings = settingsMock
		} operation: {
			XCTAssert(UserDefaultsFullVersionChecker().hasExpiredTrial)
		}
	}
}
