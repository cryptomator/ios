//
//  FolderCreationTaskExecutorTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 07.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation
import Promises
import XCTest
@testable import CryptomatorFileProvider

class FolderCreationTaskExecutorTests: CloudTaskExecutorTestCase {
	func testCreateFolder() {
		let expectation = XCTestExpectation()
		let cloudPath = CloudPath("/NewFolder")
		let itemMetadata = ItemMetadata(id: 2, name: "NewFolder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, cloudPath: cloudPath, isPlaceholderItem: true, isCandidateForCacheCleanup: false)

		let task = FolderCreationTask(itemMetadata: itemMetadata)
		let taskExecutor = FolderCreationTaskExecutor(domainIdentifier: .test, provider: cloudProviderMock, itemMetadataManager: metadataManagerMock)
		taskExecutor.execute(task: task).then { item in
			XCTAssertEqual(1, self.metadataManagerMock.updatedMetadata.count)
			XCTAssertEqual(itemMetadata, self.metadataManagerMock.updatedMetadata[0])
			XCTAssertEqual(ItemStatus.isUploaded, item.metadata.statusCode)
			XCTAssertFalse(item.metadata.isPlaceholderItem)
			XCTAssertEqual(1, self.cloudProviderMock.createdFolders.count)
			XCTAssertEqual(item.metadata.cloudPath.path, self.cloudProviderMock.createdFolders[0])
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testCreateFolderFailWithSameErrorAsProvider() {
		let expectation = XCTestExpectation()
		let cloudPath = CloudPath("/NewFolder")
		let itemMetadata = ItemMetadata(id: 2, name: "NewFolder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, cloudPath: cloudPath, isPlaceholderItem: true, isCandidateForCacheCleanup: false)

		let errorCloudProviderMock = CloudProviderErrorMock()
		errorCloudProviderMock.createFolderResponse = { folderPath in
			XCTAssertEqual(cloudPath, folderPath)
			return Promise(CloudTaskTestError.correctPassthrough)
		}

		let task = FolderCreationTask(itemMetadata: itemMetadata)
		let taskExecutor = FolderCreationTaskExecutor(domainIdentifier: .test, provider: errorCloudProviderMock, itemMetadataManager: metadataManagerMock)
		taskExecutor.execute(task: task).then { _ in
			XCTFail("Promise should not fulfill if the provider fails with an error")
		}.catch { error in
			guard case CloudTaskTestError.correctPassthrough = error else {
				XCTFail("Promise rejected but with the wrong error: \(error)")
				return
			}
			XCTAssert(self.metadataManagerMock.cachedMetadata.isEmpty, "Unexpected change of cached metadata.")
			XCTAssert(self.metadataManagerMock.updatedMetadata.isEmpty, "Unexpected change of cached metadata.")
			XCTAssert(self.metadataManagerMock.removedMetadataID.isEmpty, "Unexpected change of cached metadata.")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}
}
