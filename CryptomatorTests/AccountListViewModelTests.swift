//
//  AccountListViewModelTests.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 22.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import GRDB
import XCTest
@testable import Cryptomator
@testable import CryptomatorCommonCore

class AccountListViewModelTests: XCTestCase {
	func testMoveRow() throws {
		let dbManagerMock = try DatabaseManagerMock()
		let accountManager = CloudProviderAccountDBManager()
		let cloudAuthenticatorMock = CloudAuthenticatorMock(accountManager: accountManager)
		let accountListViewModel = AccountListViewModelMock(with: .dropbox, dbManager: dbManagerMock, cloudAuthenticator: cloudAuthenticatorMock)
		try accountListViewModel.refreshItems()

		XCTAssertEqual(0, accountListViewModel.accountInfos[0].listPosition)
		XCTAssertEqual(1, accountListViewModel.accountInfos[1].listPosition)

		try accountListViewModel.moveRow(at: 0, to: 1)
		XCTAssertEqual("account2", accountListViewModel.accountInfos[0].accountUID)
		XCTAssertEqual(0, accountListViewModel.accountInfos[0].listPosition)
		XCTAssertEqual("account1", accountListViewModel.accountInfos[1].accountUID)
		XCTAssertEqual(1, accountListViewModel.accountInfos[1].listPosition)

		XCTAssertEqual("account2", accountListViewModel.accounts[0].mainLabelText)
		XCTAssertEqual("account1", accountListViewModel.accounts[1].mainLabelText)

		XCTAssertEqual("account2", dbManagerMock.updatedPositions[0].accountUID)
		XCTAssertEqual(0, dbManagerMock.updatedPositions[0].position)
		XCTAssertEqual("account1", dbManagerMock.updatedPositions[1].accountUID)
		XCTAssertEqual(1, dbManagerMock.updatedPositions[1].position)
	}

	func testRemoveRow() throws {
		let dbManagerMock = DatabaseManagerMock()
		let accountManager = CloudProviderAccountDBManager()
		let cloudAuthenticatorMock = CloudAuthenticatorMock(accountManager: accountManager)
		let accountListViewModel = AccountListViewModelMock(with: .dropbox, dbManager: dbManagerMock, cloudAuthenticator: cloudAuthenticatorMock)
		try accountListViewModel.refreshItems()

		XCTAssertEqual(0, accountListViewModel.accountInfos[0].listPosition)
		XCTAssertEqual(1, accountListViewModel.accountInfos[1].listPosition)

		try accountListViewModel.removeRow(at: 0)

		XCTAssertEqual(1, accountListViewModel.accounts.count)
		XCTAssertEqual(1, accountListViewModel.accountInfos.count)
		XCTAssertEqual(1, dbManagerMock.updatedPositions.count)
		XCTAssertEqual("account2", dbManagerMock.updatedPositions[0].accountUID)
		XCTAssertEqual(0, dbManagerMock.updatedPositions[0].position)

		XCTAssertEqual("account1", cloudAuthenticatorMock.deauthenticatedAccounts[0].accountUID)
	}

	func testWebDAVAccountCellContent() throws {
		let dbManagerMock = DatabaseManagerMock()
		let accountManager = CloudProviderAccountDBManager()
		let cloudAuthenticatorMock = CloudAuthenticatorMock(accountManager: accountManager)
		let accountListViewModel = AccountListViewModel(with: .dropbox, dbManager: dbManagerMock, cloudAuthenticator: cloudAuthenticatorMock)
		let baseURL = URL(string: "https://www.example.com")!
		let webDAVCredential = WebDAVCredential(baseURL: baseURL, username: "Alice", password: "Bob", allowedCertificate: nil)
		let accountCellContent = accountListViewModel.createAccountCellContent(for: webDAVCredential)
		XCTAssertEqual("www.example.com", accountCellContent.mainLabelText)
		XCTAssertEqual("Alice", accountCellContent.detailLabelText)
	}

	func testWebDAVAccountCellContentWithPathInDetailLabel() throws {
		let dbManagerMock = DatabaseManagerMock()
		let accountManager = CloudProviderAccountDBManager()
		let cloudAuthenticatorMock = CloudAuthenticatorMock(accountManager: accountManager)
		let accountListViewModel = AccountListViewModel(with: .dropbox, dbManager: dbManagerMock, cloudAuthenticator: cloudAuthenticatorMock)
		let baseURL = URL(string: "https://www.example.com/path")!
		let webDAVCredential = WebDAVCredential(baseURL: baseURL, username: "Alice", password: "Bob", allowedCertificate: nil)
		let accountCellContent = accountListViewModel.createAccountCellContent(for: webDAVCredential)
		XCTAssertEqual("www.example.com", accountCellContent.mainLabelText)
		XCTAssertEqual("Alice • /path", accountCellContent.detailLabelText)
	}

	func testWebDAVAccountCellContentWithUnknownHost() throws {
		let dbManagerMock = DatabaseManagerMock()
		let accountManager = CloudProviderAccountDBManager()
		let cloudAuthenticatorMock = CloudAuthenticatorMock(accountManager: accountManager)
		let accountListViewModel = AccountListViewModel(with: .dropbox, dbManager: dbManagerMock, cloudAuthenticator: cloudAuthenticatorMock)
		let baseURL = URL(string: "www")!
		let webDAVCredential = WebDAVCredential(baseURL: baseURL, username: "Alice", password: "Bob", allowedCertificate: nil)
		let accountCellContent = accountListViewModel.createAccountCellContent(for: webDAVCredential)
		XCTAssertEqual("<unknown-host>", accountCellContent.mainLabelText)
		XCTAssertEqual("Alice • www", accountCellContent.detailLabelText)
	}
}

private class DatabaseManagerMock: DatabaseManager {
	var updatedPositions = [AccountListPosition]()
	let accounts = [AccountInfo(cloudProviderAccount: CloudProviderAccount(accountUID: "account1", cloudProviderType: .dropbox),
	                            accountListPosition: AccountListPosition(id: 0, position: 0, accountUID: "account1")),
	                AccountInfo(cloudProviderAccount: CloudProviderAccount(accountUID: "account2", cloudProviderType: .dropbox),
	                            accountListPosition: AccountListPosition(id: 1, position: 1, accountUID: "account2"))]

	override func getAllAccounts(for: CloudProviderType) throws -> [AccountInfo] {
		return accounts
	}

	override func updateAccountListPositions(_ positions: [AccountListPosition]) throws {
		updatedPositions = positions
	}
}

private class AccountListViewModelMock: AccountListViewModel {
	override func createAccountCellContent(from accountInfo: AccountInfo) throws -> AccountCellContent {
		return AccountCellContent(mainLabelText: accountInfo.accountUID, detailLabelText: nil)
	}
}

private class CloudAuthenticatorMock: CloudAuthenticator {
	var deauthenticatedAccounts = [CloudProviderAccount]()

	override func deauthenticate(account: CloudProviderAccount) throws {
		deauthenticatedAccounts.append(account)
	}
}
