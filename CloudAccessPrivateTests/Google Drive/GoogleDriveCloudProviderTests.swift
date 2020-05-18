//
//  GoogleDriveCloudProviderTests.swift
//  CloudAccessPrivateTests
//
//  Created by Philipp Schmid on 11.05.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

@testable import CloudAccessPrivate
import XCTest
class GoogleDriveCloudProviderTests: XCTestCase {
	var provider: GoogleDriveCloudProvider!
	override func setUpWithError() throws {
		let authentication = GoogleDriveCloudAuthentication()
		provider = GoogleDriveCloudProvider(with: authentication)
	}

	override func tearDownWithError() throws {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
	}

	func testOnlyItemNameChangedWorksWithFolders() throws {
		let oldRemoteURL = URL(fileURLWithPath: "/AAAAAA/BBBBBBB/", isDirectory: true)
		let newRemoteURLOnlyFolderNameChanged = URL(fileURLWithPath: "/AAAAAA/CCCCCCC/", isDirectory: true)
		XCTAssertTrue(provider.onlyItemNameChangedBetween(oldRemoteURL: oldRemoteURL, and: newRemoteURLOnlyFolderNameChanged))

		let newRemoteURLPathChanged = URL(fileURLWithPath: "/DDDDDDD/BBBBBBB/", isDirectory: true)
		XCTAssertFalse(provider.onlyItemNameChangedBetween(oldRemoteURL: oldRemoteURL, and: newRemoteURLPathChanged))

		let newRemoteURLPathAndFolderNameChanged = URL(fileURLWithPath: "/DDDDDDD/CCCCCCC/", isDirectory: true)
		XCTAssertFalse(provider.onlyItemNameChangedBetween(oldRemoteURL: oldRemoteURL, and: newRemoteURLPathAndFolderNameChanged))
	}

	func testOnlyItemNameChangedWorksWithFiles() throws {
		let oldRemoteURL = URL(fileURLWithPath: "/AAAAAA/test.txt", isDirectory: false)
		let newRemoteURLOnlyFileNameChanged = URL(fileURLWithPath: "/AAAAAA/renamedTest.txt", isDirectory: false)
		XCTAssertTrue(provider.onlyItemNameChangedBetween(oldRemoteURL: oldRemoteURL, and: newRemoteURLOnlyFileNameChanged))

		let newRemoteURLPathChanged = URL(fileURLWithPath: "/DDDDDDD/BBBBBBB/test.txt", isDirectory: false)
		XCTAssertFalse(provider.onlyItemNameChangedBetween(oldRemoteURL: oldRemoteURL, and: newRemoteURLPathChanged))

		let newRemoteURLPathAndFileNameChanged = URL(fileURLWithPath: "/DDDDDDD/CCCCCCC/renamedAgainTest.txt", isDirectory: true)
		XCTAssertFalse(provider.onlyItemNameChangedBetween(oldRemoteURL: oldRemoteURL, and: newRemoteURLPathAndFileNameChanged))
	}
}
