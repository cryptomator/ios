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
		let remoteURL = URL(fileURLWithPath: "/TestUploadFile", isDirectory: false)
		let uploadingItemMetadata = ItemMetadata(name: "TestUploadFile", type: .file, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploading, remotePath: remoteURL.relativePath, isPlaceholderItem: false)
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
		mockedDecorator?.internalProvider.setLastModifiedDate(nil, for: URL(fileURLWithPath: "/File 1", isDirectory: false))

		let localURL = tmpDirectory.appendingPathComponent("File 1", isDirectory: false)
		let itemIdentifier = NSFileProviderItemIdentifier("3")
		decorator.fetchItemList(for: .rootContainer, withPageToken: nil).then { _ in
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
		decorator.fetchItemList(for: .rootContainer, withPageToken: nil).then { _ in
			self.decorator.downloadFile(with: itemIdentifier, to: localURL)
		}.then { _ -> Promise<Bool> in
			let mockedDecorator = self.decorator as? FileProviderDecoratorMock
			mockedDecorator?.internalProvider.setLastModifiedDate(Date(timeIntervalSince1970: 100), for: URL(fileURLWithPath: "/File 1", isDirectory: false))
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
		decorator.fetchItemList(for: .rootContainer, withPageToken: nil).then { _ in
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
		let remoteURL = URL(fileURLWithPath: "/File 1", isDirectory: false)
		let itemMetadata = ItemMetadata(id: 3, name: "File 1", type: .file, size: 14, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: remoteURL.relativePath, isPlaceholderItem: false)
		try decorator.itemMetadataManager.cacheMetadata(itemMetadata)
		let identifier = NSFileProviderItemIdentifier(String("3"))
		decorator.downloadFile(with: identifier, to: localURL).then {
			let localContent = try Data(contentsOf: localURL)
			XCTAssertEqual(self.mockedProvider.files[remoteURL.path], localContent)
			let lastModifiedDate = try self.decorator.cachedFileManager.getLastModifiedDate(for: 3)
			XCTAssertNotNil(lastModifiedDate)
			XCTAssertEqual(self.mockedProvider.lastModifiedDate[remoteURL.path], lastModifiedDate)
			guard let fetchedMetadata = try self.decorator.itemMetadataManager.getCachedMetadata(for: 3) else {
				XCTFail("No ItemMetadata found")
				return
			}
			XCTAssertEqual(ItemStatus.isDownloaded, fetchedMetadata.statusCode)
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 2.0)
	}

	func testDownloadFileFailIfProviderRejectWithItemNotFound() throws {
		let expectation = XCTestExpectation()
		let localURL = tmpDirectory.appendingPathComponent("itemNotFound.txt", isDirectory: false)
		let remoteURL = URL(fileURLWithPath: "/itemNotFound.txt", isDirectory: false)
		let itemMetadata = ItemMetadata(id: 3, name: "itemNotFound.txt", type: .file, size: 14, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: remoteURL.relativePath, isPlaceholderItem: false)
		try decorator.itemMetadataManager.cacheMetadata(itemMetadata)
		let identifier = NSFileProviderItemIdentifier(String("3"))
		decorator.downloadFile(with: identifier, to: localURL).then {
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
}
