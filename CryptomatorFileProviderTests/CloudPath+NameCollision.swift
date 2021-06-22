//
//  CloudPath+NameCollision.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 18.09.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import XCTest

class CloudPath_NameCollision: XCTestCase {
	func testForFileWithoutPathExtension() throws {
		let cloudPath = CloudPath("/Test")
		let expectedcloudPath = CloudPath("/Test (ABABA)")
		XCTAssertEqual(expectedcloudPath, cloudPath.createCollisionCloudPath(conflictResolvingAddition: "ABABA"))
	}

	func testForFileWithPathExtension() throws {
		let cloudPath = CloudPath("/Test.txt")
		let expectedcloudPath = CloudPath("/Test (2lUi1).txt")
		XCTAssertEqual(expectedcloudPath, cloudPath.createCollisionCloudPath(conflictResolvingAddition: "2lUi1"))
	}

	func testForFileInSubfolder() throws {
		let cloudPath = CloudPath("/SubFolder/Test.txt")
		let expectedcloudPath = CloudPath("/SubFolder/Test (lalal).txt")
		XCTAssertEqual(expectedcloudPath, cloudPath.createCollisionCloudPath(conflictResolvingAddition: "lalal"))
	}

	func testForFolder() throws {
		let cloudPath = CloudPath("/Test/")
		let expectedcloudPath = CloudPath("/Test (12345)/")
		XCTAssertEqual(expectedcloudPath, cloudPath.createCollisionCloudPath(conflictResolvingAddition: "12345"))
	}

	func testForFolderInSubFolder() throws {
		let cloudPath = CloudPath("/Sub Folder/Test/")
		let expectedcloudPath = CloudPath("/Sub Folder/Test (AAAAA)/")
		XCTAssertEqual(expectedcloudPath, cloudPath.createCollisionCloudPath(conflictResolvingAddition: "AAAAA"))
	}
}
