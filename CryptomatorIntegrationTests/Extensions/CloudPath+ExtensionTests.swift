//
//  CloudPath+ExtensionTests.swift
//  CryptomatorIntegrationTests
//
//  Created by Philipp Schmid on 15.09.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import XCTest
class CloudPath_ExtensionTests: XCTestCase {
	func testGetSubCloudPaths() throws {
		let testCloudPath = CloudPath("/AAA/BBB/CCC/test.txt")
		let expectedSubCloudPaths = [
			CloudPath("/AAA/"),
			CloudPath("/AAA/BBB/"),
			CloudPath("/AAA/BBB/CCC/")
		]
		let actualSubCloudPaths = testCloudPath.getPartialCloudPaths()
		XCTAssertEqual(expectedSubCloudPaths, actualSubCloudPaths)
	}

	func testGetSubCloudPathsWithRootCloudPath() throws {
		let testCloudPath = CloudPath("/")
		let expectedSubCloudPaths = [CloudPath]()
		let actualSubCloudPaths = testCloudPath.getPartialCloudPaths()
		XCTAssertEqual(expectedSubCloudPaths, actualSubCloudPaths)
	}

	func testGetSubCloudPathsWithFileAtRootCloudPath() throws {
		let testCloudPath = CloudPath("/test.txt")
		let expectedSubCloudPaths = [CloudPath]()
		let actualSubCloudPaths = testCloudPath.getPartialCloudPaths()
		XCTAssertEqual(expectedSubCloudPaths, actualSubCloudPaths)
	}
}
