//
//  VaultPasswordKeychainManagerTests.swift
//  CryptomatorCommonHostedTests
//
//  Created by Philipp Schmid on 10.07.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import LocalAuthentication
import XCTest
@testable import CryptomatorCommonCore

class VaultPasswordKeychainManagerTests: XCTestCase {
	func testSetAndRetrievePassword() throws {
		if #available(iOS 15.0, *) {
			throw XCTSkip("User presence keychain doesn't work in iOS 15 simulator (Radar 82890873)")
		}
		let passwordManager = VaultPasswordKeychainManager()
		let password = "pw"
		let vaultUID = UUID().uuidString
		try passwordManager.setPassword(password, forVaultUID: vaultUID)
		let fetchedPassword = try passwordManager.getPassword(forVaultUID: vaultUID, context: LAContext())
		XCTAssertEqual(password, fetchedPassword)
		try passwordManager.removePassword(forVaultUID: vaultUID)
	}

	func testSetPasswordOverwritesExisting() throws {
		if #available(iOS 15.0, *) {
			throw XCTSkip("User presence keychain doesn't work in iOS 15 simulator (Radar 82890873)")
		}
		let passwordManager = VaultPasswordKeychainManager()
		let oldPassword = "pw"
		let vaultUID = UUID().uuidString
		try passwordManager.setPassword(oldPassword, forVaultUID: vaultUID)
		let newPassword = "newPW"
		try passwordManager.setPassword(newPassword, forVaultUID: vaultUID)
		let fetchedPassword = try passwordManager.getPassword(forVaultUID: vaultUID, context: LAContext())
		XCTAssertEqual(newPassword, fetchedPassword)
		try passwordManager.removePassword(forVaultUID: vaultUID)
	}

	func testRemovePassword() throws {
		if #available(iOS 15.0, *) {
			throw XCTSkip("User presence keychain doesn't work in iOS 15 simulator (Radar 82890873)")
		}
		let passwordManager = VaultPasswordKeychainManager()
		let password = "pw"
		let vaultUID = UUID().uuidString
		try passwordManager.setPassword(password, forVaultUID: vaultUID)
		try passwordManager.removePassword(forVaultUID: vaultUID)
		XCTAssertThrowsError(try passwordManager.getPassword(forVaultUID: vaultUID, context: LAContext())) { error in
			guard case VaultPasswordManagerError.passwordNotFound = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}
	}
}
