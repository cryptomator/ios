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
	var rootURLForIntegrationTest: URL!
	override func setUpWithError() throws {}

	// MARK: ensures that the tests of this interface only apply to implementations and not to the interface itself
	
	override class var defaultTestSuite: XCTestSuite {
		XCTestSuite(name: "InterfaceTests Excluded")
	}

	override func tearDownWithError() throws {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
	}

	func testFetchItemMetadataForFile() throws {
		let fileURL = rootURLForIntegrationTest.appendingPathComponent("test.txt", isDirectory: false)
		let expectation = XCTestExpectation(description: "fetchItemMetadataForFile")
		provider.fetchItemMetadata(at: fileURL).then{ metadata in
			XCTAssertEqual("test.txt", metadata.name)
			XCTAssertEqual(fileURL, metadata.remoteURL)
			XCTAssertEqual(CloudItemType.file, metadata.itemType)
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 60.0)
	}
	
	func testFetchItemMetadataForFolder() throws {
		let folderURL = rootURLForIntegrationTest.appendingPathComponent("/testFolder/", isDirectory: true)
		let expectation = XCTestExpectation(description: "fetchItemMetadataForFolder")
		provider.fetchItemMetadata(at: folderURL).then{ metadata in
			XCTAssertEqual("testFolder", metadata.name)
			XCTAssertEqual(folderURL, metadata.remoteURL)
			XCTAssertEqual(CloudItemType.folder, metadata.itemType)
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 60.0)
	}
	
	func testFetchItemFailWithItemNotFoundWhenFileDoesNotExists() throws {
		let expectation = XCTestExpectation(description: "fetchItemMetadataForNonexistentFile")
		let nonexistentFileURL = rootURLForIntegrationTest.appendingPathComponent("thisFileMustNotExist.pdf", isDirectory: false)
		provider.fetchItemMetadata(at: nonexistentFileURL).then{_ in
			XCTFail("Promise should not fulfill for nonexistent File")
		}.catch{ error in
			if case CloudProviderError.itemNotFound = error {
				expectation.fulfill()
			} else {
				XCTFail("Promise rejected but with the wrong error: \(error)")
			}
		}
	}
	
	func testFetchItemFailWithItemNotFoundWhenFolderDoesNotExists() throws {
		let expectation = XCTestExpectation(description: "fetchItemMetadataForNonexistentFolder")
		let nonexistentFolderURL = rootURLForIntegrationTest.appendingPathComponent("/thisFolderMustNotExist/", isDirectory: true)
		provider.fetchItemMetadata(at: nonexistentFolderURL).then{_ in
			XCTFail("Promise should not fulfill for nonexistent File")
		}.catch{ error in
			if case CloudProviderError.itemNotFound = error {
				expectation.fulfill()
			} else {
				XCTFail("Promise rejected but with the wrong error: \(error)")
			}
		}
	}
}
