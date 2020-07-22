//
//  MetadataManagerTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 26.06.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import GRDB
import XCTest
@testable import CryptomatorFileProvider
class MetadataManagerTests: XCTestCase {
	var manager: MetadataManager!
	var tmpDirURL: URL!
	override func setUpWithError() throws {
		tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: tmpDirURL, withIntermediateDirectories: true)
		let dbURL = tmpDirURL.appendingPathComponent("db.sqlite", isDirectory: false)
		let dbQueue = try DataBaseHelper.getDBMigratedQueue(at: dbURL.path)
		manager = MetadataManager(with: dbQueue)
	}

	override func tearDownWithError() throws {
		manager = nil
		try FileManager.default.removeItem(at: tmpDirURL)
	}

	func testCacheMetadataForFile() throws {
		let remoteURL = URL(fileURLWithPath: "/TestFile", isDirectory: false)

		let itemMetadata = ItemMetadata(name: "TestFile", type: .file, size: 100, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: remoteURL.relativePath, isPlaceholderItem: false)
		XCTAssertNil(itemMetadata.id)
		try manager.cacheMetadata(itemMetadata)
		XCTAssertNotNil(itemMetadata.id)
		guard let fetchedMetadata = try manager.getCachedMetadata(for: remoteURL.relativePath) else {
			XCTFail("ItemMetadata not cached properly")
			return
		}
		XCTAssertEqual(itemMetadata, fetchedMetadata)
		XCTAssertNotNil(fetchedMetadata.id)
	}

	func testCacheMetadataForFolder() throws {
		let remoteURL = URL(fileURLWithPath: "/Test Folder/", isDirectory: true)

		let itemMetadata = ItemMetadata(name: "Test Folder", type: .folder, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: remoteURL.relativePath, isPlaceholderItem: true)
		XCTAssertNil(itemMetadata.id)
		try manager.cacheMetadata(itemMetadata)
		guard let fetchedMetadata = try manager.getCachedMetadata(for: remoteURL.relativePath) else {
			XCTFail("ItemMetadata not cached properly")
			return
		}
		XCTAssertEqual(itemMetadata, fetchedMetadata)
		XCTAssertNotNil(fetchedMetadata.id)
	}

	func testCacheMultipleEntries() throws {
		let remoteFileURL = URL(fileURLWithPath: "/TestFile", isDirectory: false)
		let remoteFolderURL = URL(fileURLWithPath: "/TestFolder/", isDirectory: true)
		let itemMetadataForFile = ItemMetadata(name: "TestFile", type: .file, size: 100, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: remoteFileURL.relativePath, isPlaceholderItem: false)
		let itemMetadataForFolder = ItemMetadata(name: "TestFolder", type: .folder, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: remoteFolderURL.relativePath, isPlaceholderItem: true)
		XCTAssertNil(itemMetadataForFile.id)
		XCTAssertNil(itemMetadataForFolder.id)
		let metadatas = [itemMetadataForFile, itemMetadataForFolder]
		try manager.cacheMetadatas(metadatas)
		guard let fetchedMetadataForFile = try manager.getCachedMetadata(for: remoteFileURL.relativePath) else {
			XCTFail("ItemMetadata not cached properly")
			return
		}
		XCTAssertEqual(itemMetadataForFile, fetchedMetadataForFile)
		XCTAssertNotNil(fetchedMetadataForFile.id)
		guard let fetchedMetadataForFolder = try manager.getCachedMetadata(for: remoteFolderURL.relativePath) else {
			XCTFail("ItemMetadata not cached properly")
			return
		}
		XCTAssertEqual(itemMetadataForFolder, fetchedMetadataForFolder)
		XCTAssertNotNil(fetchedMetadataForFolder.id)
	}

	func testGetPlaceholderItems() throws {
		let remoteFileURL = URL(fileURLWithPath: "/Test File.txt", isDirectory: false)
		let remoteFolderURL = URL(fileURLWithPath: "/Test Folder/", isDirectory: true)
		let remoteSecondFolderURL = URL(fileURLWithPath: "/SecondFolder/", isDirectory: true)
		let placeholderItemMetadataForFile = ItemMetadata(name: "Test File.txt", type: .file, size: 100, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: remoteFileURL.relativePath, isPlaceholderItem: true)
		let placeholderItemMetadataForFolder = ItemMetadata(name: "Test Folder", type: .folder, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: remoteFolderURL.relativePath, isPlaceholderItem: true)
		let itemMetadataForFolder = ItemMetadata(name: "SecondFolder", type: .folder, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: remoteSecondFolderURL.relativePath, isPlaceholderItem: false)
		XCTAssertNil(placeholderItemMetadataForFile.id)
		XCTAssertNil(placeholderItemMetadataForFolder.id)
		XCTAssertNil(itemMetadataForFolder.id)
		try manager.cacheMetadatas([placeholderItemMetadataForFile, placeholderItemMetadataForFolder, itemMetadataForFolder])
		let fetchedPlaceholderItems = try manager.getPlaceholderMetadata(for: MetadataManager.rootContainerId)
		XCTAssertEqual(2, fetchedPlaceholderItems.count)
		XCTAssertEqual([placeholderItemMetadataForFile, placeholderItemMetadataForFolder], fetchedPlaceholderItems)
		XCTAssertNotNil(fetchedPlaceholderItems[0].id)
		XCTAssertNotNil(fetchedPlaceholderItems[1].id)
		XCTAssertNotEqual(fetchedPlaceholderItems[0].id, fetchedPlaceholderItems[1].id)
	}

	func testGetPlaceholderItemsIsEmptyForNoPlaceholderItemsUnderParent() throws {
		let remoteFileURL = URL(fileURLWithPath: "/Test File.txt", isDirectory: false)
		let remoteFolderURL = URL(fileURLWithPath: "/Test Folder/", isDirectory: true)
		let remoteSecondFolderURL = URL(fileURLWithPath: "/Test Folder/SecondFolder/", isDirectory: true)
		let placeholderItemMetadataForFile = ItemMetadata(name: "Test File.txt", type: .file, size: 100, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: remoteFileURL.relativePath, isPlaceholderItem: false)
		let placeholderItemMetadataForFolder = ItemMetadata(name: "Test Folder", type: .folder, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: remoteFolderURL.relativePath, isPlaceholderItem: false)
		XCTAssertNil(placeholderItemMetadataForFile.id)
		XCTAssertNil(placeholderItemMetadataForFolder.id)
		try manager.cacheMetadatas([placeholderItemMetadataForFile, placeholderItemMetadataForFolder])
		XCTAssertNotNil(placeholderItemMetadataForFile.id)
		guard let testFolderId = placeholderItemMetadataForFolder.id else {
			XCTFail("Test Folder ID is nil")
			return
		}
		let itemMetadataForFolder = ItemMetadata(name: "SecondFolder", type: .folder, size: nil, parentId: testFolderId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: remoteSecondFolderURL.relativePath, isPlaceholderItem: true)
		XCTAssertNil(itemMetadataForFolder.id)
		try manager.cacheMetadata(itemMetadataForFolder)
		XCTAssertNotNil(itemMetadataForFolder.id)
		let fetchedPlaceholderItems = try manager.getPlaceholderMetadata(for: MetadataManager.rootContainerId)
		XCTAssert(fetchedPlaceholderItems.isEmpty)
	}

	func testOverwriteMetadata() throws {
		let remoteURL = URL(fileURLWithPath: "/TestFolder/", isDirectory: true)

		let itemMetadata = ItemMetadata(name: "TestFolder", type: .folder, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: remoteURL.relativePath, isPlaceholderItem: false)
		try manager.cacheMetadata(itemMetadata)
		guard let id = itemMetadata.id else {
			XCTFail("Metadata has no id")
			return
		}
		guard let fetchedItemMetadata = try manager.getCachedMetadata(for: id) else {
			XCTFail("Metadata not stored correctly")
			return
		}
		XCTAssertEqual(itemMetadata, fetchedItemMetadata)
		let changedItemMetadataAtSameRemoteURL = ItemMetadata(name: "TestFolder", type: .folder, size: 100, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: remoteURL.relativePath, isPlaceholderItem: false)
		try manager.cacheMetadata(changedItemMetadataAtSameRemoteURL)

		XCTAssertEqual(id, changedItemMetadataAtSameRemoteURL.id)
		guard let fetchedChangedItemMetadata = try manager.getCachedMetadata(for: id) else {
			XCTFail("Metadata not stored correctly")
			return
		}
		XCTAssertEqual(changedItemMetadataAtSameRemoteURL, fetchedChangedItemMetadata)
	}

	func testGetCachedMetadataInsideParentId() throws {
		let remoteFileURL = URL(fileURLWithPath: "/Existing File.txt", isDirectory: false)
		let remoteFolderURL = URL(fileURLWithPath: "/Existing Folder/", isDirectory: true)
		let itemMetadataForFile = ItemMetadata(name: "Existing File.txt", type: .file, size: 100, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: remoteFileURL.relativePath, isPlaceholderItem: false)
		let itemMetadataForFolder = ItemMetadata(name: "Existing Folder", type: .folder, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: remoteFolderURL.relativePath, isPlaceholderItem: false)
		XCTAssertNil(itemMetadataForFile.id)
		XCTAssertNil(itemMetadataForFolder.id)
		try manager.cacheMetadatas([itemMetadataForFile, itemMetadataForFolder])
		XCTAssertNotNil(itemMetadataForFile.id)
		XCTAssertNotNil(itemMetadataForFolder.id)
		let cachedMetadata = try manager.getCachedMetadata(forParentId: MetadataManager.rootContainerId)
		XCTAssertEqual(2, cachedMetadata.count)
		XCTAssertFalse(cachedMetadata.contains { $0.id == MetadataManager.rootContainerId })
		XCTAssert(cachedMetadata.contains { $0 == itemMetadataForFile })
		XCTAssert(cachedMetadata.contains { $0 == itemMetadataForFolder })
	}

	func testFlagAllNonPlaceholderItemsAsCacheCleanupCandidates() throws {
		let remotePlaceholderFileURL = URL(fileURLWithPath: "/Placeholder File.txt", isDirectory: false)
		let remotePlaceholderFolderURL = URL(fileURLWithPath: "/Placeholder Folder/", isDirectory: true)
		let placeholderItemMetadataForFile = ItemMetadata(name: "Placeholder File.txt", type: .file, size: 100, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: remotePlaceholderFileURL.relativePath, isPlaceholderItem: true)
		let placeholderItemMetadataForFolder = ItemMetadata(name: "Placeholder Folder", type: .folder, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: remotePlaceholderFolderURL.relativePath, isPlaceholderItem: true)
		let remoteFileURL = URL(fileURLWithPath: "/Existing File.txt", isDirectory: false)
		let remoteFolderURL = URL(fileURLWithPath: "/Existing Folder/", isDirectory: true)
		let itemMetadataForFile = ItemMetadata(name: "Existing File.txt", type: .file, size: 100, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: remoteFileURL.relativePath, isPlaceholderItem: false)
		let itemMetadataForFolder = ItemMetadata(name: "Existing Folder", type: .folder, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: remoteFolderURL.relativePath, isPlaceholderItem: false)
		try manager.cacheMetadatas([placeholderItemMetadataForFile, placeholderItemMetadataForFolder, itemMetadataForFile, itemMetadataForFolder])
		try manager.flagAllItemsAsMaybeOutdated(insideParentId: MetadataManager.rootContainerId)
		let cachedMetadata = try manager.getCachedMetadata(forParentId: MetadataManager.rootContainerId)
		XCTAssertEqual(4, cachedMetadata.count)
		XCTAssert(cachedMetadata.contains { $0.name == "Placeholder File.txt" && !$0.isMaybeOutdated })
		XCTAssert(cachedMetadata.contains { $0.name == "Placeholder Folder" && !$0.isMaybeOutdated })
		XCTAssert(cachedMetadata.contains { $0.name == "Existing File.txt" && $0.isMaybeOutdated })
		XCTAssert(cachedMetadata.contains { $0.name == "Existing Folder" && $0.isMaybeOutdated })
	}
}

extension ItemMetadata: Comparable {
	public static func < (lhs: ItemMetadata, rhs: ItemMetadata) -> Bool {
		return lhs.name < rhs.name
	}

	public static func == (lhs: ItemMetadata, rhs: ItemMetadata) -> Bool {
		return lhs.name == rhs.name && lhs.type == rhs.type && lhs.size == rhs.size && lhs.parentId == rhs.parentId && lhs.lastModifiedDate == rhs.lastModifiedDate && lhs.statusCode == rhs.statusCode && lhs.remotePath == rhs.remotePath && lhs.isPlaceholderItem == rhs.isPlaceholderItem && lhs.isMaybeOutdated == rhs.isMaybeOutdated
	}
}
