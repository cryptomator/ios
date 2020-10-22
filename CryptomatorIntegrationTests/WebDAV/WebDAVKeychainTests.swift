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
		let sucessfulSaving = WebDAVAuthenticator.saveCredentialToKeychain(credential, with: accountUID)
		XCTAssertTrue(sucessfulSaving)

		guard let fetchedCredential = WebDAVAuthenticator.getCredentialFromKeychain(with: accountUID) else {
			XCTFail("No Credential found in Keychain for accountUID: \(accountUID)")
			return
		}
		XCTAssertEqual(baseURL, fetchedCredential.baseURL)
		XCTAssertEqual(username, fetchedCredential.username)
		XCTAssertEqual(password, fetchedCredential.password)
		XCTAssertEqual(certificate, fetchedCredential.allowedCertificate)

		_ = WebDAVAuthenticator.removeCredentialFromKeychain(with: accountUID)
	}

	func testRemoveCredentialFromKeychain() {
		let baseURL = URL(string: "www.testurl.com")!
		let username = "user"
		let password = "pass"
		let certificate = "CertificateData".data(using: .utf8)
		let credential = WebDAVCredential(baseURL: baseURL, username: username, password: password, allowedCertificate: certificate)
		let accountUID = UUID().uuidString
		let sucessfulSaving = WebDAVAuthenticator.saveCredentialToKeychain(credential, with: accountUID)
		XCTAssertTrue(sucessfulSaving)

		let sucessfulDeletion = WebDAVAuthenticator.removeCredentialFromKeychain(with: accountUID)
		XCTAssertTrue(sucessfulDeletion)
		XCTAssertNil(WebDAVAuthenticator.getCredentialFromKeychain(with: accountUID))
	}

	func testSaveUpdatesOverwritesCredentialInKeychain() {
		let baseURL = URL(string: "www.testurl.com")!
		let username = "user"
		let password = "pass"
		let certificate = "CertificateData".data(using: .utf8)
		let credential = WebDAVCredential(baseURL: baseURL, username: username, password: password, allowedCertificate: certificate)
		let accountUID = UUID().uuidString
		let sucessfulSaving = WebDAVAuthenticator.saveCredentialToKeychain(credential, with: accountUID)
		XCTAssertTrue(sucessfulSaving)

		let updatedBaseURL = URL(string: "www.updated-testurl.com")!
		let updatedUsername = "updatedUser"
		let updatedPassword = "updatedPass"
		let updatedCredential = WebDAVCredential(baseURL: updatedBaseURL, username: updatedUsername, password: updatedPassword, allowedCertificate: nil)
		let sucessfulUpdate = WebDAVAuthenticator.saveCredentialToKeychain(updatedCredential, with: accountUID)
		XCTAssertTrue(sucessfulUpdate)

		guard let fetchedCredential = WebDAVAuthenticator.getCredentialFromKeychain(with: accountUID) else {
			XCTFail("No Credential found in Keychain for accountUID: \(accountUID)")
			return
		}
		XCTAssertEqual(updatedBaseURL, fetchedCredential.baseURL)
		XCTAssertEqual(updatedUsername, fetchedCredential.username)
		XCTAssertEqual(updatedPassword, fetchedCredential.password)
		XCTAssertNil(fetchedCredential.allowedCertificate)

		_ = WebDAVAuthenticator.removeCredentialFromKeychain(with: accountUID)
	}

	func testMultipleCredentialSupport() {
		let baseURL = URL(string: "www.testurl.com")!
		let firstUsername = "user"
		let firstPassword = "pass"
		let certificate = "CertificateData".data(using: .utf8)
		let firstCredential = WebDAVCredential(baseURL: baseURL, username: firstUsername, password: firstPassword, allowedCertificate: certificate)
		let firstAccountUID = UUID().uuidString
		let sucessfulSavingOfFirstAccount = WebDAVAuthenticator.saveCredentialToKeychain(firstCredential, with: firstAccountUID)
		XCTAssertTrue(sucessfulSavingOfFirstAccount)

		let secondUsername = "user-2"
		let secondPassword = "pass-2"
		let secondCredential = WebDAVCredential(baseURL: baseURL, username: secondUsername, password: secondPassword, allowedCertificate: nil)
		let secondAccountUID = UUID().uuidString
		let sucessfulSavingOfSecondAccount = WebDAVAuthenticator.saveCredentialToKeychain(secondCredential, with: secondAccountUID)
		XCTAssertTrue(sucessfulSavingOfSecondAccount)

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

		_ = WebDAVAuthenticator.removeCredentialFromKeychain(with: firstAccountUID)
		_ = WebDAVAuthenticator.removeCredentialFromKeychain(with: secondAccountUID)
	}
}
