//
//  GoogleDriveCloudIdentifierCacheManagerTests.swift
//  CloudAccessPrivate-CoreTests
//
//  Created by Philipp Schmid on 11.05.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import Foundation
import XCTest
@testable import CloudAccessPrivateCore

class GoogleDriveCloudIdentifierCacheManagerTests: XCTestCase {
	var cachedCloudIdentifierManager: GoogleDriveCloudIdentifierCacheManager!
	override func setUpWithError() throws {
		guard let manager = GoogleDriveCloudIdentifierCacheManager() else {
			throw NSError(domain: "CloudAccessPrivate-CoreTests", code: -1000, userInfo: ["localizedDescription": "could not initialize GoogleDriveCloudIdentifierCacheManager"])
		}
		cachedCloudIdentifierManager = manager
	}

	override func tearDownWithError() throws {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
	}

	func testRootIdentifierIsCachedAtStart() throws {
		let rootCloudPath = CloudPath("/")
		let rootIdentifier = cachedCloudIdentifierManager.getIdentifier(for: rootCloudPath)
		XCTAssertNotNil(rootIdentifier)
		XCTAssertEqual("root", rootIdentifier)
	}

	func testCacheAndRetrieveIdentifierForFileCloudPath() throws {
		let identifierToStore = "TestABC--1234@^"
		let cloudPath = CloudPath("/abc/test.txt")
		try cachedCloudIdentifierManager.cacheIdentifier(identifierToStore, for: cloudPath)
		let retrievedIdentifier = cachedCloudIdentifierManager.getIdentifier(for: cloudPath)
		XCTAssertNotNil(retrievedIdentifier)
		XCTAssertEqual(identifierToStore, retrievedIdentifier)
	}

	func testCacheAndRetrieveIdentifierForFolderCloudPath() throws {
		let identifierToStore = "TestABC--1234@^"
		let cloudPath = CloudPath("/abc/test--a-/")
		try cachedCloudIdentifierManager.cacheIdentifier(identifierToStore, for: cloudPath)
		let retrievedIdentifier = cachedCloudIdentifierManager.getIdentifier(for: cloudPath)
		XCTAssertNotNil(retrievedIdentifier)
		XCTAssertEqual(identifierToStore, retrievedIdentifier)
	}

	func testUpdateWithDifferentIdentifierForCachedCloudPath() throws {
		let identifierToStore = "TestABC--1234@^"
		let cloudPath = CloudPath("/abc/test--a-/")
		try cachedCloudIdentifierManager.cacheIdentifier(identifierToStore, for: cloudPath)
		let newIdentifierToStore = "NewerIdentifer879978123.1-"
		try cachedCloudIdentifierManager.cacheIdentifier(newIdentifierToStore, for: cloudPath)
		let retrievedIdentifier = cachedCloudIdentifierManager.getIdentifier(for: cloudPath)
		XCTAssertNotNil(retrievedIdentifier)
		XCTAssertEqual(newIdentifierToStore, retrievedIdentifier)
	}

	func testUncacheIdentifier() throws {
		let identifierToStore = "TestABC--1234@^"
		let cloudPath = CloudPath("/abc/test--a-/")
		try cachedCloudIdentifierManager.cacheIdentifier(identifierToStore, for: cloudPath)
		let retrievedIdentifier = cachedCloudIdentifierManager.getIdentifier(for: cloudPath)
		XCTAssertNotNil(retrievedIdentifier)
		let secondCloudPath = CloudPath("/test/AAAAAAAAAAAA/test.txt")
		let secondIdentifierToStore = "SecondIdentifer@@^1!!´´$"
		try cachedCloudIdentifierManager.cacheIdentifier(secondIdentifierToStore, for: secondCloudPath)
		try cachedCloudIdentifierManager.uncacheIdentifier(for: cloudPath)
		XCTAssertNil(cachedCloudIdentifierManager.getIdentifier(for: cloudPath))
		let stillCachedIdentifier = cachedCloudIdentifierManager.getIdentifier(for: secondCloudPath)
		XCTAssertNotNil(stillCachedIdentifier)
		XCTAssertEqual(secondIdentifierToStore, stillCachedIdentifier)
	}

	func testUncacheCanBeCalledForNonExistentCloudPathsWithoutError() throws {
		let cloudPath = CloudPath("/abc/test--a-/")
		XCTAssertNil(cachedCloudIdentifierManager.getIdentifier(for: cloudPath))
		try cachedCloudIdentifierManager.uncacheIdentifier(for: cloudPath)
	}
}
