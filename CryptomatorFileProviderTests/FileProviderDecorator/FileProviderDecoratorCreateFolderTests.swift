//
//  FileProviderDecoratorCreateFolderTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 15.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
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
		XCTAssertEqual(CloudPath("/TestFolder"), placeholderItem.metadata.cloudPath)
		XCTAssertNotNil(placeholderItem.metadata.id)
		guard let fetchedMetadata = try decorator.itemMetadataManager.getCachedMetadata(for: placeholderItem.metadata.id!) else {
			XCTFail("No Metadata in DB")
			return
		}
		XCTAssertEqual(placeholderItem.metadata, fetchedMetadata)
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

	func skip_testCreatePlaceholderItemForFolderFailsWithLocalFilenameCollsion() throws {
		let cloudPath = CloudPath("/Test Folder/")
		let itemMetadata = ItemMetadata(name: "Test Folder", type: .folder, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
		try decorator.itemMetadataManager.cacheMetadata(itemMetadata)
		XCTAssertThrowsError(try decorator.createPlaceholderItemForFolder(withName: "Test Folder", in: .rootContainer)) { error in
			print(error)
		}
	}

	func skip_testCreateTwoTimesSameFolder() throws {
		let expectation = XCTestExpectation()
		let placeholderItem = try decorator.createPlaceholderItemForFolder(withName: "Test Folder", in: .rootContainer)
		decorator.createFolderInCloud(for: placeholderItem).then { item in
			XCTAssertEqual(ItemStatus.isUploaded, item.metadata.statusCode)
			XCTAssertFalse(item.metadata.isPlaceholderItem)
			XCTAssertEqual(1, self.mockedProvider.createdFolders.count)
			XCTAssertEqual(item.metadata.cloudPath.path, self.mockedProvider.createdFolders[0])
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
		XCTAssertThrowsError(try decorator.createPlaceholderItemForFolder(withName: "Test Folder", in: .rootContainer)) { error in
			print(error)
		}
	}

	func testCreateFolder() throws {
		let expectation = XCTestExpectation()
		let placeholderItem = try decorator.createPlaceholderItemForFolder(withName: "TestFolder", in: .rootContainer)
		decorator.createFolderInCloud(for: placeholderItem).then { item in
			XCTAssertEqual(ItemStatus.isUploaded, item.metadata.statusCode)
			XCTAssertFalse(item.metadata.isPlaceholderItem)
			XCTAssertEqual(1, self.mockedProvider.createdFolders.count)
			XCTAssertEqual(item.metadata.cloudPath.path, self.mockedProvider.createdFolders[0])
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testCreateFolderWithCloudCollision() throws {
		let expectation = XCTestExpectation()
		let placeholderItem = try decorator.createPlaceholderItemForFolder(withName: "FolderAlreadyExists", in: .rootContainer)
		decorator.createFolderInCloud(for: placeholderItem).then { item in
			XCTAssertEqual(ItemStatus.isUploaded, item.metadata.statusCode)
			XCTAssertFalse(item.metadata.isPlaceholderItem)
			XCTAssertEqual(1, self.mockedProvider.createdFolders.count)
			XCTAssertEqual(item.metadata.cloudPath.path, self.mockedProvider.createdFolders[0])
			XCTAssert(self.mockedProvider.createdFolders.filter { $0.hasPrefix("/FolderAlreadyExists (") && $0.hasSuffix(")") }.count == 1)
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testCreateFolderErrorReporting() throws {
		let expectation = XCTestExpectation()
		let placeholderItem = try decorator.createPlaceholderItemForFolder(withName: "quotaInsufficient", in: .rootContainer)
		decorator.createFolderInCloud(for: placeholderItem).then { item in
			guard let error = item.error as NSError? else {
				XCTFail("Item has no error")
				return
			}
			XCTAssert(NSFileProviderError(.insufficientQuota)._nsError.isEqual(error))
			XCTAssertEqual(ItemStatus.uploadError, item.metadata.statusCode)
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}
}
