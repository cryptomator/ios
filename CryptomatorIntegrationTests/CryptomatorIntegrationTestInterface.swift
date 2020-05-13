//
//  CryptomatorIntegrationTestInterface.swift
//  CryptomatorIntegrationTests
//
//  Created by Philipp Schmid on 29.04.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import XCTest

class CryptomatorIntegrationTestInterface: XCTestCase {
	var authentication: CloudAuthentication!
	var provider: CloudProvider!
	override func setUpWithError() throws {}

	// MARK: ensures that the tests of this interface only apply to implementations and not to the interface itself

	override class var defaultTestSuite: XCTestSuite {
		XCTestSuite(name: "InterfaceTests Excluded")
	}

	override func tearDownWithError() throws {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
	}

	func testFetchItemMetadataForFile() throws {}
}
