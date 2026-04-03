//
//  FileProviderAdapterMoveItemTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 07.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Foundation
import Promises
import XCTest
@testable import CryptomatorFileProvider

class FileProviderAdapterMoveItemTests: FileProviderAdapterTestCase {
	func testMoveItemLocally() throws {
		let rootItemMetadata = ItemMetadata(id: NSFileProviderItemIdentifier.rootContainerDatabaseValue, name: "Home", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/"), isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(rootItemMetadata)

		let parentItemID: Int64 = 2
		let itemID: Int64 = 3

		let sourceCloudPath = CloudPath("/Test.txt")
		let targetCloudPath = CloudPath("/Folder/RenamedTest.txt")
		let itemMetadata = ItemMetadata(id: itemID, name: "Test.txt", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: sourceCloudPath, isPlaceholderItem: false)
		let targetParentCloudPath = CloudPath("/Folder/")
		let newParentItemMetadata = ItemMetadata(id: parentItemID, name: "Folder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: targetParentCloudPath, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata([itemMetadata, newParentItemMetadata])

		let itemIdentifier = NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: itemID)
		let parentItemIdentifier = NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: parentItemID)
		let newName = "RenamedTest.txt"
		let result = try adapter.moveItemLocally(withIdentifier: itemIdentifier, toParentItemWithIdentifier: parentItemIdentifier, newName: newName)
		let item = result.item
		XCTAssertEqual(newName, item.filename)
		XCTAssertEqual(parentItemIdentifier, item.parentItemIdentifier)
		XCTAssertEqual(itemIdentifier, item.itemIdentifier)
		XCTAssertEqual(ItemStatus.isUploading, item.metadata.statusCode)
		XCTAssertEqual(targetCloudPath, item.metadata.cloudPath)

		XCTAssertEqual(3, metadataManagerMock.cachedMetadata.count)
		XCTAssertEqual(itemMetadata, metadataManagerMock.cachedMetadata[itemID])

		XCTAssertEqual(newName, itemMetadata.name)
		XCTAssertEqual(newParentItemMetadata.id, itemMetadata.parentID)
		XCTAssertEqual(ItemStatus.isUploading, itemMetadata.statusCode)
		XCTAssertEqual(targetCloudPath, itemMetadata.cloudPath)

		let reparentTaskRecord = result.reparentTaskRecord
		XCTAssertEqual(itemID, reparentTaskRecord.correspondingItem)
		XCTAssertEqual(NSFileProviderItemIdentifier.rootContainerDatabaseValue, reparentTaskRecord.oldParentID)
		XCTAssertEqual(parentItemID, reparentTaskRecord.newParentID)
		XCTAssertEqual(sourceCloudPath, reparentTaskRecord.sourceCloudPath)
		XCTAssertEqual(targetCloudPath, reparentTaskRecord.targetCloudPath)
	}

	func testMoveItemLocallyOnlyNameChanged() throws {
		let rootItemMetadata = ItemMetadata(id: NSFileProviderItemIdentifier.rootContainerDatabaseValue, name: "Home", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/"), isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(rootItemMetadata)

		let sourceCloudPath = CloudPath("/Test.txt")
		let targetCloudPath = CloudPath("/RenamedTest.txt")
		let itemID: Int64 = 2
		let itemMetadata = ItemMetadata(id: itemID, name: "Test.txt", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: sourceCloudPath, isPlaceholderItem: false)
		metadataManagerMock.cachedMetadata[itemID] = itemMetadata
		let itemIdentifier = try NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: XCTUnwrap(itemMetadata.id))
		let newName = "RenamedTest.txt"
		let result = try adapter.moveItemLocally(withIdentifier: itemIdentifier, toParentItemWithIdentifier: nil, newName: newName)
		let item = result.item
		XCTAssertEqual(newName, item.filename)
		XCTAssertEqual(NSFileProviderItemIdentifier.rootContainer, item.parentItemIdentifier)
		XCTAssertEqual(itemIdentifier, item.itemIdentifier)
		XCTAssertEqual(ItemStatus.isUploading, item.metadata.statusCode)
		XCTAssertEqual(targetCloudPath, item.metadata.cloudPath)

		XCTAssertEqual(2, metadataManagerMock.cachedMetadata.count)
		XCTAssertEqual(itemMetadata, metadataManagerMock.cachedMetadata[itemID])

		XCTAssertEqual(newName, itemMetadata.name)
		XCTAssertEqual(NSFileProviderItemIdentifier.rootContainerDatabaseValue, itemMetadata.parentID)
		XCTAssertEqual(ItemStatus.isUploading, itemMetadata.statusCode)
		XCTAssertEqual(targetCloudPath, itemMetadata.cloudPath)

		let reparentTaskRecord = result.reparentTaskRecord
		XCTAssertEqual(itemID, reparentTaskRecord.correspondingItem)
		XCTAssertEqual(sourceCloudPath, reparentTaskRecord.sourceCloudPath)
		XCTAssertEqual(targetCloudPath, reparentTaskRecord.targetCloudPath)
	}

	func testMoveItemLocallyOnlyParentChanged() throws {
		let rootItemMetadata = ItemMetadata(id: NSFileProviderItemIdentifier.rootContainerDatabaseValue, name: "Home", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/"), isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(rootItemMetadata)

		let parentItemID: Int64 = 2
		let itemID: Int64 = 3

		let sourceCloudPath = CloudPath("/Test.txt")
		let targetCloudPath = CloudPath("/Folder/Test.txt")
		let itemMetadata = ItemMetadata(id: itemID, name: "Test.txt", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: sourceCloudPath, isPlaceholderItem: false)
		let targetParentCloudPath = CloudPath("/Folder/")
		let newParentItemMetadata = ItemMetadata(id: parentItemID, name: "Folder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: targetParentCloudPath, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata([itemMetadata, newParentItemMetadata])

		let itemIdentifier = NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: itemID)
		let parentItemIdentifier = NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: parentItemID)
		let result = try adapter.moveItemLocally(withIdentifier: itemIdentifier, toParentItemWithIdentifier: parentItemIdentifier, newName: nil)
		let item = result.item
		XCTAssertEqual("Test.txt", item.filename)
		XCTAssertEqual(parentItemIdentifier, item.parentItemIdentifier)
		XCTAssertEqual(itemIdentifier, item.itemIdentifier)
		XCTAssertEqual(ItemStatus.isUploading, item.metadata.statusCode)
		XCTAssertEqual(targetCloudPath, item.metadata.cloudPath)

		XCTAssertEqual(3, metadataManagerMock.cachedMetadata.count)
		XCTAssertEqual(itemMetadata, metadataManagerMock.cachedMetadata[itemID])

		XCTAssertEqual("Test.txt", itemMetadata.name)
		XCTAssertEqual(parentItemID, itemMetadata.parentID)
		XCTAssertEqual(ItemStatus.isUploading, itemMetadata.statusCode)
		XCTAssertEqual(targetCloudPath, itemMetadata.cloudPath)
		let reparentTaskRecord = result.reparentTaskRecord

		XCTAssertEqual(itemID, reparentTaskRecord.correspondingItem)
		XCTAssertEqual(NSFileProviderItemIdentifier.rootContainerDatabaseValue, reparentTaskRecord.oldParentID)
		XCTAssertEqual(parentItemID, reparentTaskRecord.newParentID)
		XCTAssertEqual(sourceCloudPath, reparentTaskRecord.sourceCloudPath)
		XCTAssertEqual(targetCloudPath, reparentTaskRecord.targetCloudPath)
	}

	func testMoveFolderLocallyUpdatesDescendantCloudPaths() throws {
		let rootItemMetadata = ItemMetadata(id: NSFileProviderItemIdentifier.rootContainerDatabaseValue, name: "Home", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/"), isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(rootItemMetadata)

		let sourceParentID: Int64 = 2
		let movedFolderID: Int64 = 3
		let childFileID: Int64 = 4
		let targetParentID: Int64 = 5

		// Initial tree:
		// /
		// |- A/
		// |  |- B/
		// |     |- C.txt
		// |- Target/
		let sourceParent = ItemMetadata(id: sourceParentID, name: "A", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/A/"), isPlaceholderItem: false)
		let movedFolder = ItemMetadata(id: movedFolderID, name: "B", type: .folder, size: nil, parentID: sourceParentID, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/A/B/"), isPlaceholderItem: false)
		let childFile = ItemMetadata(id: childFileID, name: "C.txt", type: .file, size: 100, parentID: movedFolderID, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/A/B/C.txt"), isPlaceholderItem: false)
		let targetParent = ItemMetadata(id: targetParentID, name: "Target", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/Target/"), isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata([sourceParent, movedFolder, childFile, targetParent])

		let movedFolderIdentifier = NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: movedFolderID)
		let targetParentIdentifier = NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: targetParentID)

		// Move B from /A/B/ to /Target/B/.
		// The important part is that descendants must follow that move as well in the database.
		_ = try adapter.moveItemLocally(withIdentifier: movedFolderIdentifier, toParentItemWithIdentifier: targetParentIdentifier, newName: nil)

		// Sanity check for the folder row itself.
		XCTAssertEqual(CloudPath("/Target/B/"), movedFolder.cloudPath)
		XCTAssertEqual(targetParentID, movedFolder.parentID)

		// Regression check:
		// If cloudPath is effectively hardcoded per row and only the moved folder row is updated,
		// the child would incorrectly stay at /A/B/C.txt even though its parent is now /Target/B/.
		// We expect the descendant path prefix to be rewritten to keep parentID and cloudPath in sync.
		// Otherwise path-based metadata lookups, subtree queries, enumeration, deletion bookkeeping,
		// and follow-up remote operations can use the stale location.
		// This does not directly corrupt the local cached-file table because that is keyed by item id/local URL.
		let updatedChild = try XCTUnwrap(metadataManagerMock.getCachedMetadata(for: childFileID))
		XCTAssertEqual(CloudPath("/Target/B/C.txt"), updatedChild.cloudPath)
		XCTAssertEqual(movedFolderID, updatedChild.parentID)
		XCTAssertNil(try metadataManagerMock.getCachedMetadata(for: CloudPath("/A/B/C.txt")))
	}

	func testRenameItem() throws {
		let expectation = XCTestExpectation()

		let rootItemMetadata = ItemMetadata(id: NSFileProviderItemIdentifier.rootContainerDatabaseValue, name: "Home", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/"), isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(rootItemMetadata)

		let sourceCloudPath = CloudPath("/Test.txt")
		let targetCloudPath = CloudPath("/RenamedTest.txt")
		let itemID: Int64 = 2
		let itemMetadata = ItemMetadata(id: itemID, name: "Test.txt", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: sourceCloudPath, isPlaceholderItem: false)
		metadataManagerMock.cachedMetadata[itemID] = itemMetadata
		let newName = "RenamedTest.txt"
		let itemIdentifier = NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: itemID)
		adapter.renameItem(withIdentifier: itemIdentifier, toName: newName) { item, error in
			XCTAssertNil(error)
			guard let fileProviderItem = item as? FileProviderItem else {
				XCTFail("FileProviderItem is nil")
				return
			}

			XCTAssertEqual(newName, fileProviderItem.filename)
			XCTAssertEqual(NSFileProviderItemIdentifier.rootContainer, fileProviderItem.parentItemIdentifier)
			XCTAssertEqual(itemIdentifier, fileProviderItem.itemIdentifier)
			XCTAssertEqual(ItemStatus.isUploading, fileProviderItem.metadata.statusCode)
			XCTAssertEqual(targetCloudPath, fileProviderItem.metadata.cloudPath)

			XCTAssertEqual(2, self.metadataManagerMock.cachedMetadata.count)
			XCTAssertEqual(itemMetadata, self.metadataManagerMock.cachedMetadata[itemID])

			XCTAssertEqual(newName, itemMetadata.name)
			XCTAssertEqual(NSFileProviderItemIdentifier.rootContainerDatabaseValue, itemMetadata.parentID)
			XCTAssertEqual(ItemStatus.isUploading, itemMetadata.statusCode)
			XCTAssertEqual(targetCloudPath, itemMetadata.cloudPath)

			guard let reparentTaskRecord = self.reparentTaskManagerMock.reparentTasks[itemID] else {
				XCTFail("reparentTaskRecord is nil")
				return
			}
			XCTAssertEqual(itemID, reparentTaskRecord.correspondingItem)
			XCTAssertEqual(sourceCloudPath, reparentTaskRecord.sourceCloudPath)
			XCTAssertEqual(targetCloudPath, reparentTaskRecord.targetCloudPath)
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 5.0)
	}

	func testReparentItem() throws {
		let expectation = XCTestExpectation()

		let rootItemMetadata = ItemMetadata(id: NSFileProviderItemIdentifier.rootContainerDatabaseValue, name: "Home", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/"), isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(rootItemMetadata)

		let parentItemID: Int64 = 2
		let itemID: Int64 = 3

		let sourceCloudPath = CloudPath("/Test.txt")
		let targetCloudPath = CloudPath("/Folder/Test.txt")
		let itemMetadata = ItemMetadata(id: itemID, name: "Test.txt", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: sourceCloudPath, isPlaceholderItem: false)
		let targetParentCloudPath = CloudPath("/Folder/")
		let newParentItemMetadata = ItemMetadata(id: parentItemID, name: "Folder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: targetParentCloudPath, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata([itemMetadata, newParentItemMetadata])

		let itemIdentifier = NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: itemID)
		let parentItemIdentifier = NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: parentItemID)
		adapter.reparentItem(withIdentifier: itemIdentifier, toParentItemWithIdentifier: parentItemIdentifier, newName: nil) { item, error in
			XCTAssertNil(error)
			guard let fileProviderItem = item as? FileProviderItem else {
				XCTFail("FileProviderItem is nil")
				return
			}
			XCTAssertEqual("Test.txt", fileProviderItem.filename)
			XCTAssertEqual(parentItemIdentifier, fileProviderItem.parentItemIdentifier)
			XCTAssertEqual(itemIdentifier, fileProviderItem.itemIdentifier)
			XCTAssertEqual(ItemStatus.isUploading, fileProviderItem.metadata.statusCode)
			XCTAssertEqual(targetCloudPath, fileProviderItem.metadata.cloudPath)

			XCTAssertEqual(3, self.metadataManagerMock.cachedMetadata.count)
			XCTAssertEqual(itemMetadata, self.metadataManagerMock.cachedMetadata[itemID])

			XCTAssertEqual("Test.txt", itemMetadata.name)
			XCTAssertEqual(parentItemID, itemMetadata.parentID)
			XCTAssertEqual(ItemStatus.isUploading, itemMetadata.statusCode)
			XCTAssertEqual(targetCloudPath, itemMetadata.cloudPath)

			guard let reparentTaskRecord = self.reparentTaskManagerMock.reparentTasks[itemID] else {
				XCTFail("reparentTaskRecord is nil")
				return
			}
			XCTAssertEqual(itemID, reparentTaskRecord.correspondingItem)
			XCTAssertEqual(NSFileProviderItemIdentifier.rootContainerDatabaseValue, reparentTaskRecord.oldParentID)
			XCTAssertEqual(parentItemID, reparentTaskRecord.newParentID)
			XCTAssertEqual(sourceCloudPath, reparentTaskRecord.sourceCloudPath)
			XCTAssertEqual(targetCloudPath, reparentTaskRecord.targetCloudPath)
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 5.0)
	}

	func testValidateItemName() throws {
		try adapter.validateItemName("Foo.pages")
		try adapter.validateItemName("Foo..pages")
		try adapter.validateItemName("Foo Bar.pages")
		try adapter.validateItemName("Foo")
		try adapter.validateItemName(".foo")
		try assertThrowsInvalidNameCocoaError(adapter.validateItemName("Foo."), localizedDescription: ItemNameValidatorError.nameEndsWithPeriod.localizedDescription)
		try assertThrowsInvalidNameCocoaError(adapter.validateItemName("Foo "), localizedDescription: ItemNameValidatorError.nameEndsWithSpace.localizedDescription)
		try assertThrowsInvalidNameCocoaError(adapter.validateItemName("Fo\\o"), localizedDescription: ItemNameValidatorError.nameContainsIllegalCharacter("\\").localizedDescription)
		try assertThrowsInvalidNameCocoaError(adapter.validateItemName("Fo/o"), localizedDescription: ItemNameValidatorError.nameContainsIllegalCharacter("/").localizedDescription)
		try assertThrowsInvalidNameCocoaError(adapter.validateItemName("Fo:o"), localizedDescription: ItemNameValidatorError.nameContainsIllegalCharacter(":").localizedDescription)
		try assertThrowsInvalidNameCocoaError(adapter.validateItemName("Fo*o"), localizedDescription: ItemNameValidatorError.nameContainsIllegalCharacter("*").localizedDescription)
		try assertThrowsInvalidNameCocoaError(adapter.validateItemName("Fo?o"), localizedDescription: ItemNameValidatorError.nameContainsIllegalCharacter("?").localizedDescription)
		try assertThrowsInvalidNameCocoaError(adapter.validateItemName("Fo\"o"), localizedDescription: ItemNameValidatorError.nameContainsIllegalCharacter("\"").localizedDescription)
		try assertThrowsInvalidNameCocoaError(adapter.validateItemName("Fo<o"), localizedDescription: ItemNameValidatorError.nameContainsIllegalCharacter("<").localizedDescription)
		try assertThrowsInvalidNameCocoaError(adapter.validateItemName("Fo>o"), localizedDescription: ItemNameValidatorError.nameContainsIllegalCharacter(">").localizedDescription)
		try assertThrowsInvalidNameCocoaError(adapter.validateItemName("Fo|o"), localizedDescription: ItemNameValidatorError.nameContainsIllegalCharacter("|").localizedDescription)
	}

	private func assertThrowsInvalidNameCocoaError(_ expression: @autoclosure () throws -> Void, localizedDescription: String) {
		let expectedError = CocoaError(.fileWriteInvalidFileName, userInfo: [
			NSLocalizedDescriptionKey: localizedDescription,
			NSLocalizedFailureReasonErrorKey: ""
		])
		XCTAssertThrowsError(try expression()) { error in
			XCTAssertEqual(expectedError, error as? CocoaError)
		}
	}
}
