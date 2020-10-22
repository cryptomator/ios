//
//  WebDAVAuthenticator+KeychainTests.swift
//	CloudAccessPrivateCore
//
//  Created by Philipp Schmid on 21.10.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import Foundation
import XCTest
@testable import CloudAccessPrivateCore
class WebDAVAuthenticator_KeychainTests: XCTestCase {
	func skip_testSaveCredentialToKeychain() {
		let baseURL = URL(string: "www.testurl.com")!
		let username = "user"
		let password = "pass"
		let certificate = "CertificateData".data(using: .utf8)
		let credential = WebDAVCredential(baseURL: baseURL, username: username, password: password, allowedCertificate: certificate)
		let accountUID = UUID().uuidString
		let sucessfulSaving = WebDAVAuthenticator.saveCredentialToKeychain(credential, with: accountUID)
		XCTAssertTrue(sucessfulSaving)
	}
}
