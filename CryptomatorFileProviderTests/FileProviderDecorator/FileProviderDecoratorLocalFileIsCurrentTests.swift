//
//  FileProviderDecoratorLocalFileIsCurrentTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 16.12.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Promises
import XCTest
@testable import CryptomatorFileProvider
class FileProviderDecoratorLocalFileIsCurrentTests: FileProviderDecoratorTestCase {
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

	func testLocalFileIsCurrentForNoInternetConnection() throws {
		mockedProvider.everyOperationShouldFailWithError = CloudProviderError.noInternetConnection
		let expectation = XCTestExpectation()
		let cloudPath = CloudPath("/File")
		let metadata = ItemMetadata(name: "File", type: .file, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
		try decorator.itemMetadataManager.cacheMetadata(metadata)
		guard let id = metadata.id else {
			XCTFail("ItemMetadata has no id")
			return
		}
		let identifier = NSFileProviderItemIdentifier("\(id)")
		decorator.localFileIsCurrent(with: identifier).then { isCurrent in
			XCTAssertTrue(isCurrent)
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
		wait(for: [expectation], timeout: 1.0)
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
		wait(for: [expectation], timeout: 1.0)
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
		wait(for: [expectation], timeout: 1.0)
	}
}
