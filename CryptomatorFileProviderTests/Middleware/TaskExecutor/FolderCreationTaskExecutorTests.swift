//
//  FolderCreationTaskExecutorTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 07.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation
import os
import XCTest
@testable import CryptomatorFileProvider

class FolderCreationTaskExecutorTests: CloudTaskExecutorTestCase {
	func testCreateFolder() async throws {
		let cloudPath = CloudPath("/NewFolder")
		let itemMetadata = ItemMetadata(id: 2, name: "NewFolder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, isPlaceholderItem: true, isCandidateForCacheCleanup: false)

		let task = FolderCreationTask(itemMetadata: itemMetadata, cloudPath: cloudPath)
		let taskExecutor = FolderCreationTaskExecutor(domainIdentifier: .test, provider: cloudProviderMock, itemMetadataManager: metadataManagerMock, limiter: ConcurrencyLimiter(label: "Test Folder Creations", maxConcurrentOperations: 2))
		let item = try await taskExecutor.execute(task: task)
		XCTAssertEqual(1, metadataManagerMock.updatedMetadata.count)
		XCTAssertEqual(itemMetadata, metadataManagerMock.updatedMetadata[0])
		XCTAssertEqual(ItemStatus.isUploaded, item.metadata.statusCode)
		XCTAssertFalse(item.metadata.isPlaceholderItem)
		XCTAssertEqual(1, cloudProviderMock.createdFolders.count)
		XCTAssertEqual(cloudPath.path, cloudProviderMock.createdFolders[0])
	}

	func testCreateFolderFailWithSameErrorAsProvider() async throws {
		let cloudPath = CloudPath("/NewFolder")
		let itemMetadata = ItemMetadata(id: 2, name: "NewFolder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, isPlaceholderItem: true, isCandidateForCacheCleanup: false)

		let errorCloudProviderMock = CloudProviderErrorMock()
		errorCloudProviderMock.createFolderResponse = { folderPath in
			XCTAssertEqual(cloudPath, folderPath)
			throw CloudTaskTestError.correctPassthrough
		}

		let task = FolderCreationTask(itemMetadata: itemMetadata, cloudPath: cloudPath)
		let taskExecutor = FolderCreationTaskExecutor(domainIdentifier: .test, provider: errorCloudProviderMock, itemMetadataManager: metadataManagerMock, limiter: ConcurrencyLimiter(label: "Test Folder Creations", maxConcurrentOperations: 2))
		await XCTAssertThrowsAsyncError(try await taskExecutor.execute(task: task)) { error in
			guard case CloudTaskTestError.correctPassthrough = error else {
				XCTFail("Rejected with the wrong error: \(error)")
				return
			}
		}
		XCTAssert(metadataManagerMock.cachedMetadata.isEmpty, "Unexpected change of cached metadata.")
		XCTAssert(metadataManagerMock.updatedMetadata.isEmpty, "Unexpected change of cached metadata.")
		XCTAssert(metadataManagerMock.removedMetadataID.isEmpty, "Unexpected change of cached metadata.")
	}

	func testCreateFolderRunsNoMoreRequestsAtOnceThanTheLimiterAllows() async throws {
		let requests = OSAllocatedUnfairLock(initialState: (inFlight: 0, maxInFlight: 0))
		let slowCloudProviderMock = CloudProviderErrorMock()
		slowCloudProviderMock.createFolderResponse = { _ in
			requests.withLock {
				$0.inFlight += 1
				$0.maxInFlight = max($0.maxInFlight, $0.inFlight)
			}
			defer { requests.withLock { $0.inFlight -= 1 } }
			try await Task.sleep(for: .seconds(0.1))
		}
		let limiter = ConcurrencyLimiter(label: "Test Folder Creations", maxConcurrentOperations: 2)

		let executions = (2 ... 6).map { id in
			Task {
				let itemMetadata = ItemMetadata(id: Int64(id), name: "Folder \(id)", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, isPlaceholderItem: true)
				let task = FolderCreationTask(itemMetadata: itemMetadata, cloudPath: CloudPath("/Folder \(id)"))
				let taskExecutor = FolderCreationTaskExecutor(domainIdentifier: .test, provider: slowCloudProviderMock, itemMetadataManager: metadataManagerMock, limiter: limiter)
				return try await taskExecutor.execute(task: task)
			}
		}
		for execution in executions {
			_ = try await execution.value
		}

		XCTAssertEqual(2, requests.withLock { $0.maxInFlight })
	}

	func testCreateFolderReleasesItsPermitWhenTheRequestFails() async throws {
		let failingOnceCloudProviderMock = CloudProviderErrorMock()
		failingOnceCloudProviderMock.createFolderResponse = { cloudPath in
			if cloudPath == CloudPath("/Failing") {
				throw CloudTaskTestError.correctPassthrough
			}
		}
		let limiter = ConcurrencyLimiter(label: "Test Folder Creations", maxConcurrentOperations: 1)
		let taskExecutor = FolderCreationTaskExecutor(domainIdentifier: .test, provider: failingOnceCloudProviderMock, itemMetadataManager: metadataManagerMock, limiter: limiter)
		let failingMetadata = ItemMetadata(id: 2, name: "Failing", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, isPlaceholderItem: true)

		await XCTAssertThrowsAsyncError(try await taskExecutor.execute(task: FolderCreationTask(itemMetadata: failingMetadata, cloudPath: CloudPath("/Failing")))) { error in
			guard case CloudTaskTestError.correctPassthrough = error else {
				XCTFail("Rejected with the wrong error: \(error)")
				return
			}
		}

		let finished = XCTestExpectation(description: "Succeeding folder creation finished")
		let succeeding = Task {
			defer { finished.fulfill() }
			let succeedingMetadata = ItemMetadata(id: 3, name: "Succeeding", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, isPlaceholderItem: true)
			return try await taskExecutor.execute(task: FolderCreationTask(itemMetadata: succeedingMetadata, cloudPath: CloudPath("/Succeeding")))
		}
		let result = await XCTWaiter().fulfillment(of: [finished], timeout: 5.0)
		XCTAssertEqual(.completed, result, "The second folder creation never got a permit")
		guard result == .completed else {
			return
		}
		_ = try await succeeding.value
	}
}
