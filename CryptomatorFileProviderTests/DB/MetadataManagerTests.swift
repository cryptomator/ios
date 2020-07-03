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

	override func setUpWithError() throws {
		let inMemoryDB = DatabaseQueue()
		manager = try MetadataManager(with: inMemoryDB)
	}

	override func tearDownWithError() throws {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
	}

	func testCacheMetadataForFile() throws {
		let remoteURL = URL(fileURLWithPath: "/TestFile", isDirectory: false)

		let itemMetadata = ItemMetadata(name: "TestFile", type: .file, size: 100, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: remoteURL.relativePath, isPlaceholderItem: false)
		XCTAssertNil(itemMetadata.id)
		try manager.cacheMetadata(itemMetadata)
		guard let fetchedMetadata = try manager.getCachedMetadata(for: remoteURL.relativePath) else {
			XCTFail("ItemMetadata not cached properly")
			return
		}
		XCTAssertEqual(itemMetadata, fetchedMetadata)
		XCTAssertNotNil(fetchedMetadata.id)
	}

	func testCacheMetadataForFolder() throws {
		let remoteURL = URL(fileURLWithPath: "/TestFolder/", isDirectory: true)

		let itemMetadata = ItemMetadata(name: "TestFolder", type: .folder, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: remoteURL.relativePath, isPlaceholderItem: true)
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
}

extension ItemMetadata: Comparable {
	public static func < (lhs: ItemMetadata, rhs: ItemMetadata) -> Bool {
		return lhs.name < rhs.name
	}

	public static func == (lhs: ItemMetadata, rhs: ItemMetadata) -> Bool {
		return lhs.name == rhs.name && lhs.type == rhs.type && lhs.size == rhs.size && lhs.parentId == rhs.parentId && lhs.lastModifiedDate == rhs.lastModifiedDate && lhs.statusCode == rhs.statusCode && lhs.remotePath == rhs.remotePath && lhs.isPlaceholderItem == rhs.isPlaceholderItem
	}
}
