//
//  DownloadTaskExecutorTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 25.05.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import GRDB
import Promises
import XCTest
@testable import CryptomatorFileProvider
class DownloadTaskExecutorTests: CloudTaskExecutorTestCase {
	func testDownloadFile() throws {
		let expectation = XCTestExpectation()
		let localURL = tmpDirectory.appendingPathComponent("localItem.txt", isDirectory: false)
		let cloudPath = CloudPath("/File 1")
		let itemID: Int64 = 2

		let itemMetadata = ItemMetadata(id: itemID, name: "File 1", type: .file, size: 14, parentId: metadataManagerMock.getRootContainerID(), lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)

		let downloadTask = DownloadTask(replaceExisting: false, localURL: localURL, itemMetadata: itemMetadata)

		let taskExecutor = DownloadTaskExecutor(provider: cloudProviderMock, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock)

		taskExecutor.execute(task: downloadTask).then { _ in
			let localContent = try Data(contentsOf: localURL)
			XCTAssertEqual(self.cloudProviderMock.files[cloudPath.path], localContent)
			let localCachedFileInfo = self.cachedFileManagerMock.cachedLocalFileInfo[itemID]
			XCTAssertNotNil(localCachedFileInfo)
			let lastModifiedDate = localCachedFileInfo?.lastModifiedDate
			XCTAssertNotNil(lastModifiedDate)
			XCTAssertEqual(self.cloudProviderMock.lastModifiedDate[cloudPath.path], lastModifiedDate)
			XCTAssertEqual(1, self.metadataManagerMock.updatedMetadata.count)
			XCTAssertEqual(ItemStatus.isUploaded, self.metadataManagerMock.updatedMetadata[0].statusCode)
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testDownloadFileFailWithSameErrorAsProvider() throws {
		let expectation = XCTestExpectation()
		let localURL = tmpDirectory.appendingPathComponent("itemNotFound.txt", isDirectory: false)
		let cloudPath = CloudPath("/itemNotFound.txt")

		let itemMetadata = ItemMetadata(id: 3, name: "itemNotFound.txt", type: .file, size: 14, parentId: metadataManagerMock.getRootContainerID(), lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
		let errorCloudProviderMock = CloudProviderErrorMock()
		errorCloudProviderMock.fetchItemMetadataResponse = { _ in
			Promise(CloudTaskTestError.correctPassthrough)
		}
		errorCloudProviderMock.downloadFileResponse = { _, _ in
			Promise(CloudTaskTestError.correctPassthrough)
		}

		let downloadTask = DownloadTask(replaceExisting: false, localURL: localURL, itemMetadata: itemMetadata)

		let taskExecutor = DownloadTaskExecutor(provider: errorCloudProviderMock, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock)

		taskExecutor.execute(task: downloadTask).then { _ in
			XCTFail("Promise should not fulfill if the provider fails with an error")
		}.catch { error in
			guard case CloudTaskTestError.correctPassthrough = error else {
				XCTFail("Promise rejected but with the wrong error: \(error)")
				return
			}
			XCTAssert(self.metadataManagerMock.cachedMetadata.isEmpty, "Unexpected change of cached metadata.")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testDownloadFileReplaceExisting() throws {
		let expectation = XCTestExpectation()
		let localURL = tmpDirectory.appendingPathComponent("localItem.txt", isDirectory: false)
		let existingLocalContent = "Old Local FileContent"
		try existingLocalContent.write(to: localURL, atomically: true, encoding: .utf8)
		let existingLocalContentData = try Data(contentsOf: localURL)
		let cloudPath = CloudPath("/File 1")
		let itemID: Int64 = 2
		let itemMetadata = ItemMetadata(id: itemID, name: "File 1", type: .file, size: 14, parentId: metadataManagerMock.getRootContainerID(), lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)

		let downloadTask = DownloadTask(replaceExisting: true, localURL: localURL, itemMetadata: itemMetadata)

		let taskExecutor = DownloadTaskExecutor(provider: cloudProviderMock, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock)

		taskExecutor.execute(task: downloadTask).then { _ in
			let localContent = try Data(contentsOf: localURL)
			XCTAssertEqual(self.cloudProviderMock.files[cloudPath.path], localContent)
			XCTAssertNotEqual(existingLocalContentData, localContent)
			let cachedLocalFileInfo = self.cachedFileManagerMock.cachedLocalFileInfo[itemID]
			XCTAssertNotNil(cachedLocalFileInfo)
			let lastModifiedDate = cachedLocalFileInfo?.lastModifiedDate
			XCTAssertNotNil(lastModifiedDate)
			XCTAssertEqual(self.cloudProviderMock.lastModifiedDate[cloudPath.path], lastModifiedDate)

			XCTAssertEqual(1, self.metadataManagerMock.updatedMetadata.count)
			XCTAssertEqual(ItemStatus.isUploaded, self.metadataManagerMock.updatedMetadata[0].statusCode)
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testDownloadPostProcessingForReplaceExisting() throws {
		let cloudPath = CloudPath("/File 1")
		let itemID: Int64 = 2
		let itemMetadata = ItemMetadata(id: itemID, name: "File 1", type: .file, size: 14, parentId: metadataManagerMock.getRootContainerID(), lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)

		let localURL = tmpDirectory.appendingPathComponent("localItem.txt", isDirectory: false)
		let existingLocalContent = "Old Local FileContent"
		try existingLocalContent.write(to: localURL, atomically: true, encoding: .utf8)

		let downloadDestination = tmpDirectory.appendingPathComponent("localItem-12345.txt", isDirectory: false)
		let downloadedContent = "Downloaded FileContent"
		try downloadedContent.write(to: downloadDestination, atomically: true, encoding: .utf8)

		let lastModifiedDate = Date(timeIntervalSince1970: 0)

		let taskExecutor = DownloadTaskExecutor(provider: cloudProviderMock, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock)

		let item = try taskExecutor.downloadPostProcessing(for: itemMetadata, lastModifiedDate: lastModifiedDate, localURL: localURL, downloadDestination: downloadDestination)
		XCTAssert(FileManager.default.fileExists(atPath: localURL.path))
		XCTAssertFalse(FileManager.default.fileExists(atPath: downloadDestination.path))
		let localURLContent = try String(contentsOf: localURL, encoding: .utf8)
		XCTAssertEqual(downloadedContent, localURLContent)
		XCTAssertEqual(localURL, item.localURL)
		XCTAssert(item.newestVersionLocallyCached)
		XCTAssertEqual(itemMetadata, item.metadata)

		guard let localCachedFileInfo = try cachedFileManagerMock.getLocalCachedFileInfo(for: itemID) else {
			XCTFail("No LocalCachedFileInfo found")
			return
		}
		XCTAssertEqual(lastModifiedDate, localCachedFileInfo.lastModifiedDate)
		XCTAssertEqual(localURL, localCachedFileInfo.localURL)
	}

	func testDownloadPostProcessingForNewFile() throws {
		let cloudPath = CloudPath("/File 1")
		let itemID: Int64 = 2
		let itemMetadata = ItemMetadata(id: itemID, name: "File 1", type: .file, size: 14, parentId: metadataManagerMock.getRootContainerID(), lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)

		let localURL = tmpDirectory.appendingPathComponent("localItem.txt", isDirectory: false)
		let downloadedContent = "Downloaded FileContent"
		try downloadedContent.write(to: localURL, atomically: true, encoding: .utf8)

		let lastModifiedDate = Date(timeIntervalSince1970: 0)

		let taskExecutor = DownloadTaskExecutor(provider: cloudProviderMock, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock)

		let item = try taskExecutor.downloadPostProcessing(for: itemMetadata, lastModifiedDate: lastModifiedDate, localURL: localURL, downloadDestination: localURL)
		XCTAssert(FileManager.default.fileExists(atPath: localURL.path))
		let localURLContent = try String(contentsOf: localURL, encoding: .utf8)
		XCTAssertEqual(downloadedContent, localURLContent)
		XCTAssertEqual(localURL, item.localURL)
		XCTAssert(item.newestVersionLocallyCached)
		XCTAssertEqual(itemMetadata, item.metadata)

		guard let localCachedFileInfo = try cachedFileManagerMock.getLocalCachedFileInfo(for: itemID) else {
			XCTFail("No LocalCachedFileInfo found")
			return
		}
		XCTAssertEqual(lastModifiedDate, localCachedFileInfo.lastModifiedDate)
		XCTAssertEqual(localURL, localCachedFileInfo.localURL)
	}
}
