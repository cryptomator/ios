//
//  MetadataManagerTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 26.06.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import GRDB
import XCTest
@testable import CryptomatorFileProvider

class MetadataManagerTests: XCTestCase {
	var manager: ItemMetadataDBManager!

	override func setUpWithError() throws {
		let inMemoryDB = try DatabaseQueue()
		try DatabaseHelper.migrate(inMemoryDB)
		manager = ItemMetadataDBManager(database: inMemoryDB)
	}

	func testCacheMetadataForFile() throws {
		let cloudPath = CloudPath("/TestFile")

		let itemMetadata = ItemMetadata(name: "TestFile", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		XCTAssertNil(itemMetadata.id)
		try manager.cacheMetadata(itemMetadata)
		XCTAssertNotNil(itemMetadata.id)
		guard let fetchedMetadata = try manager.getCachedMetadata(for: cloudPath) else {
			XCTFail("ItemMetadata not cached properly")
			return
		}
		XCTAssertEqual(itemMetadata, fetchedMetadata)
		XCTAssertNotNil(fetchedMetadata.id)
	}

	func testCacheMetadataForFolder() throws {
		let cloudPath = CloudPath("/Test Folder/")

		let itemMetadata = ItemMetadata(name: "Test Folder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: true)
		XCTAssertNil(itemMetadata.id)
		try manager.cacheMetadata(itemMetadata)
		guard let fetchedMetadata = try manager.getCachedMetadata(for: cloudPath) else {
			XCTFail("ItemMetadata not cached properly")
			return
		}
		XCTAssertEqual(itemMetadata, fetchedMetadata)
		XCTAssertNotNil(fetchedMetadata.id)
	}

	func testCacheMultipleEntries() throws {
		let fileCloudPath = CloudPath("/TestFile")
		let folderCloudPath = CloudPath("/TestFolder/")
		let itemMetadataForFile = ItemMetadata(name: "TestFile", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		let itemMetadataForFolder = ItemMetadata(name: "TestFolder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: true)
		XCTAssertNil(itemMetadataForFile.id)
		XCTAssertNil(itemMetadataForFolder.id)
		let itemMetadataList = [itemMetadataForFile, itemMetadataForFolder]
		try manager.cacheMetadata(itemMetadataList)
		guard let fetchedMetadataForFile = try manager.getCachedMetadata(for: fileCloudPath) else {
			XCTFail("ItemMetadata not cached properly")
			return
		}
		XCTAssertEqual(itemMetadataForFile, fetchedMetadataForFile)
		XCTAssertNotNil(fetchedMetadataForFile.id)
		guard let fetchedMetadataForFolder = try manager.getCachedMetadata(for: folderCloudPath) else {
			XCTFail("ItemMetadata not cached properly")
			return
		}
		XCTAssertEqual(itemMetadataForFolder, fetchedMetadataForFolder)
		XCTAssertNotNil(fetchedMetadataForFolder.id)
	}

	func testGetPlaceholderItems() throws {
		let fileCloudPath = CloudPath("/Test File.txt")
		let folderCloudPath = CloudPath("/Test Folder/")
		let secondFolderCloudPath = CloudPath("/SecondFolder/")
		let placeholderItemMetadataForFile = ItemMetadata(name: "Test File.txt", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: true)
		let placeholderItemMetadataForFolder = ItemMetadata(name: "Test Folder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: true)
		let itemMetadataForFolder = ItemMetadata(name: "SecondFolder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		XCTAssertNil(placeholderItemMetadataForFile.id)
		XCTAssertNil(placeholderItemMetadataForFolder.id)
		XCTAssertNil(itemMetadataForFolder.id)
		try manager.cacheMetadata([placeholderItemMetadataForFile, placeholderItemMetadataForFolder, itemMetadataForFolder])
		let fetchedPlaceholderItems = try manager.getPlaceholderMetadata(withParentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue)
		XCTAssertEqual(2, fetchedPlaceholderItems.count)
		XCTAssertEqual([placeholderItemMetadataForFile, placeholderItemMetadataForFolder], fetchedPlaceholderItems)
		XCTAssertNotNil(fetchedPlaceholderItems[0].id)
		XCTAssertNotNil(fetchedPlaceholderItems[1].id)
		XCTAssertNotEqual(fetchedPlaceholderItems[0].id, fetchedPlaceholderItems[1].id)
	}

	func testGetPlaceholderItemsIsEmptyForNoPlaceholderItemsUnderParent() throws {
		let fileCloudPath = CloudPath("/Test File.txt")
		let folderCloudPath = CloudPath("/Test Folder/")
		let secondFolderCloudPath = CloudPath("/Test Folder/SecondFolder/")
		let placeholderItemMetadataForFile = ItemMetadata(name: "Test File.txt", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		let placeholderItemMetadataForFolder = ItemMetadata(name: "Test Folder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		XCTAssertNil(placeholderItemMetadataForFile.id)
		XCTAssertNil(placeholderItemMetadataForFolder.id)
		try manager.cacheMetadata([placeholderItemMetadataForFile, placeholderItemMetadataForFolder])
		XCTAssertNotNil(placeholderItemMetadataForFile.id)
		guard let testFolderId = placeholderItemMetadataForFolder.id else {
			XCTFail("Test Folder ID is nil")
			return
		}
		let itemMetadataForFolder = ItemMetadata(name: "SecondFolder", type: .folder, size: nil, parentID: testFolderId, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: true)
		XCTAssertNil(itemMetadataForFolder.id)
		try manager.cacheMetadata(itemMetadataForFolder)
		XCTAssertNotNil(itemMetadataForFolder.id)
		let fetchedPlaceholderItems = try manager.getPlaceholderMetadata(withParentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue)
		XCTAssert(fetchedPlaceholderItems.isEmpty)
	}

	func testOverwriteMetadata() throws {
		let cloudPath = CloudPath("/TestFolder/")

		let itemMetadata = ItemMetadata(name: "TestFolder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try manager.cacheMetadata(itemMetadata)
		let id = try XCTUnwrap(itemMetadata.id)
		XCTAssertEqual(2, id)
		guard let fetchedItemMetadata = try manager.getCachedMetadata(for: id) else {
			XCTFail("Metadata not stored correctly")
			return
		}
		XCTAssertEqual(itemMetadata, fetchedItemMetadata)

		let fileCloudPath = CloudPath("/Existing File.txt")
		let itemMetadataForFile = ItemMetadata(name: "Existing File.txt", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try manager.cacheMetadata(itemMetadataForFile)
		let secondItemID = try XCTUnwrap(itemMetadataForFile.id)
		XCTAssertEqual(3, secondItemID)

		let changedItemMetadataAtSameRemoteURL = ItemMetadata(name: "TestFolder", type: .folder, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try manager.cacheMetadata(changedItemMetadataAtSameRemoteURL)
		let changedItemID = try XCTUnwrap(changedItemMetadataAtSameRemoteURL.id)
		XCTAssertEqual(2, changedItemID)

		XCTAssertEqual(id, changedItemMetadataAtSameRemoteURL.id)
		guard let fetchedChangedItemMetadata = try manager.getCachedMetadata(for: id) else {
			XCTFail("Metadata not stored correctly")
			return
		}
		XCTAssertEqual(changedItemMetadataAtSameRemoteURL, fetchedChangedItemMetadata)
	}

	func testGetCachedMetadataInsideParentId() throws {
		let fileCloudPath = CloudPath("/Existing File.txt")
		let folderCloudPath = CloudPath("/Existing Folder/")
		let itemMetadataForFile = ItemMetadata(name: "Existing File.txt", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		let itemMetadataForFolder = ItemMetadata(name: "Existing Folder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		XCTAssertNil(itemMetadataForFile.id)
		XCTAssertNil(itemMetadataForFolder.id)
		try manager.cacheMetadata([itemMetadataForFile, itemMetadataForFolder])
		XCTAssertNotNil(itemMetadataForFile.id)
		XCTAssertNotNil(itemMetadataForFolder.id)
		let cachedMetadata = try manager.getCachedMetadata(withParentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue)
		XCTAssertEqual(2, cachedMetadata.count)
		XCTAssertFalse(cachedMetadata.contains { $0.id == NSFileProviderItemIdentifier.rootContainerDatabaseValue })
		XCTAssert(cachedMetadata.contains { $0 == itemMetadataForFile })
		XCTAssert(cachedMetadata.contains { $0 == itemMetadataForFolder })
	}

	func testFlagAllNonPlaceholderItemsAsCacheCleanupCandidates() throws {
		let placeholderFileCloudPath = CloudPath("/Placeholder File.txt")
		let placeholderFolderCloudPath = CloudPath("/Placeholder Folder/")
		let placeholderItemMetadataForFile = ItemMetadata(name: "Placeholder File.txt", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: true)
		let placeholderItemMetadataForFolder = ItemMetadata(name: "Placeholder Folder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: true)
		let fileCloudPath = CloudPath("/Existing File.txt")
		let folderCloudPath = CloudPath("/Existing Folder/")
		let itemMetadataForFile = ItemMetadata(name: "Existing File.txt", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		let itemMetadataForFolder = ItemMetadata(name: "Existing Folder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try manager.cacheMetadata([placeholderItemMetadataForFile, placeholderItemMetadataForFolder, itemMetadataForFile, itemMetadataForFolder])
		try manager.flagAllItemsAsMaybeOutdated(withParentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue)
		let cachedMetadata = try manager.getCachedMetadata(withParentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue)
		XCTAssertEqual(4, cachedMetadata.count)
		XCTAssert(cachedMetadata.contains { $0.name == "Placeholder File.txt" && !$0.isMaybeOutdated })
		XCTAssert(cachedMetadata.contains { $0.name == "Placeholder Folder" && !$0.isMaybeOutdated })
		XCTAssert(cachedMetadata.contains { $0.name == "Existing File.txt" && $0.isMaybeOutdated })
		XCTAssert(cachedMetadata.contains { $0.name == "Existing Folder" && $0.isMaybeOutdated })
	}

	func testGetAllCachedMetadataInsideAFolder() throws {
		let fileInFolderCloudPath = CloudPath("/Test Folder/Test File.txt")
		let fileInSubFolderCloudPath = CloudPath("/Test Folder/SecondFolder/Test File.txt")
		let folderCloudPath = CloudPath("/Test Folder/")
		let secondFolderCloudPath = CloudPath("/Test Folder 1/")
		let subFolderCloudPath = CloudPath("/Test Folder/SecondFolder/")

		let itemMetadataForFolder = ItemMetadata(name: "Test Folder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		let secondItemMetadataForFolder = ItemMetadata(name: "Test Folder 1", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try manager.cacheMetadata([itemMetadataForFolder, secondItemMetadataForFolder])
		guard let folderId = itemMetadataForFolder.id else {
			XCTFail("Folder has no ID")
			return
		}
		let itemMetadataForFileInFolder = ItemMetadata(name: "Test File.txt", type: .file, size: 100, parentID: folderId, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		let itemMetadataForSubFolder = ItemMetadata(name: "SecondFolder", type: .folder, size: nil, parentID: folderId, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try manager.cacheMetadata(itemMetadataForSubFolder)
		guard let subFolderId = itemMetadataForSubFolder.id else {
			XCTFail("Folder has no ID")
			return
		}
		let itemMetadataForFileInSubFolder = ItemMetadata(name: "Test File.txt", type: .file, size: 100, parentID: subFolderId, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try manager.cacheMetadata([itemMetadataForFileInFolder, itemMetadataForFileInSubFolder])
		let cachedMetadata = try manager.getAllCachedMetadata(inside: itemMetadataForFolder)

		XCTAssertEqual(3, cachedMetadata.count)
		XCTAssertTrue(cachedMetadata.contains(where: { $0.id == itemMetadataForFileInFolder.id! }))
		XCTAssertTrue(cachedMetadata.contains(where: { $0.id == subFolderId }))
		XCTAssertTrue(cachedMetadata.contains(where: { $0.id == itemMetadataForFileInSubFolder.id! }))
	}

	func testGetAllCachedMetadataInsideUnsavedFolderThrowsNonSavedItemMetadata() throws {
		let unsavedFolder = ItemMetadata(name: "Unsaved Folder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		XCTAssertThrowsError(try manager.getAllCachedMetadata(inside: unsavedFolder)) { error in
			guard case DBManagerError.nonSavedItemMetadata = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}
	}

	func testGetMetadataWithCaseMismatchPath() throws {
		let cloudPath = CloudPath("/File.txt")
		let itemMetadataForFile = ItemMetadata(name: "File.txt", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try manager.cacheMetadata(itemMetadataForFile)

		guard let fetchedMetadataForSensitivePath = try manager.getCachedMetadata(for: cloudPath) else {
			XCTFail("Metadata not found for path: \(cloudPath)")
			return
		}
		let lowerCasedCloudPath = CloudPath("/file.txt")
		guard let fetchedMetadataForInSensitivePath = try manager.getCachedMetadata(for: lowerCasedCloudPath) else {
			XCTFail("Metadata not found for path: \(lowerCasedCloudPath)")
			return
		}
		XCTAssertEqual(fetchedMetadataForSensitivePath, fetchedMetadataForInSensitivePath)
		XCTAssertEqual("File.txt", fetchedMetadataForInSensitivePath.name)
	}

	func testGetCloudPathResolvesParentChain() throws {
		let itemMetadataForFolder = ItemMetadata(name: "Test Folder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try manager.cacheMetadata(itemMetadataForFolder)
		let folderId = try XCTUnwrap(itemMetadataForFolder.id)
		let itemMetadataForSubFolder = ItemMetadata(name: "SecondFolder", type: .folder, size: nil, parentID: folderId, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try manager.cacheMetadata(itemMetadataForSubFolder)
		let subFolderId = try XCTUnwrap(itemMetadataForSubFolder.id)
		let itemMetadataForFile = ItemMetadata(name: "Test File.txt", type: .file, size: 100, parentID: subFolderId, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try manager.cacheMetadata(itemMetadataForFile)
		let fileId = try XCTUnwrap(itemMetadataForFile.id)

		XCTAssertEqual(CloudPath("/Test Folder/SecondFolder/Test File.txt"), try manager.getCloudPath(for: fileId))
		XCTAssertEqual(CloudPath("/"), try manager.getCloudPath(for: NSFileProviderItemIdentifier.rootContainerDatabaseValue))
	}

	func testGetCloudPathForMissingItemThrowsItemNotFound() throws {
		XCTAssertThrowsError(try manager.getCloudPath(for: 999)) { error in
			guard case FileProviderAdapterError.itemNotFound = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}
	}

	func testGetCloudPathForUnresolvableParentChainThrows() throws {
		let db = try DatabaseQueue()
		try DatabaseHelper.migrate(db)
		let orphan = ItemMetadata(name: "Orphan", type: .folder, size: nil, parentID: 999, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		// Foreign keys must be off to insert a row whose parent does not exist; PRAGMA can't change inside a transaction, hence writeWithoutTransaction.
		try db.writeWithoutTransaction { db in
			try db.execute(sql: "PRAGMA foreign_keys = OFF")
			try orphan.insert(db)
		}
		let manager = ItemMetadataDBManager(database: db)
		let orphanID = try XCTUnwrap(orphan.id)
		XCTAssertThrowsError(try manager.getCloudPath(for: orphanID)) { error in
			guard case FileProviderAdapterError.unresolvableParentChain = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}
	}

	func testGetCachedMetadataForCaseOnlyDuplicateSiblingsResolvesDeterministically() throws {
		let db = try DatabaseQueue()
		try DatabaseHelper.migrate(db)
		// Reverse the order of unordered SELECTs so this test fails unless the sibling fetch explicitly orders by id.
		try db.writeWithoutTransaction { db in
			try db.execute(sql: "PRAGMA reverse_unordered_selects = ON")
		}
		let manager = ItemMetadataDBManager(database: db)
		let firstSibling = ItemMetadata(name: "Foo", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		let secondSibling = ItemMetadata(name: "foo", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try manager.cacheMetadata(firstSibling)
		try manager.cacheMetadata(secondSibling)
		let lowerID = try XCTUnwrap(firstSibling.id)
		let higherID = try XCTUnwrap(secondSibling.id)
		XCTAssertLessThan(lowerID, higherID)

		let exactlyMatchingLowercase = try XCTUnwrap(manager.getCachedMetadata(for: CloudPath("/foo")))
		XCTAssertEqual(higherID, exactlyMatchingLowercase.id)
		XCTAssertEqual("foo", exactlyMatchingLowercase.name)

		let exactlyMatchingUppercase = try XCTUnwrap(manager.getCachedMetadata(for: CloudPath("/Foo")))
		XCTAssertEqual(lowerID, exactlyMatchingUppercase.id)
		XCTAssertEqual("Foo", exactlyMatchingUppercase.name)

		let caseMismatch = try XCTUnwrap(manager.getCachedMetadata(for: CloudPath("/FOO")))
		XCTAssertEqual(lowerID, caseMismatch.id)
	}

	func testCacheMetadataKeepsCaseOnlySiblingsSeparate() throws {
		let rootID = NSFileProviderItemIdentifier.rootContainerDatabaseValue
		let uppercase = ItemMetadata(name: "CaseTest.txt", type: .file, size: 15, parentID: rootID, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		let lowercase = ItemMetadata(name: "casetest.txt", type: .file, size: 15, parentID: rootID, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try manager.cacheMetadata(uppercase)
		try manager.cacheMetadata(lowercase)

		XCTAssertNotEqual(uppercase.id, lowercase.id)
		let children = try manager.getCachedMetadata(withParentID: rootID)
		XCTAssertEqual(["CaseTest.txt", "casetest.txt"], children.map { $0.name }.sorted())
		XCTAssertEqual(CloudPath("/CaseTest.txt"), try manager.getCloudPath(for: XCTUnwrap(uppercase.id)))
		XCTAssertEqual(CloudPath("/casetest.txt"), try manager.getCloudPath(for: XCTUnwrap(lowercase.id)))
	}

	func testCacheMetadataMergesCanonicallyEquivalentNames() throws {
		let rootID = NSFileProviderItemIdentifier.rootContainerDatabaseValue
		let precomposed = ItemMetadata(name: "Cafe\u{0301}.txt".precomposedStringWithCanonicalMapping, type: .file, size: 10, parentID: rootID, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		let decomposed = ItemMetadata(name: "Cafe\u{0301}.txt".decomposedStringWithCanonicalMapping, type: .file, size: 20, parentID: rootID, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try manager.cacheMetadata(precomposed)
		try manager.cacheMetadata(decomposed)

		// Both spellings encrypt to the same ciphertext name, so they are one item.
		XCTAssertEqual(precomposed.id, decomposed.id)
		let children = try manager.getCachedMetadata(withParentID: rootID)
		XCTAssertEqual(1, children.count)
		XCTAssertEqual(decomposed.name, children.first?.name)
	}

	func testCacheMetadataUpdatesCaseOnlyRenameInPlace() throws {
		let rootID = NSFileProviderItemIdentifier.rootContainerDatabaseValue
		let original = ItemMetadata(name: "foo.txt", type: .file, size: 100, parentID: rootID, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try manager.cacheMetadata(original)
		let originalID = try XCTUnwrap(original.id)
		let tagData = Data("Tag".utf8)
		try manager.setTagData(to: tagData, forItemWithID: originalID)
		try manager.setFavoriteRank(to: 42, forItemWithID: originalID)

		// Simulates an enumeration that reports only the renamed spelling.
		try manager.flagAllItemsAsMaybeOutdated(withParentID: rootID)
		let renamed = ItemMetadata(name: "Foo.txt", type: .file, size: 100, parentID: rootID, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try manager.cacheMetadata(renamed)

		XCTAssertEqual(originalID, renamed.id)
		let children = try manager.getCachedMetadata(withParentID: rootID)
		XCTAssertEqual(["Foo.txt"], children.map { $0.name })
		let reloaded = try XCTUnwrap(manager.getCachedMetadata(for: originalID))
		XCTAssertEqual(tagData, reloaded.tagData)
		XCTAssertEqual(42, reloaded.favoriteRank)
	}

	func testCacheMetadataKeepsIdentityWhenCaseVariantIsAddedBeforeTheKnownSpelling() throws {
		let rootID = NSFileProviderItemIdentifier.rootContainerDatabaseValue
		let known = ItemMetadata(name: "report.txt", type: .file, size: 100, parentID: rootID, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try manager.cacheMetadata(known)
		let knownID = try XCTUnwrap(known.id)
		let tagData = Data("Tag".utf8)
		try manager.setTagData(to: tagData, forItemWithID: knownID)
		try manager.flagAllItemsAsMaybeOutdated(withParentID: rootID)

		// Listed before the known spelling: the order a single-pass reconciler would get wrong.
		let addedVariant = ItemMetadata(name: "Report.txt", type: .file, size: 5, parentID: rootID, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		let knownAgain = ItemMetadata(name: "report.txt", type: .file, size: 100, parentID: rootID, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try manager.cacheMetadata([addedVariant, knownAgain])

		XCTAssertEqual(knownID, knownAgain.id)
		XCTAssertNotEqual(knownID, addedVariant.id)
		let reloaded = try XCTUnwrap(manager.getCachedMetadata(for: knownID))
		XCTAssertEqual("report.txt", reloaded.name)
		XCTAssertEqual(tagData, reloaded.tagData)
	}

	func testCacheMetadataReconcilesCaseVariantsIndependentlyOfListingOrder() throws {
		let rootID = NSFileProviderItemIdentifier.rootContainerDatabaseValue
		func idsAfterCaching(_ names: [String]) throws -> (ids: [String: Int64], knownID: Int64) {
			let db = try DatabaseQueue()
			try DatabaseHelper.migrate(db)
			let manager = ItemMetadataDBManager(database: db)
			let known = ItemMetadata(name: "report.txt", type: .file, size: 100, parentID: rootID, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
			try manager.cacheMetadata(known)
			try manager.flagAllItemsAsMaybeOutdated(withParentID: rootID)
			let batch = names.map { ItemMetadata(name: $0, type: .file, size: 100, parentID: rootID, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false) }
			try manager.cacheMetadata(batch)
			let ids: [String: Int64] = try manager.getCachedMetadata(withParentID: rootID).reduce(into: [:]) { $0[$1.name] = $1.id }
			return try (ids, XCTUnwrap(known.id))
		}
		let variantFirst = try idsAfterCaching(["Report.txt", "report.txt"])
		let knownFirst = try idsAfterCaching(["report.txt", "Report.txt"])
		XCTAssertEqual(variantFirst.ids, knownFirst.ids)
		// Agreement alone would also hold if both orders were wrong in the same way.
		XCTAssertEqual(variantFirst.knownID, variantFirst.ids["report.txt"])
	}

	func testCacheMetadataClaimsAnOutdatedRowOnlyOnce() throws {
		let rootID = NSFileProviderItemIdentifier.rootContainerDatabaseValue
		let known = ItemMetadata(name: "REPORT.TXT", type: .file, size: 100, parentID: rootID, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try manager.cacheMetadata(known)
		let knownID = try XCTUnwrap(known.id)
		try manager.flagAllItemsAsMaybeOutdated(withParentID: rootID)

		// Neither reported spelling matches exactly, so both are candidates for the one outdated row.
		let first = ItemMetadata(name: "Report.txt", type: .file, size: 100, parentID: rootID, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		let second = ItemMetadata(name: "report.txt", type: .file, size: 100, parentID: rootID, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try manager.cacheMetadata([first, second])

		XCTAssertNotEqual(first.id, second.id)
		let children = try manager.getCachedMetadata(withParentID: rootID)
		XCTAssertEqual(["Report.txt", "report.txt"], children.map { $0.name }.sorted())
		XCTAssertTrue([first.id, second.id].contains(knownID))
	}

	func testCacheMetadataMergesCanonicallyEquivalentNamesWithinOneBatch() throws {
		let rootID = NSFileProviderItemIdentifier.rootContainerDatabaseValue
		let precomposed = ItemMetadata(name: "Cafe\u{0301}.txt".precomposedStringWithCanonicalMapping, type: .file, size: 10, parentID: rootID, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		let decomposed = ItemMetadata(name: "Cafe\u{0301}.txt".decomposedStringWithCanonicalMapping, type: .file, size: 20, parentID: rootID, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try manager.cacheMetadata([precomposed, decomposed])

		XCTAssertEqual(precomposed.id, decomposed.id)
		XCTAssertEqual(1, try manager.getCachedMetadata(withParentID: rootID).count)
	}

	func testCacheMetadataForPlaceholderDoesNotAdoptCaseOnlySibling() throws {
		let rootID = NSFileProviderItemIdentifier.rootContainerDatabaseValue
		let existing = ItemMetadata(name: "foo.txt", type: .file, size: 100, parentID: rootID, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try manager.cacheMetadata(existing)
		let existingID = try XCTUnwrap(existing.id)
		try manager.flagAllItemsAsMaybeOutdated(withParentID: rootID)

		let placeholder = ItemMetadata(name: "Foo.txt", type: .file, size: 5, parentID: rootID, lastModifiedDate: nil, statusCode: .isUploading, isPlaceholderItem: true)
		try manager.cacheMetadata(placeholder)

		XCTAssertNotEqual(existingID, placeholder.id)
		XCTAssertEqual(2, try manager.getCachedMetadata(withParentID: rootID).count)
	}

	// MARK: Set Tag Data

	func testSetTagData() throws {
		let cloudPath = CloudPath("/File.txt")
		let itemMetadata = ItemMetadata(name: "File.txt", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try manager.cacheMetadata(itemMetadata)
		let tagData = Data("Foo".utf8)
		let id = try XCTUnwrap(itemMetadata.id)
		try manager.setTagData(to: tagData, forItemWithID: id)

		let cachedMetadata = try XCTUnwrap(manager.getCachedMetadata(for: id))
		XCTAssertEqual(tagData, cachedMetadata.tagData)
	}

	func testSetTagDataToNil() throws {
		let cloudPath = CloudPath("/File.txt")
		let tagData = Data("Foo".utf8)
		let itemMetadata = ItemMetadata(name: "File.txt", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false, tagData: tagData)
		try manager.cacheMetadata(itemMetadata)

		let id = try XCTUnwrap(itemMetadata.id)
		try manager.setTagData(to: nil, forItemWithID: id)

		let cachedMetadata = try XCTUnwrap(manager.getCachedMetadata(for: id))
		XCTAssertNil(cachedMetadata.tagData)
	}

	func testCacheMetadataDoesNotOverwriteExistingTagData() throws {
		let cloudPath = CloudPath("/File.txt")
		let tagData = Data("Foo".utf8)
		let itemMetadata = ItemMetadata(name: "File.txt", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false, tagData: tagData)
		try manager.cacheMetadata(itemMetadata)

		itemMetadata.tagData = nil
		try manager.cacheMetadata(itemMetadata)

		let id = try XCTUnwrap(itemMetadata.id)
		let cachedMetadata = try XCTUnwrap(manager.getCachedMetadata(for: id))
		XCTAssertEqual(tagData, cachedMetadata.tagData)
	}

	// MARK: Set Favorite Rank

	func testSetFavoriteRank() throws {
		let cloudPath = CloudPath("/Folder")
		let itemMetadata = ItemMetadata(name: "Folder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try manager.cacheMetadata(itemMetadata)
		let favoriteRank: Int64 = 100
		let id = try XCTUnwrap(itemMetadata.id)
		try manager.setFavoriteRank(to: favoriteRank, forItemWithID: id)

		let cachedMetadata = try XCTUnwrap(manager.getCachedMetadata(for: id))
		XCTAssertEqual(favoriteRank, cachedMetadata.favoriteRank)
	}

	func testSetFavoriteRankToNil() throws {
		let cloudPath = CloudPath("/Folder")
		let itemMetadata = ItemMetadata(name: "Folder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false, favoriteRank: 100)
		try manager.cacheMetadata(itemMetadata)
		let id = try XCTUnwrap(itemMetadata.id)
		try manager.setFavoriteRank(to: nil, forItemWithID: id)

		let cachedMetadata = try XCTUnwrap(manager.getCachedMetadata(for: id))
		XCTAssertNil(cachedMetadata.favoriteRank)
	}

	func testCacheMetadataDoesNotOverwriteExistingFavoriteRank() throws {
		let cloudPath = CloudPath("/Folder")
		let favoriteRank: Int64 = 100
		let itemMetadata = ItemMetadata(name: "File.txt", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false, favoriteRank: favoriteRank)
		try manager.cacheMetadata(itemMetadata)

		itemMetadata.favoriteRank = nil
		try manager.cacheMetadata(itemMetadata)

		let id = try XCTUnwrap(itemMetadata.id)
		let cachedMetadata = try XCTUnwrap(manager.getCachedMetadata(for: id))
		XCTAssertEqual(favoriteRank, cachedMetadata.favoriteRank)
	}
}

extension ItemMetadata: Comparable {
	public static func < (lhs: ItemMetadata, rhs: ItemMetadata) -> Bool {
		return lhs.name < rhs.name
	}
}
