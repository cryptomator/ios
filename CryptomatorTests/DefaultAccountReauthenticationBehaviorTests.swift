//
//  DefaultAccountReauthenticationBehaviorTests.swift
//  CryptomatorTests
//
//  Created by Tobias Hagemann on 01.09.26.
//  Copyright © 2026 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Promises
import UIKit
import XCTest
@testable import Cryptomator

/**
 Pins which outcome reaches `CloudAuthenticator.deauthenticate`, because that call removes the account and every vault that belongs to it.
 */
class DefaultAccountReauthenticationBehaviorTests: XCTestCase {
	private let expectedAccount = CloudProviderAccount(accountUID: "account-1", cloudProviderType: .dropbox)
	private var coordinator: ReauthenticatingCoordinatorMock!
	private var viewController: UIViewController!

	override func setUpWithError() throws {
		coordinator = ReauthenticatingCoordinatorMock()
		viewController = UIViewController()
	}

	// MARK: - Discards

	func testDiscardsAccountAddedBySignIn() {
		let addedAccount = CloudProviderAccount(accountUID: "account-2", cloudProviderType: .dropbox)
		let authenticator = CloudAuthenticatorMock(reAuthAccount: addedAccount, accountUIDs: ["account-1"])

		let promise = coordinator.reauthenticate(expectedAccount, from: viewController, authenticator: authenticator)
		XCTAssertRejects(promise, with: AccountReauthenticationError.accountMismatch)

		XCTAssertTrue(authenticator.authenticateCalled)
		XCTAssertEqual([addedAccount.accountUID], authenticator.deauthenticatedAccountUIDs)
	}

	// MARK: - Keeps

	func testKeepsAccountTheUserAlreadyHad() {
		let otherAccount = CloudProviderAccount(accountUID: "account-2", cloudProviderType: .dropbox)
		let authenticator = CloudAuthenticatorMock(reAuthAccount: otherAccount, accountUIDs: ["account-1", "account-2"])

		let promise = coordinator.reauthenticate(expectedAccount, from: viewController, authenticator: authenticator)
		XCTAssertRejects(promise, with: AccountReauthenticationError.accountMismatch)

		XCTAssertTrue(authenticator.authenticateCalled)
		XCTAssertTrue(authenticator.deauthenticatedAccountUIDs.isEmpty)
	}

	func testKeepsAccountWhenKnownAccountsCannotBeRead() {
		let otherAccount = CloudProviderAccount(accountUID: "account-2", cloudProviderType: .dropbox)
		let authenticator = CloudAuthenticatorMock(reAuthAccount: otherAccount, accountUIDs: nil)

		let promise = coordinator.reauthenticate(expectedAccount, from: viewController, authenticator: authenticator)
		XCTAssertRejects(promise, with: AccountReauthenticationError.accountMismatch)

		XCTAssertTrue(authenticator.authenticateCalled)
		XCTAssertTrue(authenticator.deauthenticatedAccountUIDs.isEmpty)
	}

	func testKeepsAccountOnMatch() {
		let authenticator = CloudAuthenticatorMock(reAuthAccount: expectedAccount, accountUIDs: ["account-1"])

		var reAuthAccount: CloudProviderAccount?
		let promise = coordinator.reauthenticate(expectedAccount, from: viewController, authenticator: authenticator).then { account in
			reAuthAccount = account
		}
		wait(for: promise)

		XCTAssertTrue(authenticator.authenticateCalled)
		XCTAssertTrue(authenticator.deauthenticatedAccountUIDs.isEmpty)
		XCTAssertEqual(expectedAccount, reAuthAccount)
	}

	// MARK: - Failed sign-in

	/**
	 The user closed the sign-in screen on purpose, thus the rejection passes through unchanged.
	 */
	func testKeepsAccountOnCancellation() {
		let authenticator = CloudAuthenticatorMock(authenticateError: CocoaError(.userCancelled), accountUIDs: ["account-1"])

		let promise = coordinator.reauthenticate(expectedAccount, from: viewController, authenticator: authenticator)
		XCTAssertRejects(promise, with: CocoaError(.userCancelled))

		XCTAssertTrue(authenticator.authenticateCalled)
		XCTAssertTrue(authenticator.deauthenticatedAccountUIDs.isEmpty)
	}

	func testKeepsAccountOnFailedSignIn() {
		let authenticator = CloudAuthenticatorMock(authenticateError: CloudProviderError.unauthorized, accountUIDs: ["account-1"])

		let promise = coordinator.reauthenticate(expectedAccount, from: viewController, authenticator: authenticator)
		XCTAssertRejects(promise, with: CloudProviderError.unauthorized)

		XCTAssertTrue(authenticator.authenticateCalled)
		XCTAssertTrue(authenticator.deauthenticatedAccountUIDs.isEmpty)
	}

	// MARK: - Unsupported cloud provider

	/**
	 Signing in again mints a new identifier for these providers, so it must not run at all.
	 */
	func testRejectsProviderThatCannotKeepItsAccount() {
		let s3Account = CloudProviderAccount(accountUID: "account-1", cloudProviderType: .s3(type: .custom))
		let authenticator = CloudAuthenticatorMock(reAuthAccount: s3Account, accountUIDs: ["account-1"])

		let promise = coordinator.reauthenticate(s3Account, from: viewController, authenticator: authenticator)
		XCTAssertRejects(promise, with: AccountReauthenticationError.unsupportedCloudProviderType)

		XCTAssertFalse(authenticator.authenticateCalled)
		XCTAssertTrue(authenticator.deauthenticatedAccountUIDs.isEmpty)
	}
}

private class ReauthenticatingCoordinatorMock: Coordinator, DefaultAccountReauthenticationBehavior {
	var childCoordinators = [Coordinator]()
	/// Holds no root view controller, so the alerts this flow shows have nothing to present on.
	var navigationController = UINavigationController()

	func start() {}
}

private class CloudAuthenticatorMock: CloudAuthenticator {
	private(set) var authenticateCalled = false
	private(set) var deauthenticatedAccountUIDs = [String]()
	private let reAuthAccount: CloudProviderAccount?
	private let authenticateError: Error?

	init(reAuthAccount: CloudProviderAccount, accountUIDs: [String]?) {
		self.reAuthAccount = reAuthAccount
		self.authenticateError = nil
		super.init(accountManager: CloudProviderAccountManagerMock(accountUIDs: accountUIDs))
	}

	init(authenticateError: Error, accountUIDs: [String]?) {
		self.reAuthAccount = nil
		self.authenticateError = authenticateError
		super.init(accountManager: CloudProviderAccountManagerMock(accountUIDs: accountUIDs))
	}

	override func authenticate(_ cloudProviderType: CloudProviderType, from viewController: UIViewController) -> Promise<CloudProviderAccount> {
		authenticateCalled = true
		if let authenticateError = authenticateError {
			return Promise(authenticateError)
		}
		guard let reAuthAccount = reAuthAccount else {
			return Promise(MockError.notMocked)
		}
		return Promise(reAuthAccount)
	}

	override func deauthenticate(account: CloudProviderAccount) throws {
		deauthenticatedAccountUIDs.append(account.accountUID)
	}
}

private class CloudProviderAccountManagerMock: CloudProviderAccountManager {
	/// `nil` stands for a read that failed.
	private let accountUIDs: [String]?

	init(accountUIDs: [String]?) {
		self.accountUIDs = accountUIDs
	}

	func getAccount(for accountUID: String) throws -> CloudProviderAccount {
		throw MockError.notMocked
	}

	func getAllAccountUIDs(for type: CloudProviderType) throws -> [String] {
		guard let accountUIDs = accountUIDs else {
			throw MockError.notMocked
		}
		return accountUIDs
	}

	func saveNewAccount(_ account: CloudProviderAccount) throws {}

	func removeAccount(with accountUID: String) throws {}
}
