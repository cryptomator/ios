//
//  FileProviderDecoratorCreateFolderTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 15.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import XCTest
@testable import CryptomatorFileProvider
class FileProviderDecoratorCreateFolderTests: FileProviderDecoratorTestCase {
	func testCreatePlaceholderItemForFolder() throws {
		let placeholderItem = try decorator.createPlaceholderItemForFolder(withName: "TestFolder", in: .rootContainer)
		XCTAssertEqual("TestFolder", placeholderItem.filename)
		XCTAssert(placeholderItem.isUploading)
		XCTAssertFalse(placeholderItem.isUploaded)
		XCTAssertEqual("public.folder", placeholderItem.typeIdentifier)
		XCTAssert(placeholderItem.metadata.isPlaceholderItem)
		// TODO: Check remotePath after deleted the Homeroot inside the decorator
	}

	func testCreatePlaceholderItemForFolderFailsIfParentDoesNotExist() throws {
		XCTAssertThrowsError(try decorator.createPlaceholderItemForFolder(withName: "TestFolder", in: NSFileProviderItemIdentifier("2"))) { error in
			guard case FileProviderDecoratorError.parentFolderNotFound = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}
	}

	// TODO: testCreatePlaceholderItemForFolderFailsWithLocalFilenameCollsion

	func testCreateFolder() throws {
		let expectation = XCTestExpectation()
		let placeholderItem = try decorator.createPlaceholderItemForFolder(withName: "TestFolder", in: .rootContainer)
		decorator.createFolderInCloud(for: placeholderItem).then { item in
			XCTAssertEqual(ItemStatus.isUploaded, item.metadata.statusCode)
			XCTAssertFalse(item.metadata.isPlaceholderItem)
			XCTAssertEqual(1, self.mockedProvider.createdFolders.count)
			XCTAssertEqual(item.metadata.remotePath, self.mockedProvider.createdFolders[0])
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	// TODO: testCreateFolderErrorReporting
}
