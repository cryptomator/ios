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
		let inMemoryDB = DatabaseQueue()
		try DatabaseHelper.migrate(inMemoryDB)
		manager = ItemMetadataDBManager(database: inMemoryDB)
	}

	func testCacheMetadataForFile() throws {
		let cloudPath = CloudPath("/TestFile")

		let itemMetadata = ItemMetadata(name: "TestFile", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
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

		let itemMetadata = ItemMetadata(name: "Test Folder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: true)
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
		let itemMetadataForFile = ItemMetadata(name: "TestFile", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: fileCloudPath, isPlaceholderItem: false)
		let itemMetadataForFolder = ItemMetadata(name: "TestFolder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: folderCloudPath, isPlaceholderItem: true)
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
		let placeholderItemMetadataForFile = ItemMetadata(name: "Test File.txt", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: fileCloudPath, isPlaceholderItem: true)
		let placeholderItemMetadataForFolder = ItemMetadata(name: "Test Folder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: folderCloudPath, isPlaceholderItem: true)
		let itemMetadataForFolder = ItemMetadata(name: "SecondFolder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: secondFolderCloudPath, isPlaceholderItem: false)
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
		let placeholderItemMetadataForFile = ItemMetadata(name: "Test File.txt", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: fileCloudPath, isPlaceholderItem: false)
		let placeholderItemMetadataForFolder = ItemMetadata(name: "Test Folder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: folderCloudPath, isPlaceholderItem: false)
		XCTAssertNil(placeholderItemMetadataForFile.id)
		XCTAssertNil(placeholderItemMetadataForFolder.id)
		try manager.cacheMetadata([placeholderItemMetadataForFile, placeholderItemMetadataForFolder])
		XCTAssertNotNil(placeholderItemMetadataForFile.id)
		guard let testFolderId = placeholderItemMetadataForFolder.id else {
			XCTFail("Test Folder ID is nil")
			return
		}
		let itemMetadataForFolder = ItemMetadata(name: "SecondFolder", type: .folder, size: nil, parentID: testFolderId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: secondFolderCloudPath, isPlaceholderItem: true)
		XCTAssertNil(itemMetadataForFolder.id)
		try manager.cacheMetadata(itemMetadataForFolder)
		XCTAssertNotNil(itemMetadataForFolder.id)
		let fetchedPlaceholderItems = try manager.getPlaceholderMetadata(withParentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue)
		XCTAssert(fetchedPlaceholderItems.isEmpty)
	}

	func testOverwriteMetadata() throws {
		let cloudPath = CloudPath("/TestFolder/")

		let itemMetadata = ItemMetadata(name: "TestFolder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
		try manager.cacheMetadata(itemMetadata)
		let id = try XCTUnwrap(itemMetadata.id)
		XCTAssertEqual(2, id)
		guard let fetchedItemMetadata = try manager.getCachedMetadata(for: id) else {
			XCTFail("Metadata not stored correctly")
			return
		}
		XCTAssertEqual(itemMetadata, fetchedItemMetadata)

		let fileCloudPath = CloudPath("/Existing File.txt")
		let itemMetadataForFile = ItemMetadata(name: "Existing File.txt", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: fileCloudPath, isPlaceholderItem: false)
		try manager.cacheMetadata(itemMetadataForFile)
		let secondItemID = try XCTUnwrap(itemMetadataForFile.id)
		XCTAssertEqual(3, secondItemID)

		let changedItemMetadataAtSameRemoteURL = ItemMetadata(name: "TestFolder", type: .folder, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
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
		let itemMetadataForFile = ItemMetadata(name: "Existing File.txt", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: fileCloudPath, isPlaceholderItem: false)
		let itemMetadataForFolder = ItemMetadata(name: "Existing Folder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: folderCloudPath, isPlaceholderItem: false)
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
		let placeholderItemMetadataForFile = ItemMetadata(name: "Placeholder File.txt", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: placeholderFileCloudPath, isPlaceholderItem: true)
		let placeholderItemMetadataForFolder = ItemMetadata(name: "Placeholder Folder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: placeholderFolderCloudPath, isPlaceholderItem: true)
		let fileCloudPath = CloudPath("/Existing File.txt")
		let folderCloudPath = CloudPath("/Existing Folder/")
		let itemMetadataForFile = ItemMetadata(name: "Existing File.txt", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: fileCloudPath, isPlaceholderItem: false)
		let itemMetadataForFolder = ItemMetadata(name: "Existing Folder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: folderCloudPath, isPlaceholderItem: false)
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

		let itemMetadataForFolder = ItemMetadata(name: "Test Folder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: folderCloudPath, isPlaceholderItem: false)
		let secondItemMetadataForFolder = ItemMetadata(name: "Test Folder 1", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: secondFolderCloudPath, isPlaceholderItem: false)
		try manager.cacheMetadata([itemMetadataForFolder, secondItemMetadataForFolder])
		guard let folderId = itemMetadataForFolder.id else {
			XCTFail("Folder has no ID")
			return
		}
		let itemMetadataForFileInFolder = ItemMetadata(name: "Test File.txt", type: .file, size: 100, parentID: folderId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: fileInFolderCloudPath, isPlaceholderItem: false)
		let itemMetadataForSubFolder = ItemMetadata(name: "SecondFolder", type: .folder, size: nil, parentID: folderId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: subFolderCloudPath, isPlaceholderItem: false)
		try manager.cacheMetadata(itemMetadataForSubFolder)
		guard let subFolderId = itemMetadataForSubFolder.id else {
			XCTFail("Folder has no ID")
			return
		}
		let itemMetadataForFileInSubFolder = ItemMetadata(name: "Test File.txt", type: .file, size: 100, parentID: subFolderId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: fileInSubFolderCloudPath, isPlaceholderItem: false)
		try manager.cacheMetadata([itemMetadataForFileInFolder, itemMetadataForFileInSubFolder])
		let cachedMetadata = try manager.getAllCachedMetadata(inside: itemMetadataForFolder)

		XCTAssertEqual(3, cachedMetadata.count)
		XCTAssertTrue(cachedMetadata.contains(where: { $0.id == itemMetadataForFileInFolder.id! }))
		XCTAssertTrue(cachedMetadata.contains(where: { $0.id == subFolderId }))
		XCTAssertTrue(cachedMetadata.contains(where: { $0.id == itemMetadataForFileInSubFolder.id! }))
	}

	func testGetMetadataWithCaseMismatchPath() throws {
		let cloudPath = CloudPath("/File.txt")
		let itemMetadataForFile = ItemMetadata(name: "File.txt", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
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
		XCTAssertEqual(cloudPath, fetchedMetadataForInSensitivePath.cloudPath)
	}

	// MARK: Set Tag Data

	func testSetTagData() throws {
		let cloudPath = CloudPath("/File.txt")
		let itemMetadata = ItemMetadata(name: "File.txt", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
		try manager.cacheMetadata(itemMetadata)
		let tagData = "Foo".data(using: .utf8)!
		let id = try XCTUnwrap(itemMetadata.id)
		try manager.setTagData(to: tagData, forItemWithID: id)

		let cachedMetadata = try XCTUnwrap(manager.getCachedMetadata(for: id))
		XCTAssertEqual(tagData, cachedMetadata.tagData)
	}

	func testSetTagDataToNil() throws {
		let cloudPath = CloudPath("/File.txt")
		let tagData = "Foo".data(using: .utf8)!
		let itemMetadata = ItemMetadata(name: "File.txt", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false, tagData: tagData)
		try manager.cacheMetadata(itemMetadata)

		let id = try XCTUnwrap(itemMetadata.id)
		try manager.setTagData(to: nil, forItemWithID: id)

		let cachedMetadata = try XCTUnwrap(manager.getCachedMetadata(for: id))
		XCTAssertNil(cachedMetadata.tagData)
	}

	func testCacheMetadataDoesNotOverwriteExistingTagData() throws {
		let cloudPath = CloudPath("/File.txt")
		let tagData = "Foo".data(using: .utf8)!
		let itemMetadata = ItemMetadata(name: "File.txt", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false, tagData: tagData)
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
		let itemMetadata = ItemMetadata(name: "Folder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
		try manager.cacheMetadata(itemMetadata)
		let favoriteRank: Int64 = 100
		let id = try XCTUnwrap(itemMetadata.id)
		try manager.setFavoriteRank(to: favoriteRank, forItemWithID: id)

		let cachedMetadata = try XCTUnwrap(manager.getCachedMetadata(for: id))
		XCTAssertEqual(favoriteRank, cachedMetadata.favoriteRank)
	}

	func testSetFavoriteRankToNil() throws {
		let cloudPath = CloudPath("/Folder")
		let itemMetadata = ItemMetadata(name: "Folder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false, favoriteRank: 100)
		try manager.cacheMetadata(itemMetadata)
		let id = try XCTUnwrap(itemMetadata.id)
		try manager.setFavoriteRank(to: nil, forItemWithID: id)

		let cachedMetadata = try XCTUnwrap(manager.getCachedMetadata(for: id))
		XCTAssertNil(cachedMetadata.favoriteRank)
	}

	func testCacheMetadataDoesNotOverwriteExistingFavoriteRank() throws {
		let cloudPath = CloudPath("/Folder")
		let favoriteRank: Int64 = 100
		let itemMetadata = ItemMetadata(name: "File.txt", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false, favoriteRank: favoriteRank)
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

	public static func == (lhs: ItemMetadata, rhs: ItemMetadata) -> Bool {
		return lhs.name == rhs.name && lhs.type == rhs.type && lhs.size == rhs.size && lhs.parentID == rhs.parentID && lhs.lastModifiedDate == rhs.lastModifiedDate && lhs.statusCode == rhs.statusCode && lhs.cloudPath == rhs.cloudPath && lhs.isPlaceholderItem == rhs.isPlaceholderItem && lhs.isMaybeOutdated == rhs.isMaybeOutdated
	}
}
