//
//  S3CredentialManagerTests.swift
//
//
//  Created by Philipp Schmid on 29.06.22.
//

import CryptomatorCloudAccessCore
import GRDB
import XCTest
@testable import CryptomatorCommonCore

class S3CredentialManagerTests: XCTestCase {
	var manager: S3CredentialManager!
	var cryptomatorKeychainMock: CryptomatorKeychainMock!
	let displayName = "Cryptomator S3"

	override func setUpWithError() throws {
		cryptomatorKeychainMock = CryptomatorKeychainMock()
		manager = S3CredentialManager(keychain: cryptomatorKeychainMock)
	}

	func testSaveCredential() throws {
		try manager.save(credential: .stub, displayName: displayName)
		try assertCredentialSavedToKeychain(.stub)

		let savedDisplayName = try manager.getDisplayName(for: .stub)
		XCTAssertEqual(displayName, savedDisplayName)
	}

	func testRemoveCredential() throws {
		try manager.save(credential: .stub, displayName: displayName)
		try manager.removeCredential(.stub)

		assertCredentialRemovedFromKeychain()
		XCTAssertNil(try manager.getDisplayName(for: .stub))
	}

	func testSaveCredentialRollbacksIfKeychainFails() throws {
		cryptomatorKeychainMock.setValueThrowableError = CryptomatorKeychainError.unhandledError(status: errSecDuplicateItem)
		XCTAssertThrowsError(try manager.save(credential: .stub, displayName: displayName))

		XCTAssertNil(try manager.getDisplayName(for: .stub))
	}

	func testSaveDuplicateDisplayName() throws {
		try manager.save(credential: .stub, displayName: displayName)
		try assertCredentialSavedToKeychain(.stub)
		let secondCredential = S3Credential(accessKey: "access-key-123", secretKey: "secret-key-345", url: URL(string: "https://example.com")!, bucket: "exampleBucket", region: "customRegion", identifier: "DifferentIdentifier")
		try manager.save(credential: secondCredential, displayName: displayName)
		try assertCredentialSavedToKeychain(secondCredential)
		XCTAssertEqual(2, cryptomatorKeychainMock.setValueCallsCount)
	}

	private func assertCredentialSavedToKeychain(_ expectedCredential: S3Credential) throws {
		let receivedArguments = try XCTUnwrap(cryptomatorKeychainMock.setValueReceivedArguments)
		let key = receivedArguments.key
		let data = receivedArguments.value
		let savedCredential = try JSONDecoder().decode(S3Credential.self, from: data)
		XCTAssertEqual(expectedCredential, savedCredential)
		XCTAssertEqual(expectedCredential.identifier, key)
	}

	private func assertCredentialRemovedFromKeychain() {
		XCTAssertEqual([S3Credential.stub.identifier], cryptomatorKeychainMock.deleteReceivedInvocations)
	}
}

private extension S3Credential {
	static let stub = S3Credential(accessKey: "access-key-123", secretKey: "secret-key-345", url: URL(string: "https://example.com")!, bucket: "exampleBucket", region: "customRegion", identifier: "Foo-12345")
}
