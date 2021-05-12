//
//  FileProviderDecoratorDownloadTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 17.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Promises
import XCTest
@testable import CryptomatorFileProvider

class FileProviderDecoratorDownloadTests: FileProviderDecoratorTestCase {
	func testDownloadFile() throws {
		let expectation = XCTestExpectation()
		let localURL = tmpDirectory.appendingPathComponent("localItem.txt", isDirectory: false)
		let cloudPath = CloudPath("/File 1")
		let itemMetadata = ItemMetadata(id: 3, name: "File 1", type: .file, size: 14, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
		try decorator.itemMetadataManager.cacheMetadata(itemMetadata)
		let identifier = NSFileProviderItemIdentifier(String("3"))
		decorator.downloadFile(with: identifier, to: localURL).then { _ in
			let localContent = try Data(contentsOf: localURL)
			XCTAssertEqual(self.mockedProvider.files[cloudPath.path], localContent)
			let lastModifiedDate = try self.decorator.cachedFileManager.getLastModifiedDate(for: 3)
			XCTAssertNotNil(lastModifiedDate)
			XCTAssertEqual(self.mockedProvider.lastModifiedDate[cloudPath.path], lastModifiedDate)
			guard let fetchedMetadata = try self.decorator.itemMetadataManager.getCachedMetadata(for: 3) else {
				XCTFail("No ItemMetadata found")
				return
			}
			XCTAssertEqual(ItemStatus.isUploaded, fetchedMetadata.statusCode)
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 2.0)
	}

	func testDownloadFileRejectIfIdentifierHasNoCorrespondingItemInDB() throws {
		let expectation = XCTestExpectation()
		let localURL = tmpDirectory.appendingPathComponent("item not in DB.txt", isDirectory: false)

		let identifier = NSFileProviderItemIdentifier(String("3"))
		decorator.downloadFile(with: identifier, to: localURL).then { _ in
			XCTFail("Promise should not fulfill for nonexistent File")
		}.catch { error in
			let nsError = error as NSError
			guard nsError.domain == NSFileProviderErrorDomain, nsError.code == NSFileProviderError.noSuchItem.rawValue else {
				XCTFail("Promise rejected but with the wrong error: \(error)")
				return
			}
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testDownloadFileFailIfProviderRejectWithItemNotFound() throws {
		let expectation = XCTestExpectation()
		let localURL = tmpDirectory.appendingPathComponent("itemNotFound.txt", isDirectory: false)
		let cloudPath = CloudPath("/itemNotFound.txt")
		let itemMetadata = ItemMetadata(id: 3, name: "itemNotFound.txt", type: .file, size: 14, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
		try decorator.itemMetadataManager.cacheMetadata(itemMetadata)
		let identifier = NSFileProviderItemIdentifier(String("3"))
		decorator.downloadFile(with: identifier, to: localURL).then { _ in
			XCTFail("Promise should not fulfill for nonexistent File")
		}.catch { error in
			let nsError = error as NSError
			guard nsError.domain == NSFileProviderErrorDomain, nsError.code == NSFileProviderError.noSuchItem.rawValue else {
				XCTFail("Promise rejected but with the wrong error: \(error)")
				return
			}
			guard let cachedMetadata = try? self.decorator.itemMetadataManager.getCachedMetadata(for: 3) else {
				XCTFail("No ItemMetadata found")
				return
			}
			XCTAssertEqual(ItemStatus.downloadError, cachedMetadata.statusCode)
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testHasPossibleVersioningConflictForItemWithFailedUploadAfterDownload() throws {
		let metadata = ItemMetadata(name: "test.txt", type: .file, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .uploadError, cloudPath: CloudPath("/test.txt"), isPlaceholderItem: false, isCandidateForCacheCleanup: false)
		try decorator.itemMetadataManager.cacheMetadata(metadata)
		_ = try decorator.uploadTaskManager.createNewTask(for: metadata.id!)
		let error = NSFileProviderError(.serverUnreachable)
		try decorator.uploadTaskManager.updateTask(with: metadata.id!, lastFailedUploadDate: Date.distantFuture, uploadErrorCode: error.errorCode, uploadErrorDomain: NSFileProviderError.errorDomain)
		let localURLForItem = tmpDirectory.appendingPathComponent("/FileProviderItemIdentifier/test.txt")
		try decorator.cachedFileManager.cacheLocalFileInfo(for: metadata.id!, localURL: localURLForItem, lastModifiedDate: nil)
		let item = FileProviderItem(metadata: metadata)
		let hasVersioningConflict = try decorator.hasPossibleVersioningConflictForItem(withIdentifier: item.itemIdentifier)
		XCTAssertTrue(hasVersioningConflict)
	}

	func testHasPossibleVersioningConflictForUploadingItem() throws {
		let metadata = ItemMetadata(name: "test.txt", type: .file, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .uploadError, cloudPath: CloudPath("/test.txt"), isPlaceholderItem: false, isCandidateForCacheCleanup: false)
		try decorator.itemMetadataManager.cacheMetadata(metadata)
		_ = try decorator.uploadTaskManager.createNewTask(for: metadata.id!)
		let localURLForItem = tmpDirectory.appendingPathComponent("/FileProviderItemIdentifier/test.txt")
		try decorator.cachedFileManager.cacheLocalFileInfo(for: metadata.id!, localURL: localURLForItem, lastModifiedDate: nil)
		let item = FileProviderItem(metadata: metadata)
		let hasVersioningConflict = try decorator.hasPossibleVersioningConflictForItem(withIdentifier: item.itemIdentifier)
		XCTAssertTrue(hasVersioningConflict)
	}

	func testHasNoVersioningConflictForItemWithoudPendingUploadTask() throws {
		let metadata = ItemMetadata(name: "test.txt", type: .file, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .uploadError, cloudPath: CloudPath("/test.txt"), isPlaceholderItem: false, isCandidateForCacheCleanup: false)
		try decorator.itemMetadataManager.cacheMetadata(metadata)
		let localURLForItem = tmpDirectory.appendingPathComponent("/FileProviderItemIdentifier/test.txt")
		try decorator.cachedFileManager.cacheLocalFileInfo(for: metadata.id!, localURL: localURLForItem, lastModifiedDate: nil)
		let item = FileProviderItem(metadata: metadata)
		let hasVersioningConflict = try decorator.hasPossibleVersioningConflictForItem(withIdentifier: item.itemIdentifier)
		XCTAssertFalse(hasVersioningConflict)
	}

	func testDownloadFileReplaceExisting() throws {
		let expectation = XCTestExpectation()
		let localURL = tmpDirectory.appendingPathComponent("localItem.txt", isDirectory: false)
		let existingLocalContent = "Old Local FileContent"
		try existingLocalContent.write(to: localURL, atomically: true, encoding: .utf8)
		let existingLocalContentData = try Data(contentsOf: localURL)
		let cloudPath = CloudPath("/File 1")
		let itemMetadata = ItemMetadata(id: 3, name: "File 1", type: .file, size: 14, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
		try decorator.itemMetadataManager.cacheMetadata(itemMetadata)
		let identifier = NSFileProviderItemIdentifier(String("3"))
		decorator.downloadFile(with: identifier, to: localURL, replaceExisting: true).then { _ in
			let localContent = try Data(contentsOf: localURL)
			XCTAssertEqual(self.mockedProvider.files[cloudPath.path], localContent)
			XCTAssertNotEqual(existingLocalContentData, localContent)
			let lastModifiedDate = try self.decorator.cachedFileManager.getLastModifiedDate(for: 3)
			XCTAssertNotNil(lastModifiedDate)
			XCTAssertEqual(self.mockedProvider.lastModifiedDate[cloudPath.path], lastModifiedDate)
			guard let fetchedMetadata = try self.decorator.itemMetadataManager.getCachedMetadata(for: 3) else {
				XCTFail("No ItemMetadata found")
				return
			}
			XCTAssertEqual(ItemStatus.isUploaded, fetchedMetadata.statusCode)
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testDownloadPostProcessingForReplaceExisting() throws {
		let cloudPath = CloudPath("/File 1")
		let itemMetadata = ItemMetadata(id: 3, name: "File 1", type: .file, size: 14, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
		try decorator.itemMetadataManager.cacheMetadata(itemMetadata)

		let localURL = tmpDirectory.appendingPathComponent("localItem.txt", isDirectory: false)
		let existingLocalContent = "Old Local FileContent"
		try existingLocalContent.write(to: localURL, atomically: true, encoding: .utf8)

		let downloadDestination = tmpDirectory.appendingPathComponent("localItem-12345.txt", isDirectory: false)
		let downloadedContent = "Downloaded FileContent"
		try downloadedContent.write(to: downloadDestination, atomically: true, encoding: .utf8)

		let lastModifiedDate = Date(timeIntervalSince1970: 0)

		let item = try decorator.downloadPostProcessing(for: itemMetadata, lastModifiedDate: lastModifiedDate, localURL: localURL, downloadDestination: downloadDestination)
		XCTAssert(FileManager.default.fileExists(atPath: localURL.path))
		XCTAssertFalse(FileManager.default.fileExists(atPath: downloadDestination.path))
		let localURLContent = try String(contentsOf: localURL, encoding: .utf8)
		XCTAssertEqual(downloadedContent, localURLContent)
		XCTAssertEqual(localURL, item.localURL)
		XCTAssert(item.newestVersionLocallyCached)
		XCTAssertEqual(itemMetadata, item.metadata)

		guard let localCachedFileInfo = try decorator.cachedFileManager.getLocalCachedFileInfo(for: 3) else {
			XCTFail("No LocalCachedFileInfo found")
			return
		}
		XCTAssertEqual(lastModifiedDate, localCachedFileInfo.lastModifiedDate)
		XCTAssertEqual(localURL, localCachedFileInfo.localURL)
	}

	func testDownloadPostProcessingForNewFile() throws {
		let cloudPath = CloudPath("/File 1")
		let itemMetadata = ItemMetadata(id: 3, name: "File 1", type: .file, size: 14, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
		try decorator.itemMetadataManager.cacheMetadata(itemMetadata)

		let localURL = tmpDirectory.appendingPathComponent("localItem.txt", isDirectory: false)
		let downloadedContent = "Downloaded FileContent"
		try downloadedContent.write(to: localURL, atomically: true, encoding: .utf8)

		let lastModifiedDate = Date(timeIntervalSince1970: 0)

		let item = try decorator.downloadPostProcessing(for: itemMetadata, lastModifiedDate: lastModifiedDate, localURL: localURL, downloadDestination: localURL)
		XCTAssert(FileManager.default.fileExists(atPath: localURL.path))
		let localURLContent = try String(contentsOf: localURL, encoding: .utf8)
		XCTAssertEqual(downloadedContent, localURLContent)
		XCTAssertEqual(localURL, item.localURL)
		XCTAssert(item.newestVersionLocallyCached)
		XCTAssertEqual(itemMetadata, item.metadata)

		guard let localCachedFileInfo = try decorator.cachedFileManager.getLocalCachedFileInfo(for: 3) else {
			XCTFail("No LocalCachedFileInfo found")
			return
		}
		XCTAssertEqual(lastModifiedDate, localCachedFileInfo.lastModifiedDate)
		XCTAssertEqual(localURL, localCachedFileInfo.localURL)
	}
}
