//
//  CloudAuthenticatorTests.swift
//  CryptomatorTests
//
//  Created by Tobias Hagemann on 16.10.26.
//  Copyright © 2026 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import XCTest
@testable import Cryptomator
@testable import CryptomatorCommonCore

@MainActor
class CloudAuthenticatorTests: XCTestCase {
	private let account = CloudProviderAccount(accountUID: "account-1", cloudProviderType: .localFileSystem(type: .custom))
	private var accountManagerMock: CloudProviderAccountManagerMock!
	private var vaultManagerMock: VaultManagerMock!
	private var authenticator: CloudAuthenticator!

	override func setUp() async throws {
		try await super.setUp()
		accountManagerMock = CloudProviderAccountManagerMock()
		vaultManagerMock = VaultManagerMock()
		let vaultAccountManagerMock = VaultAccountManagerMock(accounts: [
			VaultAccount(vaultUID: "vault-1", delegateAccountUID: "account-1", vaultPath: CloudPath("/Vault1"), vaultName: "Vault1"),
			VaultAccount(vaultUID: "vault-2", delegateAccountUID: "account-2", vaultPath: CloudPath("/Vault2"), vaultName: "Vault2"),
			VaultAccount(vaultUID: "vault-3", delegateAccountUID: "account-1", vaultPath: CloudPath("/Vault3"), vaultName: "Vault3")
		])
		authenticator = CloudAuthenticator(accountManager: accountManagerMock, vaultManager: vaultManagerMock, vaultAccountManager: vaultAccountManagerMock)
	}

	func testDeauthenticateRemovesVaultsOfAccountBeforeAccount() async throws {
		var removedUIDs = [String]()
		let accountRemoved = XCTestExpectation()
		vaultManagerMock.removeVaultsWithUIDsClosure = { vaultUIDs in
			removedUIDs.append(contentsOf: vaultUIDs)
		}
		accountManagerMock.removeAccountClosure = { accountUID in
			removedUIDs.append(accountUID)
			accountRemoved.fulfill()
		}

		try authenticator.deauthenticate(account: account)

		await fulfillment(of: [accountRemoved], timeout: 5.0)
		XCTAssertEqual(["vault-1", "vault-3", "account-1"], removedUIDs)
	}

	func testDeauthenticateKeepsAccountWhenVaultRemovalFails() async throws {
		let vaultRemovalFailed = XCTestExpectation()
		let accountRemoved = XCTestExpectation()
		accountRemoved.isInverted = true
		vaultManagerMock.removeVaultsWithUIDsClosure = { _ in
			vaultRemovalFailed.fulfill()
			throw MockError.notMocked
		}
		accountManagerMock.removeAccountClosure = { _ in
			accountRemoved.fulfill()
		}

		try authenticator.deauthenticate(account: account)

		await fulfillment(of: [vaultRemovalFailed, accountRemoved], timeout: 1.0)
	}
}

private class CloudProviderAccountManagerMock: CloudProviderAccountManager {
	var removeAccountClosure: ((String) -> Void)?

	func getAccount(for accountUID: String) throws -> CloudProviderAccount {
		throw MockError.notMocked
	}

	func getAllAccountUIDs(for type: CloudProviderType) throws -> [String] {
		throw MockError.notMocked
	}

	func saveNewAccount(_ account: CloudProviderAccount) throws {
		throw MockError.notMocked
	}

	func removeAccount(with accountUID: String) throws {
		removeAccountClosure?(accountUID)
	}
}

private class VaultAccountManagerMock: VaultAccountManager {
	private let accounts: [VaultAccount]

	init(accounts: [VaultAccount]) {
		self.accounts = accounts
	}

	func saveNewAccount(_ account: VaultAccount) throws {
		throw MockError.notMocked
	}

	func removeAccount(with vaultUID: String) throws {
		throw MockError.notMocked
	}

	func removeAccounts(with vaultUIDs: [String]) throws {
		throw MockError.notMocked
	}

	func getAccount(with vaultUID: String) throws -> VaultAccount {
		throw MockError.notMocked
	}

	func getAllAccounts() throws -> [VaultAccount] {
		return accounts
	}

	func updateAccount(_ account: VaultAccount) throws {
		throw MockError.notMocked
	}
}
