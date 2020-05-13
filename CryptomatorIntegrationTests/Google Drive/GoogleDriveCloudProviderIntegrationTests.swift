//
//  GoogleDriveCloudProviderIntegrationTests.swift
//  CryptomatorIntegrationTests
//
//  Created by Philipp Schmid on 29.04.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CloudAccessPrivate
import CryptomatorCloudAccess
import Promises
import XCTest
class GoogleDriveCloudProviderIntegrationTests: CryptomatorIntegrationTestInterface {
	override func setUpWithError() throws {
		let auth = MockGoogleDriveCloudAuthentication()
		super.authentication = auth
		super.provider = GoogleDriveCloudProvider(with: auth)
	}

	override func tearDownWithError() throws {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
	}

	override class var defaultTestSuite: XCTestSuite {
		XCTestSuite(forTestCaseClass: GoogleDriveCloudProviderIntegrationTests.self)
	}

	/**
	    It is necessary to call another function than canAuthorize, because it returns true as soon as any refreshToken is set and does not check it online for correctness before.
	 */

	// MARK: Move test to other File

	func testAuthenticationWorksWithoutViewController() throws {
		let authentication = MockGoogleDriveCloudAuthentication()
		let refreshToken = "ADD THE REFRESH TOKEN VIA ENV VARIABLE"
		let expectation = XCTestExpectation(description: "Google Authentication works without ViewController")
		authentication.authenticate(withRefreshToken: refreshToken as NSString).then {
			authentication.authorization?.authorizeRequest(nil, completionHandler: { error in
				XCTAssertNil(error)
				expectation.fulfill()
            })
		}.catch { error in
			XCTFail(error.localizedDescription)
		}
		wait(for: [expectation], timeout: 10.0)
	}
}
