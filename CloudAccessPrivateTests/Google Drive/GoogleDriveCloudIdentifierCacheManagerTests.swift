//
//  GoogleDriveCloudIdentifierCacheManagerTests.swift
//  CloudAccessPrivateTests
//
//  Created by Philipp Schmid on 11.05.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Foundation
import XCTest
@testable import CloudAccessPrivate

class GoogleDriveCloudIdentifierCacheManagerTests: XCTestCase {
	var cachedCloudIdentifierManager: GoogleDriveCloudIdentifierCacheManager!
	override func setUpWithError() throws {
		guard let manager = GoogleDriveCloudIdentifierCacheManager() else {
			throw TestError.invalidArgumentError("manager is nil")
		}
		cachedCloudIdentifierManager = manager
	}

	override func tearDownWithError() throws {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
	}

	func testRootIdentifierIsCachedAtStart() throws {
		let rootURL = URL(fileURLWithPath: "/")
		let rootIdentifier = try cachedCloudIdentifierManager.getIdentifier(for: rootURL)
		XCTAssertNotNil(rootIdentifier)
		XCTAssertEqual("root", rootIdentifier)
	}

	func testCacheAndRetrieveIdentifierForFileURL() throws {
		let identifierToStore = "TestABC--1234@^"
		let remoteURL = URL(fileURLWithPath: "/abc/test.txt", isDirectory: false)
		try cachedCloudIdentifierManager.cacheIdentifier(identifierToStore, for: remoteURL)
		let retrievedIdentifier = cachedCloudIdentifierManager.getIdentifier(for: remoteURL)
		XCTAssertNotNil(retrievedIdentifier)
		XCTAssertEqual(identifierToStore, retrievedIdentifier)
	}

	func testCacheAndRetrieveIdentifierForFolderURL() throws {
		let identifierToStore = "TestABC--1234@^"
		let remoteURL = URL(fileURLWithPath: "/abc/test--a-/", isDirectory: true)
		try cachedCloudIdentifierManager.cacheIdentifier(identifierToStore, for: remoteURL)
		let retrievedIdentifier = cachedCloudIdentifierManager.getIdentifier(for: remoteURL)
		XCTAssertNotNil(retrievedIdentifier)
		XCTAssertEqual(identifierToStore, retrievedIdentifier)
	}

	func testUpdateWithDifferentIdentifierForCachedRemoteURL() throws {
		let identifierToStore = "TestABC--1234@^"
		let remoteURL = URL(fileURLWithPath: "/abc/test--a-/")
		try cachedCloudIdentifierManager.cacheIdentifier(identifierToStore, for: remoteURL)
		let newIdentifierToStore = "NewerIdentifer879978123.1-"
		try cachedCloudIdentifierManager.cacheIdentifier(newIdentifierToStore, for: remoteURL)
		let retrievedIdentifier = cachedCloudIdentifierManager.getIdentifier(for: remoteURL)
		XCTAssertNotNil(retrievedIdentifier)
		XCTAssertEqual(newIdentifierToStore, retrievedIdentifier)
	}

	func testUncacheIdentifier() throws {
		let identifierToStore = "TestABC--1234@^"
		let remoteURL = URL(fileURLWithPath: "/abc/test--a-/")
		try cachedCloudIdentifierManager.cacheIdentifier(identifierToStore, for: remoteURL)
		let retrievedIdentifier = cachedCloudIdentifierManager.getIdentifier(for: remoteURL)
		XCTAssertNotNil(retrievedIdentifier)
		let secondRemoteURL = URL(fileURLWithPath: "/test/AAAAAAAAAAAA/test.txt")
		let secondIdentifierToStore = "SecondIdentifer@@^1!!´´$"
		try cachedCloudIdentifierManager.cacheIdentifier(secondIdentifierToStore, for: secondRemoteURL)
		try cachedCloudIdentifierManager.uncacheIdentifier(for: remoteURL)
		XCTAssertNil(cachedCloudIdentifierManager.getIdentifier(for: remoteURL))
		let stillCachedIdentifier = cachedCloudIdentifierManager.getIdentifier(for: secondRemoteURL)
		XCTAssertNotNil(stillCachedIdentifier)
		XCTAssertEqual(secondIdentifierToStore, stillCachedIdentifier)
	}

	func testUncacheCanBeCalledForNonExistentURLsWithoutError() throws {
		let remoteURL = URL(fileURLWithPath: "/abc/test--a-/")
		XCTAssertNil(cachedCloudIdentifierManager.getIdentifier(for: remoteURL))
		try cachedCloudIdentifierManager.uncacheIdentifier(for: remoteURL)
	}

	func testFileURLDoesNotOverwriteFolderURL() throws {
		let folderIdentifier = "TestABC--1234@^"
		let fileIdentifier = "AHVASJSDOKJA---12"
		let remoteFolderURL = URL(fileURLWithPath: "/abc/test--a-/", isDirectory: true)
		let remoteFileURL = URL(fileURLWithPath: "/abc/test--a-", isDirectory: false)
		try cachedCloudIdentifierManager.cacheIdentifier(folderIdentifier, for: remoteFolderURL)
		try cachedCloudIdentifierManager.cacheIdentifier(fileIdentifier, for: remoteFileURL)
		let retrievedIdentifier = cachedCloudIdentifierManager.getIdentifier(for: remoteFolderURL)
		XCTAssertNotNil(retrievedIdentifier)
		XCTAssertEqual(folderIdentifier, retrievedIdentifier)
	}
}
