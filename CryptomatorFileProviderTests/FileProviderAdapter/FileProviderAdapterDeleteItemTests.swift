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
	func testDeleteItemWithFile() async throws {
		let itemID: Int64 = 2
		let cloudPath = CloudPath("/test.txt")
		let itemMetadata = ItemMetadata(id: itemID, name: "test.txt", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(itemMetadata)
		let adapter = createFullyMockedAdapter()
		let itemIdentifier = NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: itemID)
		try await adapter.deleteItem(withIdentifier: itemIdentifier)

		guard let deletionTask = deletionTaskManagerMock.deletionTasks[itemID] else {
			XCTFail("deletionTask is nil")
			return
		}
		XCTAssertEqual(cloudPath, deletionTask.cloudPath)
		XCTAssertEqual(itemMetadata.id, deletionTask.correspondingItem)
		XCTAssertEqual(itemMetadata.parentID, deletionTask.parentID)
	}

	func testDeleteItemWithFolder() async throws {
		let folderItemID: Int64 = 2
		let fileItemID: Int64 = 3
		let folderCloudPath = CloudPath("/Folder/")
		let folderItemMetadata = ItemMetadata(id: folderItemID, name: "Folder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		let cloudPath = CloudPath("Folder/test.txt")
		let fileItemMetadata = ItemMetadata(id: fileItemID, name: "test.txt", type: .file, size: nil, parentID: folderItemID, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata([folderItemMetadata, fileItemMetadata])

		let folderItemIdentifier = NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: folderItemID)
		let fileItemIdentifier = NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: fileItemID)
		let localURLForItem = tmpDirectory.appendingPathComponent("/\(fileItemIdentifier)/test.txt")
		try cachedFileManagerMock.cacheLocalFileInfo(for: fileItemID, localURL: localURLForItem, lastModifiedDate: Date(timeIntervalSinceReferenceDate: 0))

		let adapter = createFullyMockedAdapter()
		try await adapter.deleteItem(withIdentifier: folderItemIdentifier)

		guard let deletionTask = deletionTaskManagerMock.deletionTasks[folderItemID] else {
			XCTFail("deletionTask is nil")
			return
		}
		XCTAssertEqual(folderCloudPath, deletionTask.cloudPath)
		XCTAssertEqual(folderItemMetadata.id, deletionTask.correspondingItem)
		XCTAssertEqual(folderItemMetadata.parentID, deletionTask.parentID)
	}

	func testDeleteItemWithLocallyCachedFile() async throws {
		let itemID: Int64 = 2
		let cloudPath = CloudPath("/test.txt")
		let itemMetadata = ItemMetadata(id: itemID, name: "test.txt", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(itemMetadata)
		let adapter = createFullyMockedAdapter()
		let itemIdentifier = NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: itemID)

		let localURLForItem = tmpDirectory.appendingPathComponent("/\(itemIdentifier)/test.txt")
		try cachedFileManagerMock.cacheLocalFileInfo(for: itemID, localURL: localURLForItem, lastModifiedDate: Date(timeIntervalSinceReferenceDate: 0))

		try await adapter.deleteItem(withIdentifier: itemIdentifier)

		guard let deletionTask = deletionTaskManagerMock.deletionTasks[itemID] else {
			XCTFail("deletionTask is nil")
			return
		}
		XCTAssertEqual(cloudPath, deletionTask.cloudPath)
		XCTAssertEqual(itemMetadata.id, deletionTask.correspondingItem)
		XCTAssertEqual(itemMetadata.parentID, deletionTask.parentID)

		XCTAssertEqual(1, cachedFileManagerMock.removeCachedFile.count)
		XCTAssertEqual(itemID, cachedFileManagerMock.removeCachedFile[0])
	}

	func testDeleteItemWithNonExistentFile() async throws {
		let itemID: Int64 = 2
		let itemIdentifier = NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: itemID)

		let adapter = createFullyMockedAdapter()

		try await adapter.deleteItem(withIdentifier: itemIdentifier)
		XCTAssert(metadataManagerMock.cachedMetadata.isEmpty, "Unexpected change of cached metadata.")
		XCTAssert(metadataManagerMock.updatedMetadata.isEmpty, "Unexpected change of cached metadata.")
		XCTAssert(metadataManagerMock.removedMetadataID.isEmpty, "Unexpected change of cached metadata.")

		XCTAssert(deletionTaskManagerMock.deletionTasks.isEmpty, "Unexpected creation of a deletion task.")
	}
}
