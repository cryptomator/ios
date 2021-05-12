//
//  URL+NameCollisionExtensionTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 10.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import XCTest
@testable import CryptomatorFileProvider

class URL_NameCollisionExtensionTests: XCTestCase {
	func testForFileWithoutPathExtension() throws {
		let url = URL(fileURLWithPath: "/Test", isDirectory: false)
		let expectedURL = URL(fileURLWithPath: "/Test (ABABA)", isDirectory: false)
		XCTAssertEqual(expectedURL, url.createCollisionURL(conflictResolvingAddition: "ABABA"))
	}

	func testForFileWithPathExtension() throws {
		let url = URL(fileURLWithPath: "/Test.txt", isDirectory: false)
		let expectedURL = URL(fileURLWithPath: "/Test (2lUi1).txt", isDirectory: false)
		XCTAssertEqual(expectedURL, url.createCollisionURL(conflictResolvingAddition: "2lUi1"))
	}

	func testForFileInSubfolder() throws {
		let url = URL(fileURLWithPath: "/SubFolder/Test.txt", isDirectory: false)
		let expectedURL = URL(fileURLWithPath: "/SubFolder/Test (lalal).txt", isDirectory: false)
		XCTAssertEqual(expectedURL, url.createCollisionURL(conflictResolvingAddition: "lalal"))
	}

	func testForFolder() throws {
		let url = URL(fileURLWithPath: "/Test/", isDirectory: true)
		let expectedURL = URL(fileURLWithPath: "/Test (12345)/", isDirectory: true)
		XCTAssertEqual(expectedURL, url.createCollisionURL(conflictResolvingAddition: "12345"))
	}

	func testForFolderInSubFolder() throws {
		let url = URL(fileURLWithPath: "/Sub Folder/Test/", isDirectory: true)
		let expectedURL = URL(fileURLWithPath: "/Sub Folder/Test (AAAAA)/", isDirectory: true)
		XCTAssertEqual(expectedURL, url.createCollisionURL(conflictResolvingAddition: "AAAAA"))
	}
}
