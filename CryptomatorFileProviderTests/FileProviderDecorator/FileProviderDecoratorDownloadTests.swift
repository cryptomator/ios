//
//  FileProviderDecoratorDownloadTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 17.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import Promises
import XCTest
@testable import CryptomatorFileProvider
class FileProviderDecoratorDownloadTests: FileProviderDecoratorTestCase {
	func testLocalFileIsCurrentForUploadingFile() throws {
		let expectation = XCTestExpectation()
		let cloudPath = CloudPath("/TestUploadFile")
		let uploadingItemMetadata = ItemMetadata(name: "TestUploadFile", type: .file, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploading, cloudPath: cloudPath, isPlaceholderItem: false)
		try decorator.itemMetadataManager.cacheMetadata(uploadingItemMetadata)
		guard let id = uploadingItemMetadata.id else {
			XCTFail("uploadingItemMetadata has no id")
			return
		}
		decorator.localFileIsCurrent(with: NSFileProviderItemIdentifier(String(id))).then { result in
			XCTAssert(result)
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testLocalFileIsCurrentForCloudLastModifiedDateIsNil() throws {
		let expectation = XCTestExpectation()
		let mockedDecorator = decorator as? FileProviderDecoratorMock
		mockedDecorator?.internalProvider.setLastModifiedDate(nil, for: CloudPath("/File 1"))

		let localURL = tmpDirectory.appendingPathComponent("File 1", isDirectory: false)
		let itemIdentifier = NSFileProviderItemIdentifier("3")
		decorator.enumerateItems(for: .rootContainer, withPageToken: nil).then { _ in
			self.decorator.downloadFile(with: itemIdentifier, to: localURL)
		}.then { _ in
			self.decorator.localFileIsCurrent(with: itemIdentifier)
		}.then { result in
			XCTAssertFalse(result)
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 2.0)
	}

	func testLocalFileIsCurrentForNewerVersionInCloud() throws {
		let expectation = XCTestExpectation()
		let itemIdentifier = NSFileProviderItemIdentifier("3")

		let localURL = tmpDirectory.appendingPathComponent("File 1", isDirectory: false)
		decorator.enumerateItems(for: .rootContainer, withPageToken: nil).then { _ in
			self.decorator.downloadFile(with: itemIdentifier, to: localURL)
		}.then { _ -> Promise<Bool> in
			let mockedDecorator = self.decorator as? FileProviderDecoratorMock
			mockedDecorator?.internalProvider.setLastModifiedDate(Date(timeIntervalSince1970: 100), for: CloudPath("/File 1"))
			return self.decorator.localFileIsCurrent(with: itemIdentifier)
		}.then { result in
			XCTAssertFalse(result)
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 2.0)
	}

	func testLocalFileIsCurrentForCloudLastModifiedDateIsEqual() throws {
		let expectation = XCTestExpectation()

		let localURL = tmpDirectory.appendingPathComponent("File 1", isDirectory: false)
		let itemIdentifier = NSFileProviderItemIdentifier("3")
		decorator.enumerateItems(for: .rootContainer, withPageToken: nil).then { _ in
			self.decorator.downloadFile(with: itemIdentifier, to: localURL)
		}.then { _ in
			self.decorator.localFileIsCurrent(with: itemIdentifier)
		}.then { result in
			XCTAssert(result)
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 2.0)
	}

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
}
