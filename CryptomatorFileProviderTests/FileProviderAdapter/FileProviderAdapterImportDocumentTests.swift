//
//  FileProviderAdapterImportDocumentTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 05.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation
import Promises
import XCTest
@testable import CryptomatorCommonCore
@testable import CryptomatorFileProvider

class FileProviderAdapterImportDocumentTests: FileProviderAdapterTestCase {
	// MARK: LocalItemImport

	func testLocalItemImport() throws {
		let itemID: Int64 = 2
		let expectedFileURL = tmpDirectory.appendingPathComponent("/\(itemID)/ItemToBeImported.txt")
		localURLProviderMock.response = { itemIdentifier in
			XCTAssertEqual(NSFileProviderItemIdentifier("\(itemID)"), itemIdentifier)
			return expectedFileURL
		}
		let fileURL = tmpDirectory.appendingPathComponent("ItemToBeImported.txt", isDirectory: false)
		let fileContent = "TestContent"
		try fileContent.write(to: fileURL, atomically: true, encoding: .utf8)
		let rootItemMetadata = ItemMetadata(id: metadataManagerMock.getRootContainerID(), name: "Home", type: .folder, size: nil, parentID: metadataManagerMock.getRootContainerID(), lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/"), isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(rootItemMetadata)

		let result = try adapter.localItemImport(fileURL: fileURL, parentIdentifier: .rootContainer)

		// Check that file was copied to the url provided by the localURLProvider
		XCTAssert(FileManager.default.fileExists(atPath: expectedFileURL.path))
		let contentOfCopiedFile = String(data: try Data(contentsOf: expectedFileURL), encoding: .utf8)
		XCTAssertEqual(fileContent, contentOfCopiedFile)
		// Check that the original file was not altered
		XCTAssert(FileManager.default.contentsEqual(atPath: fileURL.path, andPath: expectedFileURL.path))

		// Check that the correct uploadTask was created
		let taskRecord = result.uploadTaskRecord
		XCTAssertEqual(itemID, taskRecord.correspondingItem)
		XCTAssertNil(taskRecord.failedWithError)
		XCTAssertNil(taskRecord.lastFailedUploadDate)
		XCTAssertNil(taskRecord.uploadErrorCode)

		XCTAssertEqual(1, uploadTaskManagerMock.uploadTasks.count)
		XCTAssertEqual(taskRecord, uploadTaskManagerMock.uploadTasks[itemID])

		XCTAssertEqual(1, cachedFileManagerMock.cachedLocalFileInfo.count)
		guard let localCachedFileInfo = cachedFileManagerMock.cachedLocalFileInfo[itemID] else {
			XCTFail("LocalCachedFileInfo is nil")
			return
		}
		XCTAssertEqual(itemID, localCachedFileInfo.correspondingItem)
		XCTAssertEqual(expectedFileURL, localCachedFileInfo.localURL)
	}

	func testLocalItemImportFailsWhenNoLocalURLIsProvided() throws {
		localURLProviderMock.response = { itemIdentifier in
			XCTAssertEqual(NSFileProviderItemIdentifier("2"), itemIdentifier)
			return nil
		}
		let fileURL = tmpDirectory.appendingPathComponent("ItemToBeImported.txt", isDirectory: false)
		let fileContent = "TestContent"
		try fileContent.write(to: fileURL, atomically: true, encoding: .utf8)

		let rootItemMetadata = ItemMetadata(id: metadataManagerMock.getRootContainerID(), name: "Home", type: .folder, size: nil, parentID: metadataManagerMock.getRootContainerID(), lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/"), isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(rootItemMetadata)

		XCTAssertThrowsError(try adapter.localItemImport(fileURL: fileURL, parentIdentifier: .rootContainer)) { error in
			guard NSFileProviderError(.noSuchItem) as NSError == error as NSError else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}

		XCTAssert(uploadTaskManagerMock.uploadTasks.isEmpty)
	}

	func testLocalItemImportFailsIfItemAlreadyExistsAtLocalURL() throws {
		let expectedFileURL = tmpDirectory.appendingPathComponent("/2/ItemToBeImported.txt")
		localURLProviderMock.response = { itemIdentifier in
			XCTAssertEqual(NSFileProviderItemIdentifier("2"), itemIdentifier)
			return expectedFileURL
		}
		let fileURL = tmpDirectory.appendingPathComponent("ItemToBeImported.txt", isDirectory: false)
		let fileContent = "TestContent"
		try fileContent.write(to: fileURL, atomically: true, encoding: .utf8)
		// Simulate an existing folder structure and file at the URL of the localURLProvider
		try FileManager.default.createDirectory(at: expectedFileURL.deletingLastPathComponent(), withIntermediateDirectories: false)
		let existingFileContent = "ExistingFileContent"
		try existingFileContent.write(to: expectedFileURL, atomically: true, encoding: .utf8)
		let itemID: Int64 = 2
		let rootItemMetadata = ItemMetadata(id: metadataManagerMock.getRootContainerID(), name: "Home", type: .folder, size: nil, parentID: metadataManagerMock.getRootContainerID(), lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/"), isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(rootItemMetadata)

		XCTAssertThrowsError(try adapter.localItemImport(fileURL: fileURL, parentIdentifier: .rootContainer)) { error in
			guard case CocoaError.fileWriteFileExists = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}

		// Check that existing file at the url provided by the localURLProvider was not overwritten
		XCTAssert(FileManager.default.fileExists(atPath: expectedFileURL.path))
		let contentOfCopiedFile = String(data: try Data(contentsOf: expectedFileURL), encoding: .utf8)
		XCTAssertEqual(existingFileContent, contentOfCopiedFile)

		XCTAssertEqual(1, metadataManagerMock.removedMetadataID.count)
		XCTAssertEqual(itemID, metadataManagerMock.removedMetadataID[0])

		XCTAssert(uploadTaskManagerMock.uploadTasks.isEmpty)
	}

	// MARK: Import Document

	// swiftlint:disable:next function_body_length
	func testImportDocument() throws {
		let expectation = XCTestExpectation()

		let rootItemMetadata = ItemMetadata(id: metadataManagerMock.getRootContainerID(), name: "Home", type: .folder, size: nil, parentID: metadataManagerMock.getRootContainerID(), lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/"), isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(rootItemMetadata)

		let itemID: Int64 = 2
		let expectedFileURL = tmpDirectory.appendingPathComponent("/\(itemID)/ItemToBeImported.txt")
		localURLProviderMock.response = { itemIdentifier in
			XCTAssertEqual(NSFileProviderItemIdentifier("\(itemID)"), itemIdentifier)
			return expectedFileURL
		}
		let fileURL = tmpDirectory.appendingPathComponent("ItemToBeImported.txt", isDirectory: false)
		let fileContent = "TestContent"
		try fileContent.write(to: fileURL, atomically: true, encoding: .utf8)

		let adapter = FileProviderAdapter(uploadTaskManager: uploadTaskManagerMock, cachedFileManager: cachedFileManagerMock, itemMetadataManager: metadataManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, itemEnumerationTaskManager: itemEnumerationTaskManagerMock, downloadTaskManager: downloadTaskManagerMock, scheduler: WorkflowSchedulerMock(), provider: cloudProviderMock, localURLProvider: localURLProviderMock)
		adapter.importDocument(at: fileURL, toParentItemIdentifier: .rootContainer) { item, error in
			XCTAssertNil(error)
			guard let item = item as? FileProviderItem else {
				XCTFail("Item is nil")
				return
			}
			XCTAssertEqual("ItemToBeImported.txt", item.filename)
			XCTAssertNil(item.uploadingError ?? nil)
			XCTAssert(item.isUploading)
			XCTAssert(item.newestVersionLocallyCached)
			XCTAssertEqual(expectedFileURL, item.localURL)

			// Check that file was copied to the url provided by the localURLProvider
			XCTAssert(FileManager.default.fileExists(atPath: expectedFileURL.path))
			let contentOfCopiedFile: String?
			do {
				contentOfCopiedFile = String(data: try Data(contentsOf: expectedFileURL), encoding: .utf8)
			} catch {
				XCTFail("Content of copied file failed with error: \(error)")
				return
			}
			XCTAssertEqual(fileContent, contentOfCopiedFile)
			// Check that the original file was not altered
			XCTAssert(FileManager.default.contentsEqual(atPath: fileURL.path, andPath: expectedFileURL.path))

			// Check that the correct uploadTask was created
			XCTAssertEqual(1, self.uploadTaskManagerMock.uploadTasks.count)
			guard let taskRecord = self.uploadTaskManagerMock.uploadTasks[itemID] else {
				XCTFail("TaskRecord not found")
				return
			}
			XCTAssertEqual(itemID, taskRecord.correspondingItem)
			XCTAssertNil(taskRecord.failedWithError)
			XCTAssertNil(taskRecord.lastFailedUploadDate)
			XCTAssertNil(taskRecord.uploadErrorCode)
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	// MARK: ItemChanged

	func testItemChanged() throws {
		let itemID: Int64 = 2
		let cloudPath = CloudPath("/Item.txt")
		let itemMetadata = ItemMetadata(id: itemID, name: "Item.txt", type: .file, size: nil, parentID: metadataManagerMock.getRootContainerID(), lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false, isCandidateForCacheCleanup: false)
		metadataManagerMock.cachedMetadata[itemID] = itemMetadata
		let adapter = FileProviderAdapter(uploadTaskManager: uploadTaskManagerMock, cachedFileManager: cachedFileManagerMock, itemMetadataManager: metadataManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, itemEnumerationTaskManager: itemEnumerationTaskManagerMock, downloadTaskManager: downloadTaskManagerMock, scheduler: WorkflowSchedulerMock(), provider: cloudProviderMock)

		let fileURL = tmpDirectory.appendingPathComponent("/\(itemID)/Item.txt")
		try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: false)
		let fileContent = "TestContent"
		try fileContent.write(to: fileURL, atomically: true, encoding: .utf8)

		adapter.itemChanged(at: fileURL)

		XCTAssertEqual(1, metadataManagerMock.updatedMetadata.count)
		let updatedMetadata = metadataManagerMock.updatedMetadata[0]
		XCTAssertEqual(itemMetadata, updatedMetadata)
		XCTAssertEqual(ItemStatus.isUploading, updatedMetadata.statusCode)

		// Check that the local file info was cached
		XCTAssertEqual(1, cachedFileManagerMock.cachedLocalFileInfo.count)
		guard let cachedLocalFileInfo = cachedFileManagerMock.cachedLocalFileInfo[itemID] else {
			XCTFail("CachedLocalFileInfo is nil")
			return
		}
		XCTAssertEqual(itemID, cachedLocalFileInfo.correspondingItem)
		XCTAssertEqual(fileURL, cachedLocalFileInfo.localURL)

		// Check that the correct uploadTask was created
		XCTAssertEqual(1, uploadTaskManagerMock.uploadTasks.count)
		guard let taskRecord = uploadTaskManagerMock.uploadTasks[itemID] else {
			XCTFail("TaskRecord not found")
			return
		}
		XCTAssertEqual(itemID, taskRecord.correspondingItem)
		XCTAssertNil(taskRecord.failedWithError)
		XCTAssertNil(taskRecord.lastFailedUploadDate)
		XCTAssertNil(taskRecord.uploadErrorCode)
	}

	// MARK: Replace Existing

	// swiftlint:disable:next function_body_length
	func testReplaceExisting() throws {
		let expectation = XCTestExpectation()

		// Simulate delete item in cloud is not finished until `importDocument` locally succeeded
		let cloudProviderMock = CloudProviderMock()
		let deleteItemPromise = Promise<Void>.pending()
		let uploadItemPromise = deleteItemPromise.then { _ -> CloudItemMetadata in
			let metadata = CloudItemMetadata(name: "File 1", cloudPath: CloudPath("/File 1"), itemType: .file, lastModifiedDate: nil, size: 11)
			expectation.fulfill()
			return metadata
		}
		cloudProviderMock.deleteFileAtReturnValue = deleteItemPromise
		cloudProviderMock.uploadFileFromToReplaceExistingReturnValue = uploadItemPromise

		let rootItemMetadata = ItemMetadata(id: metadataManagerMock.getRootContainerID(), name: "Home", type: .folder, size: nil, parentID: metadataManagerMock.getRootContainerID(), lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/"), isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(rootItemMetadata)

		let itemID: Int64 = 2
		let itemFolderURL = tmpDirectory.appendingPathComponent("\(itemID)", isDirectory: true)
		try FileManager.default.createDirectory(at: itemFolderURL, withIntermediateDirectories: true)
		let expectedFileURL = itemFolderURL.appendingPathComponent("File 1", isDirectory: false)
		localURLProviderMock.response = { itemIdentifier in
			XCTAssertEqual(NSFileProviderItemIdentifier("\(itemID)"), itemIdentifier)
			return expectedFileURL
		}
		let existingFileContent = "Existing Content"
		try existingFileContent.write(to: expectedFileURL, atomically: true, encoding: .utf8)
		let existingItemMetadata = ItemMetadata(id: itemID, name: "File 1", type: .file, size: nil, parentID: metadataManagerMock.getRootContainerID(), lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/File 1"), isPlaceholderItem: false, isCandidateForCacheCleanup: false)
		try metadataManagerMock.cacheMetadata(existingItemMetadata)
		try cachedFileManagerMock.cacheLocalFileInfo(for: itemID, localURL: expectedFileURL, lastModifiedDate: Date(timeIntervalSince1970: 0))

		let fileURL = tmpDirectory.appendingPathComponent("File 1", isDirectory: false)
		let fileContent = "TestContent"
		try fileContent.write(to: fileURL, atomically: true, encoding: .utf8)

		let adapter = FileProviderAdapter(uploadTaskManager: uploadTaskManagerMock, cachedFileManager: cachedFileManagerMock, itemMetadataManager: metadataManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, itemEnumerationTaskManager: itemEnumerationTaskManagerMock, downloadTaskManager: downloadTaskManagerMock, scheduler: WorkflowSchedulerMock(), provider: cloudProviderMock, localURLProvider: localURLProviderMock)

		adapter.deleteItem(withIdentifier: NSFileProviderItemIdentifier("\(itemID)"), completionHandler: ({ error in
			XCTAssertNil(error)
			adapter.importDocument(at: fileURL, toParentItemIdentifier: .rootContainer, completionHandler: ({ item, error in
				XCTAssertNil(error)
				XCTAssertNotNil(item)
				guard let fileProviderItem = item as? FileProviderItem else {
					XCTFail("Can't cast to FileProviderItem")
					return
				}
				XCTAssertEqual(existingItemMetadata.name, fileProviderItem.metadata.name)
				XCTAssertEqual(existingItemMetadata.type, fileProviderItem.metadata.type)
				XCTAssertEqual(11, fileProviderItem.metadata.size)
				XCTAssertEqual(existingItemMetadata.parentID, fileProviderItem.metadata.parentID)
				XCTAssertEqual(.isUploading, fileProviderItem.metadata.statusCode)
				XCTAssert(fileProviderItem.metadata.isPlaceholderItem)
				XCTAssertFalse(fileProviderItem.metadata.isMaybeOutdated)

				XCTAssertEqual(expectedFileURL, fileProviderItem.localURL)

				// Check local file was overwritten
				do {
					let localFileContent = try String(contentsOf: expectedFileURL)
					XCTAssertEqual(fileContent, localFileContent)
				} catch {
					XCTFail("Read local file content from \(expectedFileURL) failed with error: \(error)")
				}

				// Check CachedFileInfo is updated
				guard let cachedLocalFileInfo = self.cachedFileManagerMock.cachedLocalFileInfo[itemID] else {
					XCTFail("CachedLocalFileInfo does not exists")
					return
				}
				XCTAssertEqual(expectedFileURL, cachedLocalFileInfo.localURL)
				XCTAssertEqual(itemID, cachedLocalFileInfo.correspondingItem)
				XCTAssertNotNil(cachedLocalFileInfo.lastModifiedDate)
				XCTAssertNotEqual(Date(timeIntervalSince1970: 0), cachedLocalFileInfo.lastModifiedDate)
				deleteItemPromise.fulfill(())
			}))
		}))
		wait(for: [expectation], timeout: 1.0)
	}
}
