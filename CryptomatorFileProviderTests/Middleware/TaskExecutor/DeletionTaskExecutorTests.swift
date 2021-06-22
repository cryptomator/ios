//
//  DeletionTaskExecutorTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 28.05.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Promises
import XCTest
@testable import CryptomatorFileProvider

class DeletionTaskExecutorTests: CloudTaskExecutorTestCase {
	var taskExecutor: DeletionTaskExecutor!
	override func setUp() {
		super.setUp()
		taskExecutor = DeletionTaskExecutor(provider: cloudProviderMock, itemMetadataManager: metadataManagerMock)
	}

	func testDeleteFile() throws {
		let expectation = XCTestExpectation()
		let itemMetadata = ItemMetadata(id: 2, name: "TestFile", type: .file, size: nil, parentID: 1, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/TestFile"), isPlaceholderItem: false, isCandidateForCacheCleanup: false)
		let taskRecord = try deletionTaskManagerMock.createTaskRecord(for: itemMetadata)
		let deletionTask = try deletionTaskManagerMock.getTask(for: taskRecord)
		taskExecutor.execute(task: deletionTask).then {
			XCTAssertEqual(1, self.cloudProviderMock.deletedFiles.count)
			XCTAssertEqual("/TestFile", self.cloudProviderMock.deletedFiles[0])

			XCTAssertEqual(1, self.metadataManagerMock.removedMetadataID.count)
			XCTAssertEqual(itemMetadata.id, self.metadataManagerMock.removedMetadataID[0])
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testDeleteFolder() throws {
		let expectation = XCTestExpectation()
		let itemMetadata = ItemMetadata(id: 2, name: "TestFolder", type: .folder, size: nil, parentID: 1, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/TestFolder"), isPlaceholderItem: false, isCandidateForCacheCleanup: false)
		let taskRecord = try deletionTaskManagerMock.createTaskRecord(for: itemMetadata)
		let deletionTask = try deletionTaskManagerMock.getTask(for: taskRecord)
		taskExecutor.execute(task: deletionTask).then {
			XCTAssertEqual(1, self.cloudProviderMock.deletedFolders.count)
			XCTAssertEqual("/TestFolder", self.cloudProviderMock.deletedFolders[0])

			XCTAssertEqual(1, self.metadataManagerMock.removedMetadataID.count)
			XCTAssertEqual(itemMetadata.id, self.metadataManagerMock.removedMetadataID[0])
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testDeleteFileFailWithSameErrorAsProvider() throws {
		let errorCloudProviderMock = CloudProviderErrorMock()
		errorCloudProviderMock.deleteFileResponse = { _ in
			Promise(CloudTaskTestError.correctPassthrough)
		}

		let expectation = XCTestExpectation()
		let itemMetadata = ItemMetadata(id: 2, name: "TestFile", type: .file, size: nil, parentID: 1, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/TestFile"), isPlaceholderItem: false, isCandidateForCacheCleanup: false)
		let taskRecord = try deletionTaskManagerMock.createTaskRecord(for: itemMetadata)
		let deletionTask = try deletionTaskManagerMock.getTask(for: taskRecord)
		let taskExecutor = DeletionTaskExecutor(provider: errorCloudProviderMock, itemMetadataManager: metadataManagerMock)
		taskExecutor.execute(task: deletionTask).then {
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

	func testDeleteFolderFailWithSameErrorAsProvider() throws {
		let errorCloudProviderMock = CloudProviderErrorMock()
		errorCloudProviderMock.deleteFolderResponse = { _ in
			Promise(CloudTaskTestError.correctPassthrough)
		}

		let expectation = XCTestExpectation()
		let itemMetadata = ItemMetadata(id: 2, name: "TestFolder", type: .folder, size: nil, parentID: 1, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/TestFolder"), isPlaceholderItem: false, isCandidateForCacheCleanup: false)
		let taskRecord = try deletionTaskManagerMock.createTaskRecord(for: itemMetadata)
		let deletionTask = try deletionTaskManagerMock.getTask(for: taskRecord)
		let taskExecutor = DeletionTaskExecutor(provider: errorCloudProviderMock, itemMetadataManager: metadataManagerMock)
		taskExecutor.execute(task: deletionTask).then {
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
