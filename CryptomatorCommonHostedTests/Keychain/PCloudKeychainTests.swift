//
//  PCloudKeychainTests.swift
//  CryptomatorCommonHostedTests
//
//  Created by Tobias Hagemann on 16.03.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import CryptomatorCloudAccessCore
import XCTest
@testable import CryptomatorCommonCore
@testable import PCloudSDKSwift

class PCloudKeychainTests: XCTestCase {
	func testSaveCredentialToKeychain() throws {
		let user = OAuth.User(id: 0, token: "Foo", serverRegionId: 0, httpAPIHostName: "")
		let credential = PCloudCredential(user: user)
		try credential.saveToKeychain()

		let fetchedCredential = try PCloudCredential(userID: "0")
		XCTAssertEqual(user, fetchedCredential.user)
		try credential.deauthenticate()
	}

	func testSaveUpdatedCredentialToKeychain() throws {
		let user = OAuth.User(id: 0, token: "Foo", serverRegionId: 0, httpAPIHostName: "")
		let credential = PCloudCredential(user: user)
		try credential.saveToKeychain()

		let updatedUser = OAuth.User(id: 0, token: "Bar", serverRegionId: 0, httpAPIHostName: "")
		let updatedCredential = PCloudCredential(user: updatedUser)
		try updatedCredential.saveToKeychain()

		let fetchedCredential = try PCloudCredential(userID: "0")
		XCTAssertEqual(updatedUser, fetchedCredential.user)
		try credential.deauthenticate()
	}

	func testMultipleCredentialSupport() throws {
		let user1 = OAuth.User(id: 0, token: "Foo", serverRegionId: 0, httpAPIHostName: "")
		let credential1 = PCloudCredential(user: user1)
		try credential1.saveToKeychain()

		let user2 = OAuth.User(id: 1, token: "Bar", serverRegionId: 0, httpAPIHostName: "")
		let credential2 = PCloudCredential(user: user2)
		try credential2.saveToKeychain()

		let fetchedCredential1 = try PCloudCredential(userID: "0")
		XCTAssertEqual(user1, fetchedCredential1.user)

		let fetchedCredential2 = try PCloudCredential(userID: "1")
		XCTAssertEqual(user2, fetchedCredential2.user)

		try credential1.deauthenticate()
		try credential2.deauthenticate()
	}

	func testRemoveCredentialFromKeychain() throws {
		let user = OAuth.User(id: 0, token: "Foo", serverRegionId: 0, httpAPIHostName: "")
		let credential = PCloudCredential(user: user)
		try credential.saveToKeychain()

		let fetchedCredential = try PCloudCredential(userID: "0")
		XCTAssertEqual(user, fetchedCredential.user)
		try credential.deauthenticate()

		XCTAssertThrowsError(try PCloudCredential(userID: "0")) { error in
			guard case CloudProviderAccountError.accountNotFoundError = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}
	}

	func testInitCredentialWithMissingUserID() throws {
		XCTAssertThrowsError(try PCloudCredential(userID: "0")) { error in
			guard case CloudProviderAccountError.accountNotFoundError = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}
	}
}
