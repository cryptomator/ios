//
//  GoogleDriveCloudProviderTests.swift
//  CloudAccessPrivateTests
//
//  Created by Philipp Schmid on 11.05.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import XCTest
@testable import CloudAccessPrivate

class GoogleDriveCloudProviderTests: XCTestCase {
	var provider: GoogleDriveCloudProvider!
	override func setUpWithError() throws {
		let authentication = GoogleDriveCloudAuthenticator()
		provider = GoogleDriveCloudProvider(with: authentication)
	}

	override func tearDownWithError() throws {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
	}

	func testOnlyItemNameChangedWorksWithFolders() throws {
		let oldCloudPath = CloudPath("/AAAAAA/BBBBBBB/")
		let newCloudPathOnlyFolderNameChanged = CloudPath("/AAAAAA/CCCCCCC/")
		XCTAssertTrue(provider.onlyItemNameChangedBetween(oldCloudPath, and: newCloudPathOnlyFolderNameChanged))

		let newCloudPathWithParentFolderChanged = CloudPath("/DDDDDDD/BBBBBBB/")
		XCTAssertFalse(provider.onlyItemNameChangedBetween(oldCloudPath, and: newCloudPathWithParentFolderChanged))

		let newCloudPathParentFolderAndFolderNameChanged = CloudPath("/DDDDDDD/CCCCCCC/")
		XCTAssertFalse(provider.onlyItemNameChangedBetween(oldCloudPath, and: newCloudPathParentFolderAndFolderNameChanged))
	}

	func testOnlyItemNameChangedWorksWithFiles() throws {
		let oldCloudPath = CloudPath("/AAAAAA/test.txt")
		let newCloudPathOnlyFileNameChanged = CloudPath("/AAAAAA/renamedTest.txt")
		XCTAssertTrue(provider.onlyItemNameChangedBetween(oldCloudPath, and: newCloudPathOnlyFileNameChanged))

		let newCloudPathWithChangedPath = CloudPath("/DDDDDDD/BBBBBBB/test.txt")
		XCTAssertFalse(provider.onlyItemNameChangedBetween(oldCloudPath, and: newCloudPathWithChangedPath))

		let newCloudPathWithPathAndFileNameChanged = CloudPath("/DDDDDDD/CCCCCCC/renamedAgainTest.txt")
		XCTAssertFalse(provider.onlyItemNameChangedBetween(oldCloudPath, and: newCloudPathWithPathAndFileNameChanged))
	}
}
