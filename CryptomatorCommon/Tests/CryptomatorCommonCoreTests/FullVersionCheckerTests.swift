//
//  FullVersionCheckerTests.swift
//
//
//  Created by Philipp Schmid on 21.02.22.
//

import XCTest
@testable import CryptomatorCommonCore
@testable import Dependencies

class FullVersionCheckerTests: XCTestCase {
	var settingsMock: CryptomatorSettingsMock!
	var fullVersionChecker: FullVersionChecker!

	override func setUpWithError() throws {
		settingsMock = CryptomatorSettingsMock()
		DependencyValues.mockDependency(\.cryptomatorSettings, with: settingsMock)
		settingsMock.fullVersionUnlocked = false
		settingsMock.hasRunningSubscription = false
		settingsMock.trialExpirationDate = nil
		fullVersionChecker = UserDefaultsFullVersionChecker()
	}

	// MARK: Is Full Version

	func testIsFullVersionWithLifetime() {
		settingsMock.fullVersionUnlocked = true
		XCTAssert(fullVersionChecker.isFullVersion)
	}

	func testIsFullVersionWithRunningSubscription() {
		settingsMock.fullVersionUnlocked = true
		XCTAssert(fullVersionChecker.isFullVersion)
	}

	func testIsFullVersionWithTrialExpirationDateInTheFuture() {
		settingsMock.trialExpirationDate = .distantFuture
		XCTAssert(fullVersionChecker.isFullVersion)
	}

	func testIsNotFullVersionWithTrialExpirationDateInThePast() {
		settingsMock.trialExpirationDate = .distantPast
		XCTAssertFalse(fullVersionChecker.isFullVersion)
	}

	func testIsNotFullVersionWithNothingSet() {
		XCTAssertFalse(fullVersionChecker.isFullVersion)
	}

	// MARK: Has Expired Trial

	func testHasExpiredTrialWithTrialExpirationDateNotSet() {
		XCTAssertFalse(fullVersionChecker.hasExpiredTrial)
	}

	func testHasExpiredTrialWithExpirationDateInTheFuture() {
		settingsMock.trialExpirationDate = .distantFuture
		XCTAssertFalse(fullVersionChecker.hasExpiredTrial)
	}

	func testHasExpiredTrialWithExpirationDateInThePast() {
		settingsMock.trialExpirationDate = .distantPast
		XCTAssert(fullVersionChecker.hasExpiredTrial)
	}
}
