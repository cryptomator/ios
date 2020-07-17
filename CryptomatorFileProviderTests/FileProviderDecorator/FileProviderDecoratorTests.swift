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
}
