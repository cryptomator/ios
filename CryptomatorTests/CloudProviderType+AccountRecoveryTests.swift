//
//  CloudProviderType+AccountRecoveryTests.swift
//  CryptomatorTests
//
//  Created by Tobias Hagemann on 01.09.26.
//  Copyright © 2026 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import XCTest
@testable import Cryptomator

class CloudProviderTypeAccountRecoveryTests: XCTestCase {
	func testReauthenticateForProvidersThatKeepTheirAccount() {
		let providers: [CloudProviderType] = [.box, .dropbox, .googleDrive, .microsoftGraph(type: .oneDrive), .microsoftGraph(type: .sharePoint), .pCloud]
		for provider in providers {
			XCTAssertEqual(.reauthenticate, provider.accountRecoveryMode, "Expected \(provider) to support signing in again")
		}
	}

	func testEditExistingForCredentialBasedProviders() {
		let providers: [CloudProviderType] = [.s3(type: .custom), .webDAV(type: .custom)]
		for provider in providers {
			XCTAssertEqual(.editExisting, provider.accountRecoveryMode, "Expected \(provider) to be edited instead")
		}
	}

	func testUnsupportedForLocalFileSystem() {
		XCTAssertEqual(.unsupported, CloudProviderType.localFileSystem(type: .custom).accountRecoveryMode)
		XCTAssertEqual(.unsupported, CloudProviderType.localFileSystem(type: .iCloudDrive).accountRecoveryMode)
	}
}
