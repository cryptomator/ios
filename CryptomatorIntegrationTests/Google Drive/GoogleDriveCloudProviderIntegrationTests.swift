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
		guard let refreshToken = ProcessInfo.processInfo.environment["GOOGLE_DRIVE_REFRESH_TOKEN"] else {
			throw IntegrationTestError.environmentVariableNotSet
		}
		let auth = MockGoogleDriveCloudAuthentication(withRefreshToken: refreshToken)
		super.authentication = auth
		super.provider = GoogleDriveCloudProvider(with: auth)
		super.rootURLForIntegrationTest = URL(fileURLWithPath: "/iOS-IntegrationTests/plain/", isDirectory: true)
	}

	override func tearDownWithError() throws {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
	}

	override class var defaultTestSuite: XCTestSuite {
		return XCTestSuite(forTestCaseClass: GoogleDriveCloudProviderIntegrationTests.self)
	}

	/**
	    It is necessary to call another function than canAuthorize, because it returns true as soon as any refreshToken is set and does not check it online for correctness before.
	 */

	// MARK: Move test to other File

	/*
	 func testAuthenticationWorksWithoutViewController() throws {
	 	let expectation = XCTestExpectation(description: "Google Authentication works without ViewController")
	 	authentication.authenticate().then {
	 		authentication.authorization?.authorizeRequest(nil, completionHandler: { error in
	 			XCTAssertNil(error)
	 			expectation.fulfill()
	 })
	 	}.catch { error in
	 		XCTFail(error.localizedDescription)
	 	}
	 	wait(for: [expectation], timeout: 10.0)
	 }*/
}
