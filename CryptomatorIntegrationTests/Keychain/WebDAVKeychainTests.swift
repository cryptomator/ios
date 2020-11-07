//
//  WebDAVKeychainTests.swift
//  CryptomatorIntegrationTests
//
//  Created by Philipp Schmid on 22.10.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import XCTest
@testable import CloudAccessPrivateCore

class WebDAVKeychainTests: XCTestCase {
	func testSaveCredentialToKeychain() {
		let baseURL = URL(string: "www.testurl.com")!
		let username = "user"
		let password = "pass"
		let certificate = "CertificateData".data(using: .utf8)
		let credential = WebDAVCredential(baseURL: baseURL, username: username, password: password, allowedCertificate: certificate)
		let accountUID = UUID().uuidString
		XCTAssertNoThrow(try WebDAVAuthenticator.saveCredentialToKeychain(credential, with: accountUID))

		guard let fetchedCredential = WebDAVAuthenticator.getCredentialFromKeychain(with: accountUID) else {
			XCTFail("No Credential found in Keychain for accountUID: \(accountUID)")
			return
		}
		XCTAssertEqual(baseURL, fetchedCredential.baseURL)
		XCTAssertEqual(username, fetchedCredential.username)
		XCTAssertEqual(password, fetchedCredential.password)
		XCTAssertEqual(certificate, fetchedCredential.allowedCertificate)

		XCTAssertNoThrow(try WebDAVAuthenticator.removeCredentialFromKeychain(with: accountUID))
	}

	func testRemoveCredentialFromKeychain() {
		let baseURL = URL(string: "www.testurl.com")!
		let username = "user"
		let password = "pass"
		let certificate = "CertificateData".data(using: .utf8)
		let credential = WebDAVCredential(baseURL: baseURL, username: username, password: password, allowedCertificate: certificate)
		let accountUID = UUID().uuidString
		XCTAssertNoThrow(try WebDAVAuthenticator.saveCredentialToKeychain(credential, with: accountUID))

		XCTAssertNoThrow(try WebDAVAuthenticator.removeCredentialFromKeychain(with: accountUID))
		XCTAssertNil(WebDAVAuthenticator.getCredentialFromKeychain(with: accountUID))
	}

	func testSaveUpdatesOverwritesCredentialInKeychain() {
		let baseURL = URL(string: "www.testurl.com")!
		let username = "user"
		let password = "pass"
		let certificate = "CertificateData".data(using: .utf8)
		let credential = WebDAVCredential(baseURL: baseURL, username: username, password: password, allowedCertificate: certificate)
		let accountUID = UUID().uuidString
		XCTAssertNoThrow(try WebDAVAuthenticator.saveCredentialToKeychain(credential, with: accountUID))

		let updatedBaseURL = URL(string: "www.updated-testurl.com")!
		let updatedUsername = "updatedUser"
		let updatedPassword = "updatedPass"
		let updatedCredential = WebDAVCredential(baseURL: updatedBaseURL, username: updatedUsername, password: updatedPassword, allowedCertificate: nil)
		XCTAssertNoThrow(try WebDAVAuthenticator.saveCredentialToKeychain(updatedCredential, with: accountUID))

		guard let fetchedCredential = WebDAVAuthenticator.getCredentialFromKeychain(with: accountUID) else {
			XCTFail("No Credential found in Keychain for accountUID: \(accountUID)")
			return
		}
		XCTAssertEqual(updatedBaseURL, fetchedCredential.baseURL)
		XCTAssertEqual(updatedUsername, fetchedCredential.username)
		XCTAssertEqual(updatedPassword, fetchedCredential.password)
		XCTAssertNil(fetchedCredential.allowedCertificate)

		XCTAssertNoThrow(try WebDAVAuthenticator.removeCredentialFromKeychain(with: accountUID))
	}

	func testMultipleCredentialSupport() {
		let baseURL = URL(string: "www.testurl.com")!
		let firstUsername = "user"
		let firstPassword = "pass"
		let certificate = "CertificateData".data(using: .utf8)
		let firstCredential = WebDAVCredential(baseURL: baseURL, username: firstUsername, password: firstPassword, allowedCertificate: certificate)
		let firstAccountUID = UUID().uuidString
		XCTAssertNoThrow(try WebDAVAuthenticator.saveCredentialToKeychain(firstCredential, with: firstAccountUID))

		let secondUsername = "user-2"
		let secondPassword = "pass-2"
		let secondCredential = WebDAVCredential(baseURL: baseURL, username: secondUsername, password: secondPassword, allowedCertificate: nil)
		let secondAccountUID = UUID().uuidString
		XCTAssertNoThrow(try WebDAVAuthenticator.saveCredentialToKeychain(secondCredential, with: secondAccountUID))

		guard let fetchedCredentialForFirstAccount = WebDAVAuthenticator.getCredentialFromKeychain(with: firstAccountUID) else {
			XCTFail("No Credential found in Keychain for accountUID: \(firstAccountUID)")
			return
		}
		XCTAssertEqual(baseURL, fetchedCredentialForFirstAccount.baseURL)
		XCTAssertEqual(firstUsername, fetchedCredentialForFirstAccount.username)
		XCTAssertEqual(firstPassword, fetchedCredentialForFirstAccount.password)
		XCTAssertEqual(certificate, fetchedCredentialForFirstAccount.allowedCertificate)

		guard let fetchedCredentialForSecondAccount = WebDAVAuthenticator.getCredentialFromKeychain(with: secondAccountUID) else {
			XCTFail("No Credential found in Keychain for accountUID: \(secondAccountUID)")
			return
		}
		XCTAssertEqual(baseURL, fetchedCredentialForSecondAccount.baseURL)
		XCTAssertEqual(secondUsername, fetchedCredentialForSecondAccount.username)
		XCTAssertEqual(secondPassword, fetchedCredentialForSecondAccount.password)
		XCTAssertNil(fetchedCredentialForSecondAccount.allowedCertificate)

		XCTAssertNoThrow(try WebDAVAuthenticator.removeCredentialFromKeychain(with: firstAccountUID))
		XCTAssertNoThrow(try WebDAVAuthenticator.removeCredentialFromKeychain(with: secondAccountUID))
	}
}
