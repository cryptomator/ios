//
//  ReparentTaskExecutorTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 28.05.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Promises
import XCTest
@testable import CryptomatorFileProvider

class ReparentTaskExecutorTests: CloudTaskExecutorTestCase {
	func testMoveFileInCloud() throws {
		let expectation = XCTestExpectation()

		let sourceCloudPath = CloudPath("/Test.txt")
		let targetCloudPath = CloudPath("/Folder/Test.txt")
		let itemMetadata = ItemMetadata(id: 2, name: "Test.txt", type: .file, size: nil, parentId: metadataManagerMock.getRootContainerID(), lastModifiedDate: nil, statusCode: .isUploading, cloudPath: sourceCloudPath, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(itemMetadata)

		let reparentTaskRecord = ReparentTaskRecord(correspondingItem: itemMetadata.id!, sourceCloudPath: sourceCloudPath, targetCloudPath: targetCloudPath, oldParentId: itemMetadata.parentId, newParentId: itemMetadata.parentId)
		let reparentTask = ReparentTask(task: reparentTaskRecord, itemMetadata: itemMetadata)
		let taskExecutor = ReparentTaskExecutor(provider: cloudProviderMock, reparentTaskManager: reparentTaskManagerMock, metadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock)

		taskExecutor.execute(task: reparentTask).then { item in
			XCTAssertEqual(.rootContainer, item.parentItemIdentifier)
			XCTAssertEqual(ItemStatus.isUploaded, item.metadata.statusCode)
			XCTAssertEqual(ItemStatus.isUploaded, self.metadataManagerMock.updatedMetadata[0].statusCode)

			XCTAssertEqual(1, self.metadataManagerMock.updatedMetadata.count)
			XCTAssertEqual(itemMetadata, self.metadataManagerMock.updatedMetadata[0])
			XCTAssertEqual(self.cloudProviderMock.movedFiles[sourceCloudPath.path], targetCloudPath.path)

			XCTAssertEqual(1, self.reparentTaskManagerMock.removedReparentTasks.count)
			XCTAssertEqual(reparentTaskRecord, self.reparentTaskManagerMock.removedReparentTasks[0])

		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testMoveFolderInCloud() throws {
		let expectation = XCTestExpectation()

		let sourceCloudPath = CloudPath("/Test")
		let targetCloudPath = CloudPath("/Folder/Test")
		let itemMetadata = ItemMetadata(id: 2, name: "Test", type: .folder, size: nil, parentId: metadataManagerMock.getRootContainerID(), lastModifiedDate: nil, statusCode: .isUploading, cloudPath: sourceCloudPath, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(itemMetadata)

		let reparentTaskRecord = ReparentTaskRecord(correspondingItem: itemMetadata.id!, sourceCloudPath: sourceCloudPath, targetCloudPath: targetCloudPath, oldParentId: itemMetadata.parentId, newParentId: itemMetadata.parentId)
		let reparentTask = ReparentTask(task: reparentTaskRecord, itemMetadata: itemMetadata)
		let taskExecutor = ReparentTaskExecutor(provider: cloudProviderMock, reparentTaskManager: reparentTaskManagerMock, metadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock)

		taskExecutor.execute(task: reparentTask).then { item in
			XCTAssertEqual(.rootContainer, item.parentItemIdentifier)
			XCTAssertEqual(ItemStatus.isUploaded, item.metadata.statusCode)
			XCTAssertEqual(ItemStatus.isUploaded, self.metadataManagerMock.updatedMetadata[0].statusCode)

			XCTAssertEqual(1, self.metadataManagerMock.updatedMetadata.count)
			XCTAssertEqual(itemMetadata, self.metadataManagerMock.updatedMetadata[0])
			XCTAssertEqual(self.cloudProviderMock.movedFolders[sourceCloudPath.path], targetCloudPath.path)

			XCTAssertEqual(1, self.reparentTaskManagerMock.removedReparentTasks.count)
			XCTAssertEqual(reparentTaskRecord, self.reparentTaskManagerMock.removedReparentTasks[0])

		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testMoveFileFailWithSameErrorAsProvider() throws {
		let expectation = XCTestExpectation()

		let errorCloudProviderMock = CloudProviderErrorMock()
		errorCloudProviderMock.moveFileResponse = { _, _ in
			Promise(CloudTaskTestError.correctPassthrough)
		}

		let sourceCloudPath = CloudPath("/Test.txt")
		let targetCloudPath = CloudPath("/Folder/Test.txt")
		let itemMetadata = ItemMetadata(id: 2, name: "Test.txt", type: .file, size: nil, parentId: metadataManagerMock.getRootContainerID(), lastModifiedDate: nil, statusCode: .isUploading, cloudPath: sourceCloudPath, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(itemMetadata)

		let reparentTaskRecord = ReparentTaskRecord(correspondingItem: itemMetadata.id!, sourceCloudPath: sourceCloudPath, targetCloudPath: targetCloudPath, oldParentId: itemMetadata.parentId, newParentId: itemMetadata.parentId)
		let reparentTask = ReparentTask(task: reparentTaskRecord, itemMetadata: itemMetadata)
		let taskExecutor = ReparentTaskExecutor(provider: errorCloudProviderMock, reparentTaskManager: reparentTaskManagerMock, metadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock)
		taskExecutor.execute(task: reparentTask).then { _ in
			XCTFail("Promise should not fulfill if the provider fails with an error")
		}.catch { error in
			guard case CloudTaskTestError.correctPassthrough = error else {
				XCTFail("Promise rejected but with the wrong error: \(error)")
				return
			}
			XCTAssert(self.metadataManagerMock.removedMetadataID.isEmpty, "Unexpected removal of ItemMetadata")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testMoveFolderFailWithSameErrorAsProvider() throws {
		let expectation = XCTestExpectation()

		let errorCloudProviderMock = CloudProviderErrorMock()
		errorCloudProviderMock.moveFolderResponse = { _, _ in
			Promise(CloudTaskTestError.correctPassthrough)
		}

		let sourceCloudPath = CloudPath("/Test")
		let targetCloudPath = CloudPath("/Folder/Test")
		let itemMetadata = ItemMetadata(id: 2, name: "Test", type: .folder, size: nil, parentId: metadataManagerMock.getRootContainerID(), lastModifiedDate: nil, statusCode: .isUploading, cloudPath: sourceCloudPath, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(itemMetadata)

		let reparentTaskRecord = ReparentTaskRecord(correspondingItem: itemMetadata.id!, sourceCloudPath: sourceCloudPath, targetCloudPath: targetCloudPath, oldParentId: itemMetadata.parentId, newParentId: itemMetadata.parentId)
		let reparentTask = ReparentTask(task: reparentTaskRecord, itemMetadata: itemMetadata)
		let taskExecutor = ReparentTaskExecutor(provider: errorCloudProviderMock, reparentTaskManager: reparentTaskManagerMock, metadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock)
		taskExecutor.execute(task: reparentTask).then { _ in
			XCTFail("Promise should not fulfill if the provider fails with an error")
		}.catch { error in
			guard case CloudTaskTestError.correctPassthrough = error else {
				XCTFail("Promise rejected but with the wrong error: \(error)")
				return
			}
			XCTAssert(self.metadataManagerMock.removedMetadataID.isEmpty, "Unexpected removal of ItemMetadata")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}
}
