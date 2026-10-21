//
//  ReparentTaskExecutorTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 28.05.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import XCTest
@testable import CryptomatorFileProvider

class ReparentTaskExecutorTests: CloudTaskExecutorTestCase {
	func testMoveFileInCloud() async throws {
		let sourceCloudPath = CloudPath("/Test.txt")
		let targetCloudPath = CloudPath("/Folder/Test.txt")
		let itemMetadata = ItemMetadata(id: 2, name: "Test.txt", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(itemMetadata)

		let reparentTaskRecord = try ReparentTaskRecord(correspondingItem: XCTUnwrap(itemMetadata.id), sourceCloudPath: sourceCloudPath, targetCloudPath: targetCloudPath, oldParentID: itemMetadata.parentID, newParentID: itemMetadata.parentID)
		let reparentTask = ReparentTask(taskRecord: reparentTaskRecord, itemMetadata: itemMetadata, cloudPath: sourceCloudPath)
		let taskExecutor = ReparentTaskExecutor(domainIdentifier: .test, provider: cloudProviderMock, reparentTaskManager: reparentTaskManagerMock, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock)

		let item = try await taskExecutor.execute(task: reparentTask)
		XCTAssertEqual(.rootContainer, item.parentItemIdentifier)
		XCTAssertEqual(ItemStatus.isUploaded, item.metadata.statusCode)
		XCTAssertEqual(ItemStatus.isUploaded, metadataManagerMock.updatedMetadata[0].statusCode)

		XCTAssertEqual(1, metadataManagerMock.updatedMetadata.count)
		XCTAssertEqual(itemMetadata, metadataManagerMock.updatedMetadata[0])
		XCTAssertEqual(cloudProviderMock.movedFiles[sourceCloudPath.path], targetCloudPath.path)

		XCTAssertEqual(1, reparentTaskManagerMock.removedReparentTasks.count)
		XCTAssertEqual(reparentTaskRecord, reparentTaskManagerMock.removedReparentTasks[0])
	}

	func testMoveFolderInCloud() async throws {
		let sourceCloudPath = CloudPath("/Test")
		let targetCloudPath = CloudPath("/Folder/Test")
		let itemMetadata = ItemMetadata(id: 2, name: "Test", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(itemMetadata)

		let reparentTaskRecord = try ReparentTaskRecord(correspondingItem: XCTUnwrap(itemMetadata.id), sourceCloudPath: sourceCloudPath, targetCloudPath: targetCloudPath, oldParentID: itemMetadata.parentID, newParentID: itemMetadata.parentID)
		let reparentTask = ReparentTask(taskRecord: reparentTaskRecord, itemMetadata: itemMetadata, cloudPath: sourceCloudPath)
		let taskExecutor = ReparentTaskExecutor(domainIdentifier: .test, provider: cloudProviderMock, reparentTaskManager: reparentTaskManagerMock, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock)

		let item = try await taskExecutor.execute(task: reparentTask)
		XCTAssertEqual(.rootContainer, item.parentItemIdentifier)
		XCTAssertEqual(ItemStatus.isUploaded, item.metadata.statusCode)
		XCTAssertEqual(ItemStatus.isUploaded, metadataManagerMock.updatedMetadata[0].statusCode)

		XCTAssertEqual(1, metadataManagerMock.updatedMetadata.count)
		XCTAssertEqual(itemMetadata, metadataManagerMock.updatedMetadata[0])
		XCTAssertEqual(cloudProviderMock.movedFolders[sourceCloudPath.path], targetCloudPath.path)

		XCTAssertEqual(1, reparentTaskManagerMock.removedReparentTasks.count)
		XCTAssertEqual(reparentTaskRecord, reparentTaskManagerMock.removedReparentTasks[0])
	}

	func testMoveFileFailWithSameErrorAsProvider() async throws {
		let errorCloudProviderMock = CloudProviderErrorMock()
		errorCloudProviderMock.moveFileResponse = { _, _ in
			throw CloudTaskTestError.correctPassthrough
		}

		let sourceCloudPath = CloudPath("/Test.txt")
		let targetCloudPath = CloudPath("/Folder/Test.txt")
		let itemMetadata = ItemMetadata(id: 2, name: "Test.txt", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(itemMetadata)

		let reparentTaskRecord = try ReparentTaskRecord(correspondingItem: XCTUnwrap(itemMetadata.id), sourceCloudPath: sourceCloudPath, targetCloudPath: targetCloudPath, oldParentID: itemMetadata.parentID, newParentID: itemMetadata.parentID)
		let reparentTask = ReparentTask(taskRecord: reparentTaskRecord, itemMetadata: itemMetadata, cloudPath: sourceCloudPath)
		let taskExecutor = ReparentTaskExecutor(domainIdentifier: .test, provider: errorCloudProviderMock, reparentTaskManager: reparentTaskManagerMock, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock)
		await XCTAssertThrowsAsyncError(try await taskExecutor.execute(task: reparentTask)) { error in
			guard case CloudTaskTestError.correctPassthrough = error else {
				XCTFail("Rejected with the wrong error: \(error)")
				return
			}
		}
		XCTAssert(metadataManagerMock.removedMetadataID.isEmpty, "Unexpected removal of ItemMetadata")
	}

	func testMoveFolderFailWithSameErrorAsProvider() async throws {
		let errorCloudProviderMock = CloudProviderErrorMock()
		errorCloudProviderMock.moveFolderResponse = { _, _ in
			throw CloudTaskTestError.correctPassthrough
		}

		let sourceCloudPath = CloudPath("/Test")
		let targetCloudPath = CloudPath("/Folder/Test")
		let itemMetadata = ItemMetadata(id: 2, name: "Test", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(itemMetadata)

		let reparentTaskRecord = try ReparentTaskRecord(correspondingItem: XCTUnwrap(itemMetadata.id), sourceCloudPath: sourceCloudPath, targetCloudPath: targetCloudPath, oldParentID: itemMetadata.parentID, newParentID: itemMetadata.parentID)
		let reparentTask = ReparentTask(taskRecord: reparentTaskRecord, itemMetadata: itemMetadata, cloudPath: sourceCloudPath)
		let taskExecutor = ReparentTaskExecutor(domainIdentifier: .test, provider: errorCloudProviderMock, reparentTaskManager: reparentTaskManagerMock, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock)
		await XCTAssertThrowsAsyncError(try await taskExecutor.execute(task: reparentTask)) { error in
			guard case CloudTaskTestError.correctPassthrough = error else {
				XCTFail("Rejected with the wrong error: \(error)")
				return
			}
		}
		XCTAssert(metadataManagerMock.removedMetadataID.isEmpty, "Unexpected removal of ItemMetadata")
	}
}
