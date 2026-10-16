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
	func testCreateDirectory() async throws {
		let rootItemMetadata = ItemMetadata(id: NSFileProviderItemIdentifier.rootContainerDatabaseValue, name: "Home", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(rootItemMetadata)
		let adapter = FileProviderAdapter(domainIdentifier: .test, uploadTaskManager: uploadTaskManagerMock, cachedFileManager: cachedFileManagerMock, itemMetadataManager: metadataManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, itemEnumerationTaskManager: itemEnumerationTaskManagerMock, downloadTaskManager: downloadTaskManagerMock, scheduler: WorkflowSchedulerMock(), maxParallelUploads: 1, maxParallelDownloads: 1, provider: cloudProviderMock, fileCoordinatorPurposeIdentifier: fileCoordinatorPurposeIdentifier, localURLProvider: localURLProviderMock, taskRegistrator: taskRegistratorMock)

		let item = try await adapter.createDirectory(withName: "TestFolder", inParentItemIdentifier: .rootContainer)

		let fileProviderItem = try XCTUnwrap(item, "FileProviderItem is nil")
		XCTAssertEqual("TestFolder", fileProviderItem.filename)
		XCTAssert(fileProviderItem.isUploading)
		XCTAssertFalse(fileProviderItem.isUploaded)
		XCTAssertEqual("public.folder", fileProviderItem.typeIdentifier)
		XCTAssert(fileProviderItem.metadata.isPlaceholderItem)
		XCTAssertEqual("TestFolder", fileProviderItem.metadata.name)
		XCTAssertNotNil(fileProviderItem.metadata.id)

		XCTAssertEqual(2, metadataManagerMock.cachedMetadata.count)
		XCTAssertEqual(fileProviderItem.metadata, try metadataManagerMock.cachedMetadata[XCTUnwrap(fileProviderItem.metadata.id)])
	}

	func testCreateDirectoryFailsIfParentDoesNotExist() async {
		let adapter = FileProviderAdapter(domainIdentifier: .test, uploadTaskManager: uploadTaskManagerMock, cachedFileManager: cachedFileManagerMock, itemMetadataManager: metadataManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, itemEnumerationTaskManager: itemEnumerationTaskManagerMock, downloadTaskManager: downloadTaskManagerMock, scheduler: WorkflowSchedulerMock(), maxParallelUploads: 1, maxParallelDownloads: 1, provider: cloudProviderMock, fileCoordinatorPurposeIdentifier: fileCoordinatorPurposeIdentifier, localURLProvider: LocalURLProviderMock(), taskRegistrator: taskRegistratorMock)

		await XCTAssertThrowsAsyncError(try await adapter.createDirectory(withName: "TestFolder", inParentItemIdentifier: NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: 2))) { error in
			guard case FileProviderAdapterError.parentFolderNotFound = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}
		XCTAssert(metadataManagerMock.cachedMetadata.isEmpty, "Unexpected change of cached metadata.")
		XCTAssert(metadataManagerMock.updatedMetadata.isEmpty, "Unexpected change of cached metadata.")
		XCTAssert(metadataManagerMock.removedMetadataID.isEmpty, "Unexpected change of cached metadata.")
	}

	// MARK: Create Placeholder

	func testCreatePlaceholderItemForFolder() throws {
		let rootItemMetadata = ItemMetadata(id: NSFileProviderItemIdentifier.rootContainerDatabaseValue, name: "Home", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(rootItemMetadata)

		let placeholderItem = try adapter.createPlaceholderItemForFolder(withName: "TestFolder", in: .rootContainer)
		XCTAssertEqual("TestFolder", placeholderItem.filename)
		XCTAssert(placeholderItem.isUploading)
		XCTAssertFalse(placeholderItem.isUploaded)
		XCTAssertEqual("public.folder", placeholderItem.typeIdentifier)
		XCTAssert(placeholderItem.metadata.isPlaceholderItem)
		XCTAssertEqual("TestFolder", placeholderItem.metadata.name)
		XCTAssertNotNil(placeholderItem.metadata.id)

		XCTAssertEqual(2, metadataManagerMock.cachedMetadata.count)
		XCTAssertEqual(placeholderItem.metadata, try metadataManagerMock.cachedMetadata[XCTUnwrap(placeholderItem.metadata.id)])
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
