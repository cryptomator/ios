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
		let itemMetadata = ItemMetadata(id: 2, name: "NewFolder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, isPlaceholderItem: true, isCandidateForCacheCleanup: false)

		let task = FolderCreationTask(itemMetadata: itemMetadata, cloudPath: cloudPath)
		let taskExecutor = FolderCreationTaskExecutor(domainIdentifier: .test, provider: cloudProviderMock, itemMetadataManager: metadataManagerMock, limiter: ConcurrencyLimiter(maxConcurrentOperations: 2))
		taskExecutor.execute(task: task).then { item in
			XCTAssertEqual(1, self.metadataManagerMock.updatedMetadata.count)
			XCTAssertEqual(itemMetadata, self.metadataManagerMock.updatedMetadata[0])
			XCTAssertEqual(ItemStatus.isUploaded, item.metadata.statusCode)
			XCTAssertFalse(item.metadata.isPlaceholderItem)
			XCTAssertEqual(1, self.cloudProviderMock.createdFolders.count)
			XCTAssertEqual(cloudPath.path, self.cloudProviderMock.createdFolders[0])
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 5.0)
	}

	func testCreateFolderFailWithSameErrorAsProvider() {
		let expectation = XCTestExpectation()
		let cloudPath = CloudPath("/NewFolder")
		let itemMetadata = ItemMetadata(id: 2, name: "NewFolder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, isPlaceholderItem: true, isCandidateForCacheCleanup: false)

		let errorCloudProviderMock = CloudProviderErrorMock()
		errorCloudProviderMock.createFolderResponse = { folderPath in
			XCTAssertEqual(cloudPath, folderPath)
			return Promise(CloudTaskTestError.correctPassthrough)
		}

		let task = FolderCreationTask(itemMetadata: itemMetadata, cloudPath: cloudPath)
		let taskExecutor = FolderCreationTaskExecutor(domainIdentifier: .test, provider: errorCloudProviderMock, itemMetadataManager: metadataManagerMock, limiter: ConcurrencyLimiter(maxConcurrentOperations: 2))
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
		wait(for: [expectation], timeout: 5.0)
	}

	func testCreateFolderRunsNoMoreRequestsAtOnceThanTheLimiterAllows() {
		var requestsInFlight = 0
		var maxRequestsInFlight = 0
		let slowCloudProviderMock = CloudProviderErrorMock()
		slowCloudProviderMock.createFolderResponse = { _ in
			requestsInFlight += 1
			maxRequestsInFlight = max(maxRequestsInFlight, requestsInFlight)
			return Promise(()).delay(0.1).always {
				requestsInFlight -= 1
			}
		}
		let limiter = ConcurrencyLimiter(maxConcurrentOperations: 2)

		let executions = (2 ... 6).map { id -> Promise<FileProviderItem> in
			let itemMetadata = ItemMetadata(id: Int64(id), name: "Folder \(id)", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, isPlaceholderItem: true)
			let task = FolderCreationTask(itemMetadata: itemMetadata, cloudPath: CloudPath("/Folder \(id)"))
			let taskExecutor = FolderCreationTaskExecutor(domainIdentifier: .test, provider: slowCloudProviderMock, itemMetadataManager: metadataManagerMock, limiter: limiter)
			return taskExecutor.execute(task: task)
		}
		wait(for: all(executions), timeout: 5.0)

		XCTAssertEqual(2, maxRequestsInFlight)
	}

	func testCreateFolderReleasesItsPermitWhenTheRequestFails() {
		var requestCount = 0
		let failingOnceCloudProviderMock = CloudProviderErrorMock()
		failingOnceCloudProviderMock.createFolderResponse = { _ in
			requestCount += 1
			return requestCount == 1 ? Promise(CloudTaskTestError.correctPassthrough) : Promise(())
		}
		let limiter = ConcurrencyLimiter(maxConcurrentOperations: 1)
		let taskExecutor = FolderCreationTaskExecutor(domainIdentifier: .test, provider: failingOnceCloudProviderMock, itemMetadataManager: metadataManagerMock, limiter: limiter)
		let failingMetadata = ItemMetadata(id: 2, name: "Failing", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, isPlaceholderItem: true)
		let succeedingMetadata = ItemMetadata(id: 3, name: "Succeeding", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, isPlaceholderItem: true)

		let failing = taskExecutor.execute(task: FolderCreationTask(itemMetadata: failingMetadata, cloudPath: CloudPath("/Failing")))
		let succeeding = taskExecutor.execute(task: FolderCreationTask(itemMetadata: succeedingMetadata, cloudPath: CloudPath("/Succeeding")))

		XCTAssertRejects(failing, with: CloudTaskTestError.correctPassthrough)
		wait(for: succeeding, timeout: 5.0)
	}
}
