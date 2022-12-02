//
//  WebDAVKeychainTests.swift
//  CryptomatorIntegrationTests
//
//  Created by Philipp Schmid on 22.10.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import CryptomatorCloudAccessCore
import XCTest
@testable import CryptomatorCommonCore

class WebDAVKeychainTests: XCTestCase {
	var manager: WebDAVCredentialManager!
	var keychain: CryptomatorKeychainType!

	override func setUpWithError() throws {
		keychain = CryptomatorKeychain(service: UUID().uuidString)
		manager = WebDAVCredentialManager(keychain: keychain)
	}

	func testSaveCredentialToKeychain() {
		let baseURL = URL(string: "www.testurl.com")!
		let username = "user"
		let password = "pass"
		let certificate = "CertificateData".data(using: .utf8)
		let identifier = UUID().uuidString
		let credential = WebDAVCredential(baseURL: baseURL, username: username, password: password, allowedCertificate: certificate, identifier: identifier)

		XCTAssertNoThrow(try manager.saveCredentialToKeychain(credential))

		guard let fetchedCredential = manager.getCredentialFromKeychain(with: identifier) else {
			XCTFail("No Credential found in Keychain for accountUID: \(identifier)")
			return
		}
		XCTAssertEqual(baseURL, fetchedCredential.baseURL)
		XCTAssertEqual(username, fetchedCredential.username)
		XCTAssertEqual(password, fetchedCredential.password)
		XCTAssertEqual(certificate, fetchedCredential.allowedCertificate)
		XCTAssertEqual(identifier, fetchedCredential.identifier)

		XCTAssertNoThrow(try manager.removeCredentialFromKeychain(with: identifier))
	}

	func testSaveCredentialDuplicatesToKeychain() throws {
		let baseURL = URL(string: "www.testurl.com")!
		let username = "user"
		let password = "pass"
		let certificate = "CertificateData".data(using: .utf8)
		let identifier = UUID().uuidString
		let credential = WebDAVCredential(baseURL: baseURL, username: username, password: password, allowedCertificate: certificate, identifier: identifier)

		try manager.saveCredentialToKeychain(credential)

		// Different Identifier is a duplicate if baseURL and username already exists in the keychain
		let duplicateCredential = WebDAVCredential(baseURL: baseURL, username: username, password: password, allowedCertificate: certificate, identifier: UUID().uuidString)
		checkSaveThrowsDuplicateErrorAndKeychainDidNotChange(for: duplicateCredential, originalCredential: credential)

		// Different Password is still a duplicate if baseURL and username already exists in the keychain and the identifier does not match
		checkSaveThrowsDuplicateErrorAndKeychainDidNotChange(for: WebDAVCredential(baseURL: baseURL, username: username, password: password + "Foo", allowedCertificate: certificate, identifier: UUID().uuidString), originalCredential: credential)

		// Different Certificate is still a duplicate if baseURL and username already exists in the keychain and the identifier does not match
		checkSaveThrowsDuplicateErrorAndKeychainDidNotChange(for: WebDAVCredential(baseURL: baseURL, username: username, password: password, allowedCertificate: "CertificateData1".data(using: .utf8), identifier: UUID().uuidString), originalCredential: credential)

		// Missing Certificate is still a duplicate if baseURL and username already exists in the keychain and the identifier does not match
		checkSaveThrowsDuplicateErrorAndKeychainDidNotChange(for: WebDAVCredential(baseURL: baseURL, username: username, password: password, allowedCertificate: nil, identifier: UUID().uuidString), originalCredential: credential)
		XCTAssertNoThrow(try manager.removeCredentialFromKeychain(with: identifier))
	}

	func testRemoveCredentialFromKeychain() {
		let baseURL = URL(string: "www.testurl.com")!
		let username = "user"
		let password = "pass"
		let certificate = "CertificateData".data(using: .utf8)
		let identifier = UUID().uuidString
		let credential = WebDAVCredential(baseURL: baseURL, username: username, password: password, allowedCertificate: certificate, identifier: identifier)
		XCTAssertNoThrow(try manager.saveCredentialToKeychain(credential))

		XCTAssertNoThrow(try manager.removeCredentialFromKeychain(with: identifier))
		XCTAssertNil(manager.getCredentialFromKeychain(with: identifier))
	}

	func testSaveUpdatesOverwritesCredentialInKeychain() {
		let baseURL = URL(string: "www.testurl.com")!
		let username = "user"
		let password = "pass"
		let certificate = "CertificateData".data(using: .utf8)
		let identifier = UUID().uuidString
		let credential = WebDAVCredential(baseURL: baseURL, username: username, password: password, allowedCertificate: certificate, identifier: identifier)
		XCTAssertNoThrow(try manager.saveCredentialToKeychain(credential))

		let updatedBaseURL = URL(string: "www.updated-testurl.com")!
		let updatedUsername = "updatedUser"
		let updatedPassword = "updatedPass"
		let updatedCredential = WebDAVCredential(baseURL: updatedBaseURL, username: updatedUsername, password: updatedPassword, allowedCertificate: nil, identifier: identifier)
		XCTAssertNoThrow(try manager.saveCredentialToKeychain(updatedCredential))

		guard let fetchedCredential = manager.getCredentialFromKeychain(with: identifier) else {
			XCTFail("No Credential found in Keychain for identifier: \(identifier)")
			return
		}
		XCTAssertEqual(updatedBaseURL, fetchedCredential.baseURL)
		XCTAssertEqual(updatedUsername, fetchedCredential.username)
		XCTAssertEqual(updatedPassword, fetchedCredential.password)
		XCTAssertNil(fetchedCredential.allowedCertificate)

		XCTAssertNoThrow(try manager.removeCredentialFromKeychain(with: identifier))
	}

	func testMultipleCredentialSupport() {
		let baseURL = URL(string: "www.testurl.com")!
		let firstUsername = "user"
		let firstPassword = "pass"
		let certificate = "CertificateData".data(using: .utf8)
		let firstIdentifier = UUID().uuidString
		let firstCredential = WebDAVCredential(baseURL: baseURL, username: firstUsername, password: firstPassword, allowedCertificate: certificate, identifier: firstIdentifier)

		XCTAssertNoThrow(try manager.saveCredentialToKeychain(firstCredential))

		let secondUsername = "user-2"
		let secondPassword = "pass-2"
		let secondIdentifier = UUID().uuidString
		let secondCredential = WebDAVCredential(baseURL: baseURL, username: secondUsername, password: secondPassword, allowedCertificate: nil, identifier: secondIdentifier)

		XCTAssertNoThrow(try manager.saveCredentialToKeychain(secondCredential))

		guard let fetchedCredentialForFirstAccount = manager.getCredentialFromKeychain(with: firstIdentifier) else {
			XCTFail("No Credential found in Keychain for identifier: \(firstIdentifier)")
			return
		}
		XCTAssertEqual(baseURL, fetchedCredentialForFirstAccount.baseURL)
		XCTAssertEqual(firstUsername, fetchedCredentialForFirstAccount.username)
		XCTAssertEqual(firstPassword, fetchedCredentialForFirstAccount.password)
		XCTAssertEqual(certificate, fetchedCredentialForFirstAccount.allowedCertificate)

		guard let fetchedCredentialForSecondAccount = manager.getCredentialFromKeychain(with: secondIdentifier) else {
			XCTFail("No Credential found in Keychain for identifier: \(secondIdentifier)")
			return
		}
		XCTAssertEqual(baseURL, fetchedCredentialForSecondAccount.baseURL)
		XCTAssertEqual(secondUsername, fetchedCredentialForSecondAccount.username)
		XCTAssertEqual(secondPassword, fetchedCredentialForSecondAccount.password)
		XCTAssertNil(fetchedCredentialForSecondAccount.allowedCertificate)

		XCTAssertNoThrow(try manager.removeCredentialFromKeychain(with: firstIdentifier))
		XCTAssertNoThrow(try manager.removeCredentialFromKeychain(with: secondIdentifier))
	}

	func testRemoveUnusedCredentialsFromKeychain() throws {
		let baseURL = URL(string: "www.testurl.com")!
		let firstUsername = "user"
		let firstPassword = "pass"
		let certificate = "CertificateData".data(using: .utf8)
		let firstIdentifier = UUID().uuidString
		let firstCredential = WebDAVCredential(baseURL: baseURL, username: firstUsername, password: firstPassword, allowedCertificate: certificate, identifier: firstIdentifier)
		try manager.saveCredentialToKeychain(firstCredential)

		let secondUsername = "user-2"
		let secondPassword = "pass-2"
		let secondIdentifier = UUID().uuidString
		let secondCredential = WebDAVCredential(baseURL: baseURL, username: secondUsername, password: secondPassword, allowedCertificate: nil, identifier: secondIdentifier)
		try manager.saveCredentialToKeychain(secondCredential)

		try manager.removeUnusedWebDAVCredentials(existingAccountUIDs: [firstIdentifier])

		let allWebDAVCredentials = try keychain.getAllWebDAVCredentials()

		XCTAssertEqual(1, allWebDAVCredentials.count)
		XCTAssertEqual(firstCredential, allWebDAVCredentials[0])
		try manager.removeCredentialFromKeychain(with: firstIdentifier)
	}

	private func checkSaveThrowsDuplicateError(for credential: WebDAVCredential, originalIdentifier: String) {
		XCTAssertThrowsError(try manager.saveCredentialToKeychain(credential)) { error in
			guard case let WebDAVAuthenticatorKeychainError.credentialDuplicate(identifier) = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
			XCTAssertEqual(originalIdentifier, identifier)
		}
	}

	private func checkSaveThrowsDuplicateErrorAndKeychainDidNotChange(for credential: WebDAVCredential, originalCredential: WebDAVCredential) {
		checkSaveThrowsDuplicateError(for: credential, originalIdentifier: originalCredential.identifier)
		XCTAssertNil(manager.getCredentialFromKeychain(with: credential.identifier))
	}
}
