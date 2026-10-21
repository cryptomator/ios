//
//  DefaultAccountReauthenticationBehaviorTests.swift
//  CryptomatorTests
//
//  Created by Tobias Hagemann on 01.09.26.
//  Copyright © 2026 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import UIKit
import XCTest
@testable import Cryptomator

/**
 Pins which outcome reaches `CloudAuthenticator.deauthenticate`, because that call removes the account and every vault that belongs to it.
 */
@MainActor
class DefaultAccountReauthenticationBehaviorTests: XCTestCase {
	private let expectedAccount = CloudProviderAccount(accountUID: "account-1", cloudProviderType: .dropbox)
	private var coordinator: ReauthenticatingCoordinatorMock!
	private var viewController: UIViewController!

	override func setUp() async throws {
		try await super.setUp()
		coordinator = ReauthenticatingCoordinatorMock()
		viewController = UIViewController()
	}

	// MARK: - Discards

	func testDiscardsAccountAddedBySignIn() async {
		let addedAccount = CloudProviderAccount(accountUID: "account-2", cloudProviderType: .dropbox)
		let authenticator = CloudAuthenticatorMock(reAuthAccount: addedAccount, accountUIDs: ["account-1"])

		await XCTAssertThrowsAsyncError(try await coordinator.reauthenticate(expectedAccount, from: viewController, authenticator: authenticator)) { error in
			XCTAssertEqual(AccountReauthenticationError.accountMismatch as NSError, error as NSError)
		}

		XCTAssertTrue(authenticator.authenticateCalled)
		XCTAssertEqual([addedAccount.accountUID], authenticator.deauthenticatedAccountUIDs)
	}

	// MARK: - Keeps

	func testKeepsAccountTheUserAlreadyHad() async {
		let otherAccount = CloudProviderAccount(accountUID: "account-2", cloudProviderType: .dropbox)
		let authenticator = CloudAuthenticatorMock(reAuthAccount: otherAccount, accountUIDs: ["account-1", "account-2"])

		await XCTAssertThrowsAsyncError(try await coordinator.reauthenticate(expectedAccount, from: viewController, authenticator: authenticator)) { error in
			XCTAssertEqual(AccountReauthenticationError.accountMismatch as NSError, error as NSError)
		}

		XCTAssertTrue(authenticator.authenticateCalled)
		XCTAssertTrue(authenticator.deauthenticatedAccountUIDs.isEmpty)
	}

	func testKeepsAccountWhenKnownAccountsCannotBeRead() async {
		let otherAccount = CloudProviderAccount(accountUID: "account-2", cloudProviderType: .dropbox)
		let authenticator = CloudAuthenticatorMock(reAuthAccount: otherAccount, accountUIDs: nil)

		await XCTAssertThrowsAsyncError(try await coordinator.reauthenticate(expectedAccount, from: viewController, authenticator: authenticator)) { error in
			XCTAssertEqual(AccountReauthenticationError.accountMismatch as NSError, error as NSError)
		}

		XCTAssertTrue(authenticator.authenticateCalled)
		XCTAssertTrue(authenticator.deauthenticatedAccountUIDs.isEmpty)
	}

	func testKeepsAccountOnMatch() async throws {
		let authenticator = CloudAuthenticatorMock(reAuthAccount: expectedAccount, accountUIDs: ["account-1"])

		let reAuthAccount = try await coordinator.reauthenticate(expectedAccount, from: viewController, authenticator: authenticator)

		XCTAssertTrue(authenticator.authenticateCalled)
		XCTAssertTrue(authenticator.deauthenticatedAccountUIDs.isEmpty)
		XCTAssertEqual(expectedAccount, reAuthAccount)
	}

	// MARK: - Failed sign-in

	/**
	 The user closed the sign-in screen on purpose, thus the rejection passes through unchanged.
	 */
	func testKeepsAccountOnCancellation() async {
		let authenticator = CloudAuthenticatorMock(authenticateError: CocoaError(.userCancelled), accountUIDs: ["account-1"])

		await XCTAssertThrowsAsyncError(try await coordinator.reauthenticate(expectedAccount, from: viewController, authenticator: authenticator)) { error in
			XCTAssertEqual(CocoaError(.userCancelled) as NSError, error as NSError)
		}

		XCTAssertTrue(authenticator.authenticateCalled)
		XCTAssertTrue(authenticator.deauthenticatedAccountUIDs.isEmpty)
	}

	func testKeepsAccountOnFailedSignIn() async {
		let authenticator = CloudAuthenticatorMock(authenticateError: CloudProviderError.unauthorized, accountUIDs: ["account-1"])

		await XCTAssertThrowsAsyncError(try await coordinator.reauthenticate(expectedAccount, from: viewController, authenticator: authenticator)) { error in
			XCTAssertEqual(CloudProviderError.unauthorized as NSError, error as NSError)
		}

		XCTAssertTrue(authenticator.authenticateCalled)
		XCTAssertTrue(authenticator.deauthenticatedAccountUIDs.isEmpty)
	}

	// MARK: - Unsupported cloud provider

	/**
	 Signing in again mints a new identifier for these providers, so it must not run at all.
	 */
	func testRejectsProviderThatCannotKeepItsAccount() async {
		let s3Account = CloudProviderAccount(accountUID: "account-1", cloudProviderType: .s3(type: .custom))
		let authenticator = CloudAuthenticatorMock(reAuthAccount: s3Account, accountUIDs: ["account-1"])

		await XCTAssertThrowsAsyncError(try await coordinator.reauthenticate(s3Account, from: viewController, authenticator: authenticator)) { error in
			XCTAssertEqual(AccountReauthenticationError.unsupportedCloudProviderType as NSError, error as NSError)
		}

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

	override func authenticate(_ cloudProviderType: CloudProviderType, from viewController: UIViewController) async throws -> CloudProviderAccount {
		authenticateCalled = true
		if let authenticateError = authenticateError {
			throw authenticateError
		}
		guard let reAuthAccount = reAuthAccount else {
			throw MockError.notMocked
		}
		return reAuthAccount
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
