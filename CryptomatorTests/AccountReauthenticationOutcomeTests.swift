//
//  AccountReauthenticationOutcomeTests.swift
//  CryptomatorTests
//
//  Created by Tobias Hagemann on 31.08.26.
//  Copyright © 2026 Skymatic GmbH. All rights reserved.
//

import XCTest
@testable import Cryptomator

class AccountReauthenticationOutcomeTests: XCTestCase {
	// MARK: - Matched

	func testMatchedForSameAccount() {
		let outcome = AccountReauthenticationOutcome(expectedAccountUID: "account-1", reAuthAccountUID: "account-1", accountUIDsBeforeSignIn: ["account-1", "account-2"])
		XCTAssertEqual(.matched, outcome)
	}

	func testMatchedEvenIfAccountIsNotKnown() {
		let outcome = AccountReauthenticationOutcome(expectedAccountUID: "account-1", reAuthAccountUID: "account-1", accountUIDsBeforeSignIn: [])
		XCTAssertEqual(.matched, outcome)
	}

	func testMatchedForSameAccountEvenIfKnownAccountsAreUnreadable() {
		let outcome = AccountReauthenticationOutcome(expectedAccountUID: "account-1", reAuthAccountUID: "account-1", accountUIDsBeforeSignIn: nil)
		XCTAssertEqual(.matched, outcome)
	}

	// MARK: - Mismatched with a new account

	func testMismatchedWithNewAccountForAccountAddedBySignIn() {
		let outcome = AccountReauthenticationOutcome(expectedAccountUID: "account-1", reAuthAccountUID: "account-2", accountUIDsBeforeSignIn: ["account-1"])
		XCTAssertEqual(.mismatchedWithNewAccount, outcome)
	}

	func testMismatchedWithNewAccountForThirdAccountBesideSeveralKnownOnes() {
		let outcome = AccountReauthenticationOutcome(expectedAccountUID: "account-1", reAuthAccountUID: "account-3", accountUIDsBeforeSignIn: ["account-1", "account-2"])
		XCTAssertEqual(.mismatchedWithNewAccount, outcome)
	}

	// MARK: - Mismatched with a known account

	func testMismatchedWithKnownAccountForAccountTheUserAlreadyHad() {
		let outcome = AccountReauthenticationOutcome(expectedAccountUID: "account-1", reAuthAccountUID: "account-2", accountUIDsBeforeSignIn: ["account-1", "account-2"])
		XCTAssertEqual(.mismatchedWithKnownAccount, outcome)
	}

	// MARK: - Untrustworthy known accounts

	/**
	 Discarding an account removes its vaults, so a list that could not be read must never lead to `mismatchedWithNewAccount`.
	 */
	func testMismatchedWithKnownAccountForUnreadableKnownAccounts() {
		let outcome = AccountReauthenticationOutcome(expectedAccountUID: "account-1", reAuthAccountUID: "account-2", accountUIDsBeforeSignIn: nil)
		XCTAssertEqual(.mismatchedWithKnownAccount, outcome)
	}

	/**
	 The caller just read the expected account, so a list without it is incomplete and proves nothing about the re-authenticated account.
	 */
	func testMismatchedWithKnownAccountForKnownAccountsWithoutTheExpectedAccount() {
		let outcome = AccountReauthenticationOutcome(expectedAccountUID: "account-1", reAuthAccountUID: "account-2", accountUIDsBeforeSignIn: ["account-3"])
		XCTAssertEqual(.mismatchedWithKnownAccount, outcome)
	}

	func testMismatchedWithKnownAccountForEmptyKnownAccounts() {
		let outcome = AccountReauthenticationOutcome(expectedAccountUID: "account-1", reAuthAccountUID: "account-2", accountUIDsBeforeSignIn: [])
		XCTAssertEqual(.mismatchedWithKnownAccount, outcome)
	}
}
