//
//  DeletionTaskExecutorTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 28.05.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import XCTest
@testable import CryptomatorFileProvider

class DeletionTaskExecutorTests: CloudTaskExecutorTestCase {
	var taskExecutor: DeletionTaskExecutor!

	override func setUp() async throws {
		try await super.setUp()
		taskExecutor = DeletionTaskExecutor(provider: cloudProviderMock, itemMetadataManager: metadataManagerMock)
	}

	func testDeleteFile() async throws {
		let itemMetadata = ItemMetadata(id: 2, name: "TestFile", type: .file, size: nil, parentID: 1, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false, isCandidateForCacheCleanup: false)
		let taskRecord = try deletionTaskManagerMock.createTaskRecord(for: itemMetadata, cloudPath: CloudPath("/").appendingPathComponent(itemMetadata.name))
		let deletionTask = try deletionTaskManagerMock.getTask(for: taskRecord)
		try await taskExecutor.execute(task: deletionTask)
		XCTAssertEqual(1, cloudProviderMock.deletedFiles.count)
		XCTAssertEqual("/TestFile", cloudProviderMock.deletedFiles[0])

		XCTAssertEqual(1, metadataManagerMock.removedMetadataID.count)
		XCTAssertEqual(itemMetadata.id, metadataManagerMock.removedMetadataID[0])
	}

	func testDeleteFolder() async throws {
		let itemMetadata = ItemMetadata(id: 2, name: "TestFolder", type: .folder, size: nil, parentID: 1, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false, isCandidateForCacheCleanup: false)
		let taskRecord = try deletionTaskManagerMock.createTaskRecord(for: itemMetadata, cloudPath: CloudPath("/").appendingPathComponent(itemMetadata.name))
		let deletionTask = try deletionTaskManagerMock.getTask(for: taskRecord)
		try await taskExecutor.execute(task: deletionTask)
		XCTAssertEqual(1, cloudProviderMock.deletedFolders.count)
		XCTAssertEqual("/TestFolder", cloudProviderMock.deletedFolders[0])

		XCTAssertEqual(1, metadataManagerMock.removedMetadataID.count)
		XCTAssertEqual(itemMetadata.id, metadataManagerMock.removedMetadataID[0])
	}

	func testDeleteFileFailWithSameErrorAsProvider() async throws {
		let errorCloudProviderMock = CloudProviderErrorMock()
		errorCloudProviderMock.deleteFileResponse = { _ in
			throw CloudTaskTestError.correctPassthrough
		}

		let itemMetadata = ItemMetadata(id: 2, name: "TestFile", type: .file, size: nil, parentID: 1, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false, isCandidateForCacheCleanup: false)
		let taskRecord = try deletionTaskManagerMock.createTaskRecord(for: itemMetadata, cloudPath: CloudPath("/").appendingPathComponent(itemMetadata.name))
		let deletionTask = try deletionTaskManagerMock.getTask(for: taskRecord)
		let taskExecutor = DeletionTaskExecutor(provider: errorCloudProviderMock, itemMetadataManager: metadataManagerMock)
		await XCTAssertThrowsAsyncError(try await taskExecutor.execute(task: deletionTask)) { error in
			guard case CloudTaskTestError.correctPassthrough = error else {
				XCTFail("Rejected with the wrong error: \(error)")
				return
			}
		}
		XCTAssert(metadataManagerMock.removedMetadataID.isEmpty, "Unexpected removal of ItemMetadata")
	}

	func testDeleteFolderFailWithSameErrorAsProvider() async throws {
		let errorCloudProviderMock = CloudProviderErrorMock()
		errorCloudProviderMock.deleteFolderResponse = { _ in
			throw CloudTaskTestError.correctPassthrough
		}

		let itemMetadata = ItemMetadata(id: 2, name: "TestFolder", type: .folder, size: nil, parentID: 1, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false, isCandidateForCacheCleanup: false)
		let taskRecord = try deletionTaskManagerMock.createTaskRecord(for: itemMetadata, cloudPath: CloudPath("/").appendingPathComponent(itemMetadata.name))
		let deletionTask = try deletionTaskManagerMock.getTask(for: taskRecord)
		let taskExecutor = DeletionTaskExecutor(provider: errorCloudProviderMock, itemMetadataManager: metadataManagerMock)
		await XCTAssertThrowsAsyncError(try await taskExecutor.execute(task: deletionTask)) { error in
			guard case CloudTaskTestError.correctPassthrough = error else {
				XCTFail("Rejected with the wrong error: \(error)")
				return
			}
		}
		XCTAssert(metadataManagerMock.removedMetadataID.isEmpty, "Unexpected removal of ItemMetadata")
	}
}
