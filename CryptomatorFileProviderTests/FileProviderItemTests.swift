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
		let metadata = ItemMetadata(id: 2, name: "test.txt", type: .file, size: 100, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isDownloaded, remotePath: remoteURL.relativePath, isPlaceholderItem: false)
		let item = FileProviderItem(metadata: metadata)
		XCTAssertEqual(NSFileProviderItemIdentifier("2"), item.itemIdentifier)
		XCTAssertEqual(NSFileProviderItemIdentifier.rootContainer, item.parentItemIdentifier)
		XCTAssertEqual("test.txt", item.filename)
		XCTAssertEqual(100, item.documentSize)
		XCTAssertTrue(item.isDownloaded)
		XCTAssertEqual("public.plain-text", item.typeIdentifier)
	}

	func testFolderItem() {
		let remoteURL = URL(fileURLWithPath: "/test Folder/", isDirectory: true)
		let metadata = ItemMetadata(id: 2, name: "test Folder", type: .folder, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isDownloaded, remotePath: remoteURL.relativePath, isPlaceholderItem: false)
		let item = FileProviderItem(metadata: metadata)
		XCTAssertEqual(NSFileProviderItemIdentifier("2"), item.itemIdentifier)
		XCTAssertEqual(NSFileProviderItemIdentifier.rootContainer, item.parentItemIdentifier)
		XCTAssertEqual("test Folder", item.filename)
		XCTAssertNil(item.documentSize)
		XCTAssertTrue(item.isDownloaded)
		XCTAssertEqual("public.folder", item.typeIdentifier)
	}

	func testUploadError() {
		let remoteURL = URL(fileURLWithPath: "/test.txt", isDirectory: false)
		let metadata = ItemMetadata(id: 2, name: "test.txt", type: .file, size: 100, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .uploadError, remotePath: remoteURL.relativePath, isPlaceholderItem: false)
		let lastFailedUploadDate = Date(timeIntervalSinceReferenceDate: 0)
		let failedUploadTask = UploadTask(correspondingItem: 2, lastFailedUploadDate: lastFailedUploadDate, uploadErrorCode: NSFileProviderError.insufficientQuota.rawValue, uploadErrorDomain: NSFileProviderErrorDomain)
		let item = FileProviderItem(metadata: metadata, uploadTask: failedUploadTask)
		XCTAssertEqual(NSFileProviderItemIdentifier("2"), item.itemIdentifier)
		XCTAssertEqual(NSFileProviderItemIdentifier.rootContainer, item.parentItemIdentifier)
		XCTAssertEqual("test.txt", item.filename)
		XCTAssertEqual(100, item.documentSize)
		XCTAssertFalse(item.isUploaded)
		XCTAssertEqual("public.plain-text", item.typeIdentifier)
		guard let actualError = item.uploadingError as NSError? else {
			XCTFail("Item has no Error")
			return
		}
		let expectedError = NSFileProviderError(.insufficientQuota) as NSError
		XCTAssertTrue(expectedError.isEqual(actualError))
	}

	func testUploadingItemRestrictsCapabilityToRead() {
		let remoteURL = URL(fileURLWithPath: "/test.txt", isDirectory: false)
		let metadata = ItemMetadata(id: 2, name: "test.txt", type: .file, size: 100, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploading, remotePath: remoteURL.relativePath, isPlaceholderItem: false)
		let item = FileProviderItem(metadata: metadata)
		XCTAssertEqual(NSFileProviderItemCapabilities.allowsReading, item.capabilities)
	}
}
