//
//  FileProviderItemTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 01.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import MobileCoreServices
import XCTest
@testable import CryptomatorFileProvider
class FileProviderItemTests: XCTestCase {
	override func setUpWithError() throws {}

	override func tearDownWithError() throws {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
	}

	func testRootItem() {
		let remoteURL = URL(fileURLWithPath: "/", isDirectory: true)
		let metadata = ItemMetadata(id: MetadataManager.rootContainerId, name: "root", type: .folder, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isDownloaded, remotePath: remoteURL.relativePath, isPlaceholderItem: false)
		let item = FileProviderItem(metadata: metadata)
		XCTAssertEqual(NSFileProviderItemIdentifier.rootContainer, item.itemIdentifier)
		XCTAssertEqual(NSFileProviderItemIdentifier.rootContainer, item.parentItemIdentifier)
		XCTAssertEqual("public.folder", item.typeIdentifier)
	}

	func testFileItem() {
		let remoteURL = URL(fileURLWithPath: "/test.txt", isDirectory: false)
		let metadata = ItemMetadata(id: 2, name: "test", type: .file, size: 100, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isDownloaded, remotePath: remoteURL.relativePath, isPlaceholderItem: false)
		let item = FileProviderItem(metadata: metadata)
		XCTAssertEqual(NSFileProviderItemIdentifier("2"), item.itemIdentifier)
		XCTAssertEqual(NSFileProviderItemIdentifier.rootContainer, item.parentItemIdentifier)
		XCTAssertEqual("test", item.filename)
		XCTAssertEqual(100, item.documentSize)
		XCTAssertTrue(item.isDownloaded)
		XCTAssertEqual("public.text", item.typeIdentifier)
	}
}
