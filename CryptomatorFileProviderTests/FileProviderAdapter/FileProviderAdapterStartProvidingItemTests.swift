//
//  FileProviderAdapterStartProvidingItemTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 08.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Promises
import XCTest
@testable import CryptomatorFileProvider
class FileProviderAdapterStartProvidingItemTests: FileProviderAdapterTestCase {
	func testStartProvidingItemNoLocalVersion() throws {
		let expectation = XCTestExpectation()
		let itemID: Int64 = 2
		let cloudPath = CloudPath("/File 1")
		let itemMetadata = ItemMetadata(id: 2, name: "File 1", type: .file, size: 14, parentId: metadataManagerMock.getRootContainerID(), lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)

		try metadataManagerMock.cacheMetadata(itemMetadata)
		let itemDirectory = tmpDirectory.appendingPathComponent("/\(itemID)")
		try FileManager.default.createDirectory(at: itemDirectory, withIntermediateDirectories: false)
		let url = itemDirectory.appendingPathComponent("File 1")
		XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
		adapter.startProvidingItem(at: url) { error in
			XCTAssertNil(error)
			XCTAssert(FileManager.default.fileExists(atPath: url.path))

			let localContent = try? Data(contentsOf: url)
			XCTAssertEqual(self.cloudProviderMock.files[cloudPath.path], localContent)

			let localCachedFileInfo = self.cachedFileManagerMock.cachedLocalFileInfo[itemID]
			XCTAssertNotNil(localCachedFileInfo)
			let lastModifiedDate = localCachedFileInfo?.lastModifiedDate
			XCTAssertNotNil(lastModifiedDate)
			XCTAssertEqual(self.cloudProviderMock.lastModifiedDate[cloudPath.path], lastModifiedDate)
			XCTAssertEqual(1, self.metadataManagerMock.updatedMetadata.count)
			XCTAssertEqual(ItemStatus.isUploaded, self.metadataManagerMock.updatedMetadata[0].statusCode)
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testStartProvidingItemWithUpToDateLocalVersion() throws {
		let expectation = XCTestExpectation()
		let itemID: Int64 = 2
		let cloudPath = CloudPath("/File 1")
		let itemMetadata = ItemMetadata(id: 2, name: "File 1", type: .file, size: 14, parentId: metadataManagerMock.getRootContainerID(), lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)

		try metadataManagerMock.cacheMetadata(itemMetadata)
		let itemDirectory = tmpDirectory.appendingPathComponent("/\(itemID)")
		try FileManager.default.createDirectory(at: itemDirectory, withIntermediateDirectories: false)
		let url = itemDirectory.appendingPathComponent("File 1")
		try String(data: cloudProviderMock.files[cloudPath.path]!!, encoding: .utf8)?.write(to: url, atomically: true, encoding: .utf8)
		let lastModifiedDateInCloud = cloudProviderMock.lastModifiedDate[cloudPath.path] ?? nil
		try cachedFileManagerMock.cacheLocalFileInfo(for: itemID, localURL: url, lastModifiedDate: lastModifiedDateInCloud)
		XCTAssert(FileManager.default.fileExists(atPath: url.path))
		adapter.startProvidingItem(at: url) { error in
			XCTAssertNil(error)
			XCTAssert(FileManager.default.fileExists(atPath: url.path))

			let localContent = try? Data(contentsOf: url)
			XCTAssertEqual(self.cloudProviderMock.files[cloudPath.path], localContent)

			let localCachedFileInfo = self.cachedFileManagerMock.cachedLocalFileInfo[itemID]
			XCTAssertNotNil(localCachedFileInfo)
			let lastModifiedDate = localCachedFileInfo?.lastModifiedDate
			XCTAssertNotNil(lastModifiedDate)
			XCTAssertNotNil(lastModifiedDate)
			XCTAssertEqual(self.cloudProviderMock.lastModifiedDate[cloudPath.path], lastModifiedDate)
			XCTAssert(self.metadataManagerMock.updatedMetadata.isEmpty, "Unexpected change of cached metadata.")
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testStartProvidingItemWithOlderLocalVersion() throws {
		let expectation = XCTestExpectation()
		let itemID: Int64 = 2
		let cloudPath = CloudPath("/File 1")
		let itemMetadata = ItemMetadata(id: 2, name: "File 1", type: .file, size: 14, parentId: metadataManagerMock.getRootContainerID(), lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)

		try metadataManagerMock.cacheMetadata(itemMetadata)
		let itemDirectory = tmpDirectory.appendingPathComponent("/\(itemID)")
		try FileManager.default.createDirectory(at: itemDirectory, withIntermediateDirectories: false)
		let url = itemDirectory.appendingPathComponent("File 1")
		try "Old file content".write(to: url, atomically: true, encoding: .utf8)
		// Enforce newer lastModifiedDate in cloud
		cloudProviderMock.lastModifiedDate[cloudPath.path] = Date(timeIntervalSince1970: 10)
		// Cache older lastModifiedDate for local version
		try cachedFileManagerMock.cacheLocalFileInfo(for: itemID, localURL: url, lastModifiedDate: Date(timeIntervalSince1970: 0))
		XCTAssert(FileManager.default.fileExists(atPath: url.path))
		adapter.startProvidingItem(at: url) { error in
			XCTAssertNil(error)
			XCTAssert(FileManager.default.fileExists(atPath: url.path))

			let localContent = try? Data(contentsOf: url)
			XCTAssertEqual(self.cloudProviderMock.files[cloudPath.path], localContent)

			let localCachedFileInfo = self.cachedFileManagerMock.cachedLocalFileInfo[itemID]
			XCTAssertNotNil(localCachedFileInfo)
			let lastModifiedDate = localCachedFileInfo?.lastModifiedDate
			XCTAssertNotNil(lastModifiedDate)
			XCTAssertNotNil(lastModifiedDate)
			XCTAssertEqual(self.cloudProviderMock.lastModifiedDate[cloudPath.path], lastModifiedDate)
			XCTAssertEqual(1, self.metadataManagerMock.updatedMetadata.count)
			XCTAssertEqual(ItemStatus.isUploaded, self.metadataManagerMock.updatedMetadata[0].statusCode)
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	// swiftlint:disable:next function_body_length
	func testStartProvidingItemWithConflictingLocalVersion() throws {
		let expectation = XCTestExpectation()
		let rootItemMetadata = ItemMetadata(id: metadataManagerMock.getRootContainerID(), name: "Home", type: .folder, size: nil, parentId: metadataManagerMock.getRootContainerID(), lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/"), isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(rootItemMetadata)

		// Create local folder for conflicting item
		let conflictingItemDirectory = tmpDirectory.appendingPathComponent("3")
		try FileManager.default.createDirectory(at: conflictingItemDirectory, withIntermediateDirectories: false)
		localURLProviderMock.response = { identifier in
			XCTAssertEqual(NSFileProviderItemIdentifier("3"), identifier)
			guard let item = try? self.adapter.item(for: identifier) else {
				return nil
			}
			return conflictingItemDirectory.appendingPathComponent(item.filename, isDirectory: false)
		}

		let itemID: Int64 = 2
		let cloudPath = CloudPath("/File 1")
		let itemMetadata = ItemMetadata(id: 2, name: "File 1", type: .file, size: 14, parentId: metadataManagerMock.getRootContainerID(), lastModifiedDate: Date(timeIntervalSince1970: 0), statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)

		try metadataManagerMock.cacheMetadata(itemMetadata)
		let itemDirectory = tmpDirectory.appendingPathComponent("\(itemID)")
		try FileManager.default.createDirectory(at: itemDirectory, withIntermediateDirectories: false)
		let url = itemDirectory.appendingPathComponent("File 1")
		try "Local changed file content".write(to: url, atomically: true, encoding: .utf8)

		// Simulate a failed upload
		let localCachedFileInfo = LocalCachedFileInfo(lastModifiedDate: nil, correspondingItem: itemID, localLastModifiedDate: Date(timeIntervalSince1970: 0), localURL: url)
		cachedFileManagerMock.cachedLocalFileInfo[itemID] = localCachedFileInfo
		let uploadTaskRecord = UploadTaskRecord(correspondingItem: itemID, lastFailedUploadDate: Date(), uploadErrorCode: NSFileProviderError(.serverUnreachable).errorCode, uploadErrorDomain: NSFileProviderErrorDomain)
		uploadTaskManagerMock.uploadTasks[itemID] = uploadTaskRecord

		// Simulate a change of the item in the cloud
		cloudProviderMock.lastModifiedDate[cloudPath.path] = Date(timeIntervalSince1970: 10)

		let adapter = FileProviderAdapter(uploadTaskManager: uploadTaskManagerMock, cachedFileManager: cachedFileManagerMock, itemMetadataManager: metadataManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, scheduler: WorkFlowSchedulerStartProvidingItemMock(), provider: cloudProviderMock, localURLProvider: localURLProviderMock)
		adapter.startProvidingItem(at: url) { error in
			XCTAssertNil(error)
			XCTAssertEqual(1, self.uploadTaskManagerMock.uploadTasks.count)
			guard let uploadTaskRecord = self.uploadTaskManagerMock.uploadTasks[3] else {
				XCTFail("uploadTaskRecord is nil")
				return
			}
			XCTAssertEqual(3, uploadTaskRecord.correspondingItem)
			XCTAssertNil(uploadTaskRecord.failedWithError)
			XCTAssertNil(uploadTaskRecord.lastFailedUploadDate)
			XCTAssertNil(uploadTaskRecord.uploadErrorCode)
			XCTAssertNil(uploadTaskRecord.uploadErrorDomain)

			guard let localCachedFileInfo = self.cachedFileManagerMock.cachedLocalFileInfo[3] else {
				XCTFail("localCachedFileInfo is nil")
				return
			}
			XCTAssertEqual(3, localCachedFileInfo.correspondingItem)
			XCTAssert(localCachedFileInfo.localURL.path.hasPrefix(conflictingItemDirectory.path))
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	class WorkFlowSchedulerStartProvidingItemMock: WorkflowScheduler {
		override func schedule<T>(_ workflow: Workflow<T>) -> Promise<T> {
			// Ignore UploadTasks to test the conflicting local version DB entries
			if workflow.task is UploadTask {
				return Promise(MockError.notMocked)
			}
			return super.schedule(workflow)
		}
	}
}
