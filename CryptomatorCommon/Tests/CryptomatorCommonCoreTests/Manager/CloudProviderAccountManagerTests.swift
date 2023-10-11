//
//  CloudProviderAccountManagerTests.swift
//  CryptomatorCommonCoreTests
//
//  Created by Philipp Schmid on 20.10.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation
import GRDB
import XCTest
@testable import CryptomatorCommonCore
@testable import Dependencies

class CloudProviderAccountManagerTests: XCTestCase {
	var accountManager: CloudProviderAccountDBManager!

	override func setUpWithError() throws {
		accountManager = CloudProviderAccountDBManager()
	}

	func testSaveAccount() throws {
		let accountUID = UUID().uuidString
		let account = CloudProviderAccount(accountUID: accountUID, cloudProviderType: .googleDrive)
		try accountManager.saveNewAccount(account)
		let fetchedCloudProviderType = try accountManager.getCloudProviderType(for: accountUID)
		XCTAssertEqual(CloudProviderType.googleDrive, fetchedCloudProviderType)
	}

	func testRemoveAccount() throws {
		let accountUID = UUID().uuidString
		let account = CloudProviderAccount(accountUID: accountUID, cloudProviderType: .googleDrive)
		try accountManager.saveNewAccount(account)
		let fetchedCloudProviderType = try accountManager.getCloudProviderType(for: accountUID)
		XCTAssertEqual(CloudProviderType.googleDrive, fetchedCloudProviderType)
		try accountManager.removeAccount(with: accountUID)
		XCTAssertThrowsError(try accountManager.getCloudProviderType(for: accountUID)) { error in
			guard case CloudProviderAccountError.accountNotFoundError = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}
	}

	func testGellAccountUIDsForCloudProviderType() throws {
		let accountUIDs = [
			UUID().uuidString,
			UUID().uuidString,
			UUID().uuidString,
			UUID().uuidString
		]
		let accounts = [
			CloudProviderAccount(accountUID: accountUIDs[0], cloudProviderType: .googleDrive),
			CloudProviderAccount(accountUID: accountUIDs[1], cloudProviderType: .googleDrive),
			CloudProviderAccount(accountUID: accountUIDs[2], cloudProviderType: .dropbox),
			CloudProviderAccount(accountUID: accountUIDs[3], cloudProviderType: .googleDrive)
		]
		for account in accounts {
			try accountManager.saveNewAccount(account)
		}
		let fetchedAccountUIDsForGoogleDrive = try accountManager.getAllAccountUIDs(for: .googleDrive)
		XCTAssertEqual(3, fetchedAccountUIDsForGoogleDrive.count)
		XCTAssert(fetchedAccountUIDsForGoogleDrive.contains { $0 == accounts[0].accountUID })
		XCTAssert(fetchedAccountUIDsForGoogleDrive.contains { $0 == accounts[1].accountUID })
		XCTAssert(fetchedAccountUIDsForGoogleDrive.contains { $0 == accounts[3].accountUID })

		let fetchedAccountUIDsForDropbox = try accountManager.getAllAccountUIDs(for: .dropbox)
		XCTAssertEqual(1, fetchedAccountUIDsForDropbox.count)
		XCTAssert(fetchedAccountUIDsForDropbox.contains { $0 == accounts[2].accountUID })
	}
}
