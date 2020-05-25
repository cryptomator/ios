//
//  URL+ExtensionsTests.swift
//  CloudAccessPrivateTests
//
//  Created by Philipp Schmid on 25.05.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import XCTest

class URL_ExtensionsTests: XCTestCase {
	func testAppendPathComponentsWithFolderURL() throws {
		let testURL = URL(fileURLWithPath: "/", isDirectory: true)
		let urlToAppend = URL(fileURLWithPath: "/AAA/BBB/", isDirectory: true)
		let result = testURL.appendPathComponents(from: urlToAppend)
		let expected = URL(fileURLWithPath: "/AAA/BBB/", isDirectory: true)
		XCTAssert(result.hasDirectoryPath)
		XCTAssertEqual(expected, result)
	}

	func testAppendPathComponentsWithFileURL() throws {
		let testURL = URL(fileURLWithPath: "/", isDirectory: true)
		let urlToAppend = URL(fileURLWithPath: "/AAA/BBB/test.txt", isDirectory: false)
		let result = testURL.appendPathComponents(from: urlToAppend)
		let expected = URL(fileURLWithPath: "/AAA/BBB/test.txt", isDirectory: false)
		XCTAssertFalse(result.hasDirectoryPath)
		XCTAssertEqual(expected, result)
	}

	func testAppendPathComponentsWithStartIndexGreaterOne() throws {
		let testURL = URL(fileURLWithPath: "/", isDirectory: true)
		let urlToAppend = URL(fileURLWithPath: "/AAA/BBB/", isDirectory: true)
		let result = testURL.appendPathComponents(from: urlToAppend, startIndex: 2)
		let expected = URL(fileURLWithPath: "/BBB/", isDirectory: true)
		XCTAssert(result.hasDirectoryPath)
		XCTAssertEqual(expected, result)
	}

	func testAppendPathComponentsWithStartIndexTooHigh() throws {
		let testURL = URL(fileURLWithPath: "/", isDirectory: true)
		let urlToAppend = URL(fileURLWithPath: "/AAA/BBB/", isDirectory: true)
		let result = testURL.appendPathComponents(from: urlToAppend, startIndex: 3)
		let expected = URL(fileURLWithPath: "/", isDirectory: true)
		XCTAssert(result.hasDirectoryPath)
		XCTAssertEqual(expected, result)
	}

	func testGetSubURLs() throws {
		let testURL = URL(fileURLWithPath: "/AAA/BBB/CCC/test.txt", isDirectory: false)
		let expectedSubURLs = [
			URL(fileURLWithPath: "/AAA/", isDirectory: true),
			URL(fileURLWithPath: "/AAA/BBB/", isDirectory: true),
			URL(fileURLWithPath: "/AAA/BBB/CCC/", isDirectory: true)
		]
		let actualSubURLs = testURL.getPartialURLs()
		XCTAssertEqual(expectedSubURLs, actualSubURLs)
	}

	func testGetSubURLWithRootURL() throws {
		let testURL = URL(fileURLWithPath: "/", isDirectory: true)
		let expectedSubURLs = [URL]()
		let actualSubURLs = testURL.getPartialURLs()
		XCTAssertEqual(expectedSubURLs, actualSubURLs)
	}

	func testGetSubURLWithFileAtRootURL() throws {
		let testURL = URL(fileURLWithPath: "/test.txt")
		let expectedSubURLs = [URL]()
		let actualSubURLs = testURL.getPartialURLs()
		XCTAssertEqual(expectedSubURLs, actualSubURLs)
	}
}
