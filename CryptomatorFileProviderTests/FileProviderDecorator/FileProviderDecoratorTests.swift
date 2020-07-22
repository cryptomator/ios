//
//  FileProviderDecoratorTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 01.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import Promises
import XCTest
@testable import CryptomatorFileProvider
class FileProviderDecoratorTests: FileProviderDecoratorTestCase {
	func testRemoveItemFromCacheWithoutAnExistingLocalCachedFile() throws {
		let itemMetadata = ItemMetadata(id: 2, name: "TestFile", type: .file, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: "/Testfile", isPlaceholderItem: false)
		try decorator.itemMetadataManager.cacheMetadata(itemMetadata)
		try decorator.removeItemFromCache(with: 2)
		guard try decorator.itemMetadataManager.getCachedMetadata(for: 2) == nil else {
			XCTFail("ItemMetadata entry still exists")
			return
		}
	}

	func testRemoveItemFromCache() throws {
		let itemMetadata = ItemMetadata(id: 2, name: "TestFile", type: .file, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: "/Testfile", isPlaceholderItem: false)
		try decorator.itemMetadataManager.cacheMetadata(itemMetadata)
		try decorator.cachedFileManager.cacheLocalFileInfo(for: 2, lastModifiedDate: Date(timeIntervalSinceReferenceDate: 0))
		let identifier = NSFileProviderItemIdentifier("2")
		guard let localURLForItem = decorator.urlForItem(withPersistentIdentifier: identifier) else {
			XCTFail("localURLForItem is nil")
			return
		}
		try FileManager.default.createDirectory(at: localURLForItem.deletingLastPathComponent(), withIntermediateDirectories: false, attributes: nil)
		let content = "TestLocalContent"
		try content.write(to: localURLForItem, atomically: true, encoding: .utf8)
		try decorator.removeItemFromCache(with: 2)
		guard try decorator.itemMetadataManager.getCachedMetadata(for: 2) == nil else {
			XCTFail("ItemMetadata entry still exists")
			return
		}
		guard try decorator.cachedFileManager.getLastModifiedDate(for: 2) == nil else {
			XCTFail("CachedFile entry still exists")
			return
		}
		XCTAssertFalse(FileManager.default.fileExists(atPath: localURLForItem.path))
	}

	func testCloudFileNameCollisionHandling() throws {
		let localURL = tmpDirectory.appendingPathComponent("itemAlreadyExists.txt", isDirectory: false)
		try "".write(to: localURL, atomically: true, encoding: .utf8)
		let collisionFreeLocalURL = tmpDirectory.appendingPathComponent("itemAlreadyExists (AAAAA).txt", isDirectory: false)
		let remoteURL = URL(fileURLWithPath: "/itemAlreadyExists (AAAAA).txt", isDirectory: false)
		let metadata = try decorator.createPlaceholderItemForFile(for: localURL, in: .rootContainer).metadata
		guard let id = metadata.id else {
			XCTFail("Metadata has no id")
			return
		}
		try decorator.cloudFileNameCollisionHandling(for: localURL, with: collisionFreeLocalURL, itemMetadata: metadata)
		XCTAssertEqual("itemAlreadyExists (AAAAA).txt", metadata.name)
		XCTAssertEqual(id, metadata.id)
		XCTAssertEqual(remoteURL.relativePath, metadata.remotePath)
		XCTAssertFalse(FileManager.default.fileExists(atPath: localURL.path))
		XCTAssert(FileManager.default.fileExists(atPath: collisionFreeLocalURL.path))
	}

	func testFilterOutWaitingReparentTasks() throws {

		let itemMetadatas = [ItemMetadata(name: "File1.txt", type: .file, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: "/File1.txt", isPlaceholderItem: false),
							 ItemMetadata(name: "File is being renamed.txt", type: .file, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploading, remotePath: "/File is being renamed.txt", isPlaceholderItem: false)
		]
		try decorator.itemMetadataManager.cacheMetadatas(itemMetadatas)
		try decorator.reparentTaskManager.createTask(for: itemMetadatas[1].id!, oldRemoteURL: URL(fileURLWithPath: "/File is being renamed.txt", isDirectory: false), newRemoteURL: URL(fileURLWithPath: "/RenamedFile.txt", isDirectory: false), oldParentId: MetadataManager.rootContainerId, newParentId: MetadataManager.rootContainerId)
		let filteredMetadata = try decorator.filterOutWaitingReparentTasks(parentId: MetadataManager.rootContainerId, for: itemMetadatas)
		XCTAssertEqual(1, filteredMetadata.count)
		XCTAssertEqual(itemMetadatas[0], filteredMetadata[0])
	}
}
