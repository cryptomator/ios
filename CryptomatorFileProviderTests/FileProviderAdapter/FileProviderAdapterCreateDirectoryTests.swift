//
//  FileProviderAdapterCreateDirectoryTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 07.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import XCTest
@testable import CryptomatorFileProvider

class FileProviderAdapterCreateDirectoryTests: FileProviderAdapterTestCase {
	func testCreateDirectory() throws {
		let expectation = XCTestExpectation()
		let rootItemMetadata = ItemMetadata(id: NSFileProviderItemIdentifier.rootContainerDatabaseValue, name: "Home", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/"), isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(rootItemMetadata)
		let adapter = FileProviderAdapter(domainIdentifier: .test, uploadTaskManager: uploadTaskManagerMock, cachedFileManager: cachedFileManagerMock, itemMetadataManager: metadataManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, itemEnumerationTaskManager: itemEnumerationTaskManagerMock, downloadTaskManager: downloadTaskManagerMock, scheduler: WorkflowSchedulerMock(), provider: cloudProviderMock, coordinator: fileCoordinator, localURLProvider: localURLProviderMock, taskRegistrator: taskRegistratorMock)
		adapter.createDirectory(withName: "TestFolder", inParentItemIdentifier: .rootContainer) { item, error in
			XCTAssertNil(error)
			guard let fileProviderItem = item as? FileProviderItem else {
				XCTFail("FileProviderItem is nil")
				return
			}
			XCTAssertEqual("TestFolder", fileProviderItem.filename)
			XCTAssert(fileProviderItem.isUploading)
			XCTAssertFalse(fileProviderItem.isUploaded)
			XCTAssertEqual("public.folder", fileProviderItem.typeIdentifier)
			XCTAssert(fileProviderItem.metadata.isPlaceholderItem)
			XCTAssertEqual(CloudPath("/TestFolder"), fileProviderItem.metadata.cloudPath)
			XCTAssertNotNil(fileProviderItem.metadata.id)

			XCTAssertEqual(2, self.metadataManagerMock.cachedMetadata.count)
			XCTAssertEqual(fileProviderItem.metadata, self.metadataManagerMock.cachedMetadata[fileProviderItem.metadata.id!])

			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testCreateDirectoryFailsIfParentDoesNotExist() throws {
		let expectation = XCTestExpectation()
		let adapter = FileProviderAdapter(domainIdentifier: .test, uploadTaskManager: uploadTaskManagerMock, cachedFileManager: cachedFileManagerMock, itemMetadataManager: metadataManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, itemEnumerationTaskManager: itemEnumerationTaskManagerMock, downloadTaskManager: downloadTaskManagerMock, scheduler: WorkflowSchedulerMock(), provider: cloudProviderMock, coordinator: fileCoordinator, localURLProvider: LocalURLProviderMock(), taskRegistrator: taskRegistratorMock)
		adapter.createDirectory(withName: "TestFolder", inParentItemIdentifier: NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: 2)) { item, error in
			XCTAssertNil(item)
			guard let error = error else {
				XCTFail("Error is nil")
				return
			}
			guard case FileProviderAdapterError.parentFolderNotFound = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
			XCTAssert(self.metadataManagerMock.cachedMetadata.isEmpty, "Unexpected change of cached metadata.")
			XCTAssert(self.metadataManagerMock.updatedMetadata.isEmpty, "Unexpected change of cached metadata.")
			XCTAssert(self.metadataManagerMock.removedMetadataID.isEmpty, "Unexpected change of cached metadata.")
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	// MARK: Create Placeholder

	func testCreatePlaceholderItemForFolder() throws {
		let rootItemMetadata = ItemMetadata(id: NSFileProviderItemIdentifier.rootContainerDatabaseValue, name: "Home", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/"), isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(rootItemMetadata)

		let placeholderItem = try adapter.createPlaceholderItemForFolder(withName: "TestFolder", in: .rootContainer)
		XCTAssertEqual("TestFolder", placeholderItem.filename)
		XCTAssert(placeholderItem.isUploading)
		XCTAssertFalse(placeholderItem.isUploaded)
		XCTAssertEqual("public.folder", placeholderItem.typeIdentifier)
		XCTAssert(placeholderItem.metadata.isPlaceholderItem)
		XCTAssertEqual(CloudPath("/TestFolder"), placeholderItem.metadata.cloudPath)
		XCTAssertNotNil(placeholderItem.metadata.id)

		XCTAssertEqual(2, metadataManagerMock.cachedMetadata.count)
		XCTAssertEqual(placeholderItem.metadata, metadataManagerMock.cachedMetadata[placeholderItem.metadata.id!])
	}

	func testCreatePlaceholderItemForFolderFailsIfParentDoesNotExist() throws {
		XCTAssertThrowsError(try adapter.createPlaceholderItemForFolder(withName: "TestFolder", in: NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: 2))) { error in
			guard case FileProviderAdapterError.parentFolderNotFound = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
			XCTAssert(self.metadataManagerMock.cachedMetadata.isEmpty, "Unexpected change of cached metadata.")
			XCTAssert(self.metadataManagerMock.updatedMetadata.isEmpty, "Unexpected change of cached metadata.")
			XCTAssert(self.metadataManagerMock.removedMetadataID.isEmpty, "Unexpected change of cached metadata.")
		}
	}
}
