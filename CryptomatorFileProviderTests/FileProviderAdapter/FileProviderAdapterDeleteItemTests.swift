//
//  FileProviderAdapterDeleteItemTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 08.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import XCTest
@testable import CryptomatorFileProvider

class FileProviderAdapterDeleteItemTests: FileProviderAdapterTestCase {
	func testDeleteItemWithFile() throws {
		let expectation = XCTestExpectation()
		let itemID: Int64 = 2
		let cloudPath = CloudPath("/test.txt")
		let itemMetadata = ItemMetadata(id: itemID, name: "test.txt", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(itemMetadata)
		let adapter = createFullyMockedAdapter()
		let itemIdentifier = NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: itemID)
		adapter.deleteItem(withIdentifier: itemIdentifier) { error in
			XCTAssertNil(error)

			guard let deletionTask = self.deletionTaskManagerMock.deletionTasks[itemID] else {
				XCTFail("deletionTask is nil")
				return
			}
			XCTAssertEqual(cloudPath, deletionTask.cloudPath)
			XCTAssertEqual(itemMetadata.id, deletionTask.correspondingItem)
			XCTAssertEqual(itemMetadata.parentID, deletionTask.parentID)
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testDeleteItemWithFolder() throws {
		let expectation = XCTestExpectation()
		let folderItemID: Int64 = 2
		let fileItemID: Int64 = 3
		let folderCloudPath = CloudPath("/Folder/")
		let folderItemMetadata = ItemMetadata(id: folderItemID, name: "Folder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: folderCloudPath, isPlaceholderItem: false)
		let cloudPath = CloudPath("Folder/test.txt")
		let fileItemMetadata = ItemMetadata(id: fileItemID, name: "test.txt", type: .file, size: nil, parentID: folderItemID, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata([folderItemMetadata, fileItemMetadata])

		let folderItemIdentifier = NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: folderItemID)
		let fileItemIdentifier = NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: fileItemID)
		let localURLForItem = tmpDirectory.appendingPathComponent("/\(fileItemIdentifier)/test.txt")
		try cachedFileManagerMock.cacheLocalFileInfo(for: fileItemID, localURL: localURLForItem, lastModifiedDate: Date(timeIntervalSinceReferenceDate: 0))

		let adapter = createFullyMockedAdapter()
		adapter.deleteItem(withIdentifier: folderItemIdentifier) { error in
			XCTAssertNil(error)

			guard let deletionTask = self.deletionTaskManagerMock.deletionTasks[folderItemID] else {
				XCTFail("deletionTask is nil")
				return
			}
			XCTAssertEqual(folderCloudPath, deletionTask.cloudPath)
			XCTAssertEqual(folderItemMetadata.id, deletionTask.correspondingItem)
			XCTAssertEqual(folderItemMetadata.parentID, deletionTask.parentID)
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testDeleteItemWithLocallyCachedFile() throws {
		let expectation = XCTestExpectation()
		let itemID: Int64 = 2
		let cloudPath = CloudPath("/test.txt")
		let itemMetadata = ItemMetadata(id: itemID, name: "test.txt", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(itemMetadata)
		let adapter = createFullyMockedAdapter()
		let itemIdentifier = NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: itemID)

		let localURLForItem = tmpDirectory.appendingPathComponent("/\(itemIdentifier)/test.txt")
		try cachedFileManagerMock.cacheLocalFileInfo(for: itemID, localURL: localURLForItem, lastModifiedDate: Date(timeIntervalSinceReferenceDate: 0))

		adapter.deleteItem(withIdentifier: itemIdentifier) { error in
			XCTAssertNil(error)

			guard let deletionTask = self.deletionTaskManagerMock.deletionTasks[itemID] else {
				XCTFail("deletionTask is nil")
				return
			}
			XCTAssertEqual(cloudPath, deletionTask.cloudPath)
			XCTAssertEqual(itemMetadata.id, deletionTask.correspondingItem)
			XCTAssertEqual(itemMetadata.parentID, deletionTask.parentID)

			XCTAssertEqual(1, self.cachedFileManagerMock.removeCachedFile.count)
			XCTAssertEqual(itemID, self.cachedFileManagerMock.removeCachedFile[0])
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testDeleteItemWithNonExistentFile() throws {
		let expectation = XCTestExpectation()
		let itemID: Int64 = 2
		let itemIdentifier = NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: itemID)

		let adapter = createFullyMockedAdapter()

		adapter.deleteItem(withIdentifier: itemIdentifier) { error in
			XCTAssertNil(error)
			XCTAssert(self.metadataManagerMock.cachedMetadata.isEmpty, "Unexpected change of cached metadata.")
			XCTAssert(self.metadataManagerMock.updatedMetadata.isEmpty, "Unexpected change of cached metadata.")
			XCTAssert(self.metadataManagerMock.removedMetadataID.isEmpty, "Unexpected change of cached metadata.")

			XCTAssert(self.deletionTaskManagerMock.deletionTasks.isEmpty, "Unexpected creation of a deletion task.")
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}
}
