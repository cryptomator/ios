//
//  MetadataManagerTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 26.06.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import XCTest
@testable import CryptomatorFileProvider
class MetadataManagerTests: XCTestCase {

	var manager: MetadataManager!
	let domain = NSFileProviderDomainIdentifier("test")
    override func setUpWithError() throws {
        manager = try MetadataManager(for: domain)
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testCacheMetadataForFile() throws {
		let rootURL = URL(fileURLWithPath: "/", isDirectory: true)
		let remoteURL = URL(fileURLWithPath: "/TestFile", isDirectory: false)

		let itemMetadata = ItemMetadata(name: "TestFile", type: .file, size: 100, remoteParentPath: rootURL.relativePath, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: remoteURL.relativePath, isPlaceholderItem: false)
		try manager.cacheMetadata(itemMetadata)
		guard let fetchedMetadata = try manager.getCachedMetadata(for: remoteURL.relativePath) else {
			XCTFail("ItemMetadata not cached properly")
			return
		}
		XCTAssertEqual(itemMetadata, fetchedMetadata)
    }

	func testCacheMetadataForFolder() throws {
		let rootURL = URL(fileURLWithPath: "/", isDirectory: true)
		let remoteURL = URL(fileURLWithPath: "/TestFolder/", isDirectory: true)

		let itemMetadata = ItemMetadata(name: "TestFolder", type: .folder, size: nil, remoteParentPath: rootURL.relativePath, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: remoteURL.relativePath, isPlaceholderItem: true)
		try manager.cacheMetadata(itemMetadata)
		guard let fetchedMetadata = try manager.getCachedMetadata(for: remoteURL.relativePath) else {
			XCTFail("ItemMetadata not cached properly")
			return
		}
		XCTAssertEqual(itemMetadata, fetchedMetadata)
    }

	func testCacheMultipleEntries() throws {
		let rootURL = URL(fileURLWithPath: "/", isDirectory: true)
		let remoteFileURL = URL(fileURLWithPath: "/TestFile", isDirectory: false)
		let remoteFolderURL = URL(fileURLWithPath: "/TestFolder/", isDirectory: true)
		let itemMetadataForFile = ItemMetadata(name: "TestFile", type: .file, size: 100, remoteParentPath: rootURL.relativePath, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: remoteFileURL.relativePath, isPlaceholderItem: false)
		let itemMetadataForFolder = ItemMetadata(name: "TestFolder", type: .folder, size: nil, remoteParentPath: rootURL.relativePath, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: remoteFolderURL.relativePath, isPlaceholderItem: true)
		let metadatas = [itemMetadataForFile, itemMetadataForFolder]
		try manager.cacheMetadatas(metadatas)
		guard let fetchedMetadataForFile = try manager.getCachedMetadata(for: remoteFileURL.relativePath) else {
			XCTFail("ItemMetadata not cached properly")
			return
		}
		XCTAssertEqual(itemMetadataForFile, fetchedMetadataForFile)
		guard let fetchedMetadataForFolder = try manager.getCachedMetadata(for: remoteFolderURL.relativePath) else {
			XCTFail("ItemMetadata not cached properly")
			return
		}
		XCTAssertEqual(itemMetadataForFolder, fetchedMetadataForFolder)
	}


}
extension ItemMetadata: Comparable {
	public static func < (lhs: ItemMetadata, rhs: ItemMetadata) -> Bool {
		return lhs.name < rhs.name
	}

	public static func == (lhs: ItemMetadata, rhs: ItemMetadata) -> Bool {
		return lhs.name == rhs.name && lhs.type == rhs.type && lhs.size == rhs.size && lhs.remoteParentPath == rhs.remoteParentPath && lhs.lastModifiedDate == rhs.lastModifiedDate && lhs.statusCode == rhs.statusCode && lhs.remotePath == rhs.remotePath && lhs.isPlaceholderItem == rhs.isPlaceholderItem
	}
}
