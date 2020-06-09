//
//  MockDropboxAuthenticationTests.swift
//  CryptomatorIntegrationTests
//
//  Created by Philipp Schmid on 05.06.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CloudAccessPrivate
import XCTest
class MockDropboxAuthenticationTests: XCTestCase {
	override func setUpWithError() throws {
		// Put setup code here. This method is called before the invocation of each test method in the class.
	}

	override func tearDownWithError() throws {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
	}

	func testExample() throws {
		let auth = MockDropboxCloudAuthentication()
		let provider = DropboxCloudProvider(with: auth)
		let expectation = XCTestExpectation()
		let url = URL(fileURLWithPath: "/TestFolder/", isDirectory: true)
		auth.authenticate().then {
			provider.createFolder(at: url)
		}.catch {
			error in
			XCTFail("Promise failed with: \(error)")
		}.always {
			expectation.fulfill()
		}

		wait(for: [expectation], timeout: 5.0)
	}

	func testPerformanceExample() throws {
		// This is an example of a performance test case.
		measure {
			// Put the code you want to measure the time of here.
		}
	}
}
