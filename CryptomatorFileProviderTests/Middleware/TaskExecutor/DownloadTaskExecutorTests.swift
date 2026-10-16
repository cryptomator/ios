//
//  DownloadTaskExecutorTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 25.05.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import GRDB
import os
import XCTest
@testable import CryptomatorFileProvider

class DownloadTaskExecutorTests: CloudTaskExecutorTestCase {
	func testDownloadFile() async throws {
		let localURL = tmpDirectory.appendingPathComponent("localItem.txt", isDirectory: false)
		let cloudPath = CloudPath("/File 1")
		let itemID: Int64 = 2

		let itemMetadata = ItemMetadata(id: itemID, name: "File 1", type: .file, size: 14, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)

		let downloadTaskRecord = try DownloadTaskRecord(correspondingItem: XCTUnwrap(itemMetadata.id), replaceExisting: false, localURL: localURL)
		let downloadTask = DownloadTask(taskRecord: downloadTaskRecord, itemMetadata: itemMetadata, cloudPath: cloudPath, onURLSessionTaskCreation: nil)

		let taskExecutor = createTaskExecutor(provider: cloudProviderMock)

		_ = try await taskExecutor.execute(task: downloadTask)
		let localContent = try Data(contentsOf: localURL)
		XCTAssertEqual(cloudProviderMock.files[cloudPath.path], localContent)
		let localCachedFileInfo = cachedFileManagerMock.cachedLocalFileInfo[itemID]
		XCTAssertNotNil(localCachedFileInfo)
		let lastModifiedDate = localCachedFileInfo?.lastModifiedDate
		XCTAssertNotNil(lastModifiedDate)
		XCTAssertEqual(cloudProviderMock.lastModifiedDate[cloudPath.path], lastModifiedDate)
		XCTAssertEqual(1, metadataManagerMock.updatedMetadata.count)
		XCTAssertEqual(ItemStatus.isUploaded, metadataManagerMock.updatedMetadata[0].statusCode)
		XCTAssertEqual(1, downloadTaskManagerMock.removedTasks.count)
		XCTAssertEqual(downloadTaskRecord, downloadTaskManagerMock.removedTasks[0])
	}

	func testDownloadFileForwardsTaskCreationHookToProvider() async throws {
		let localURL = tmpDirectory.appendingPathComponent("localItem.txt", isDirectory: false)
		let cloudPath = CloudPath("/File 1")
		let itemMetadata = ItemMetadata(id: 2, name: "File 1", type: .file, size: 14, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		let errorCloudProviderMock = CloudProviderErrorMock()
		errorCloudProviderMock.downloadFileResponse = { cloudPath, _ in
			CloudItemMetadata(name: cloudPath.lastPathComponent, cloudPath: cloudPath, itemType: .file, lastModifiedDate: nil, size: 14)
		}

		let hookInvoked = XCTestExpectation(description: "Task creation hook invoked")
		let downloadTaskRecord = DownloadTaskRecord(correspondingItem: 2, replaceExisting: false, localURL: localURL)
		let downloadTask = DownloadTask(taskRecord: downloadTaskRecord, itemMetadata: itemMetadata, cloudPath: cloudPath, onURLSessionTaskCreation: { _ in
			hookInvoked.fulfill()
		})

		_ = try await createTaskExecutor(provider: errorCloudProviderMock).execute(task: downloadTask)
		let receivedHook = try XCTUnwrap(errorCloudProviderMock.downloadFileReceivedOnTaskCreation)
		try await receivedHook(URLSession.shared.downloadTask(with: XCTUnwrap(URL(string: "https://example.com/"))))
		await fulfillment(of: [hookInvoked], timeout: 1.0)
	}

	func testDownloadFileFailWithSameErrorAsProvider() async throws {
		let localURL = tmpDirectory.appendingPathComponent("itemNotFound.txt", isDirectory: false)
		let cloudPath = CloudPath("/itemNotFound.txt")

		let itemMetadata = ItemMetadata(id: 3, name: "itemNotFound.txt", type: .file, size: 14, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		let errorCloudProviderMock = CloudProviderErrorMock()
		errorCloudProviderMock.downloadFileResponse = { _, _ in
			throw CloudTaskTestError.correctPassthrough
		}

		let downloadTaskRecord = try DownloadTaskRecord(correspondingItem: XCTUnwrap(itemMetadata.id), replaceExisting: false, localURL: localURL)
		let downloadTask = DownloadTask(taskRecord: downloadTaskRecord, itemMetadata: itemMetadata, cloudPath: cloudPath, onURLSessionTaskCreation: nil)

		let taskExecutor = createTaskExecutor(provider: errorCloudProviderMock)

		await XCTAssertThrowsAsyncError(try await taskExecutor.execute(task: downloadTask)) { error in
			guard case CloudTaskTestError.correctPassthrough = error else {
				XCTFail("Rejected with the wrong error: \(error)")
				return
			}
		}
		XCTAssert(metadataManagerMock.cachedMetadata.isEmpty, "Unexpected change of cached metadata.")
		XCTAssertEqual(1, downloadTaskManagerMock.removedTasks.count)
		XCTAssertEqual(downloadTaskRecord, downloadTaskManagerMock.removedTasks[0])
	}

	func testDownloadFileCancelledByProviderRemovesTaskRecordAndPropagatesError() async throws {
		let localURL = tmpDirectory.appendingPathComponent("localItem.txt", isDirectory: false)
		let cloudPath = CloudPath("/File 1")
		let itemMetadata = ItemMetadata(id: 2, name: "File 1", type: .file, size: 14, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		let errorCloudProviderMock = CloudProviderErrorMock()
		errorCloudProviderMock.downloadFileResponse = { _, _ in
			throw CancellationError()
		}

		let downloadTaskRecord = try DownloadTaskRecord(correspondingItem: XCTUnwrap(itemMetadata.id), replaceExisting: false, localURL: localURL)
		let downloadTask = DownloadTask(taskRecord: downloadTaskRecord, itemMetadata: itemMetadata, cloudPath: cloudPath, onURLSessionTaskCreation: nil)

		let taskExecutor = createTaskExecutor(provider: errorCloudProviderMock)

		await XCTAssertThrowsAsyncError(try await taskExecutor.execute(task: downloadTask)) { error in
			XCTAssert(error is CancellationError, "Rejected with the wrong error: \(error)")
		}
		XCTAssertEqual([downloadTaskRecord], downloadTaskManagerMock.removedTasks)
		XCTAssert(metadataManagerMock.updatedMetadata.isEmpty)
		XCTAssertNil(cachedFileManagerMock.cachedLocalFileInfo[2])
	}

	func testFailedDownloadReleasesItsPermit() async throws {
		let limiter = ConcurrencyLimiter(label: "Test Downloads", maxConcurrentOperations: 1)
		let errorCloudProviderMock = CloudProviderErrorMock()
		errorCloudProviderMock.downloadFileResponse = { _, _ in
			throw CloudProviderError.noInternetConnection
		}
		let failingItemMetadata = ItemMetadata(id: 3, name: "File 2", type: .file, size: 14, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		let failingTaskRecord = DownloadTaskRecord(correspondingItem: 3, replaceExisting: false, localURL: tmpDirectory.appendingPathComponent("failing.txt", isDirectory: false))
		let failingTask = DownloadTask(taskRecord: failingTaskRecord, itemMetadata: failingItemMetadata, cloudPath: CloudPath("/File 2"), onURLSessionTaskCreation: nil)
		await XCTAssertThrowsAsyncError(try await createTaskExecutor(provider: errorCloudProviderMock, limiter: limiter).execute(task: failingTask))

		let localURL = tmpDirectory.appendingPathComponent("localItem.txt", isDirectory: false)
		let itemMetadata = ItemMetadata(id: 2, name: "File 1", type: .file, size: 14, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		let taskRecord = DownloadTaskRecord(correspondingItem: 2, replaceExisting: false, localURL: localURL)
		let task = DownloadTask(taskRecord: taskRecord, itemMetadata: itemMetadata, cloudPath: CloudPath("/File 1"), onURLSessionTaskCreation: nil)
		let taskExecutor = createTaskExecutor(provider: cloudProviderMock, limiter: limiter)
		let finished = XCTestExpectation(description: "Second download finished")
		let secondDownload = Task {
			defer { finished.fulfill() }
			return try await taskExecutor.execute(task: task)
		}
		let result = await XCTWaiter().fulfillment(of: [finished], timeout: 2.0)
		XCTAssertEqual(.completed, result, "The second download never got a permit")
		guard result == .completed else {
			return
		}
		let item = try await secondDownload.value
		XCTAssertEqual(localURL, item.localURL)
	}

	func testDownloadCachesLastModifiedDateReturnedByDownloadWithoutFetchingMetadata() async throws {
		let localURL = tmpDirectory.appendingPathComponent("localItem.txt", isDirectory: false)
		let cloudPath = CloudPath("/File 1")
		let downloadedLastModifiedDate = Date(timeIntervalSince1970: 100)
		let fetchedLastModifiedDate = Date(timeIntervalSince1970: 200)
		let fetchItemMetadataCallsCount = OSAllocatedUnfairLock(initialState: 0)
		let errorCloudProviderMock = CloudProviderErrorMock()
		errorCloudProviderMock.fetchItemMetadataResponse = { cloudPath in
			fetchItemMetadataCallsCount.withLock { $0 += 1 }
			return CloudItemMetadata(name: cloudPath.lastPathComponent, cloudPath: cloudPath, itemType: .file, lastModifiedDate: fetchedLastModifiedDate, size: 14)
		}
		errorCloudProviderMock.downloadFileResponse = { cloudPath, localURL in
			try Data("File 1 content".utf8).write(to: localURL, options: .withoutOverwriting)
			return CloudItemMetadata(name: cloudPath.lastPathComponent, cloudPath: cloudPath, itemType: .file, lastModifiedDate: downloadedLastModifiedDate, size: 14)
		}
		let itemMetadata = ItemMetadata(id: 2, name: "File 1", type: .file, size: 14, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		let downloadTaskRecord = DownloadTaskRecord(correspondingItem: 2, replaceExisting: false, localURL: localURL)
		let downloadTask = DownloadTask(taskRecord: downloadTaskRecord, itemMetadata: itemMetadata, cloudPath: cloudPath, onURLSessionTaskCreation: nil)

		_ = try await createTaskExecutor(provider: errorCloudProviderMock).execute(task: downloadTask)

		XCTAssertEqual(0, fetchItemMetadataCallsCount.withLock { $0 })
		XCTAssertEqual(downloadedLastModifiedDate, cachedFileManagerMock.cachedLocalFileInfo[2]?.lastModifiedDate)
	}

	func testDownloadFileReplaceExisting() async throws {
		let localURL = tmpDirectory.appendingPathComponent("localItem.txt", isDirectory: false)
		let existingLocalContent = "Old Local FileContent"
		try existingLocalContent.write(to: localURL, atomically: true, encoding: .utf8)
		let existingLocalContentData = try Data(contentsOf: localURL)
		let cloudPath = CloudPath("/File 1")
		let itemID: Int64 = 2
		let itemMetadata = ItemMetadata(id: itemID, name: "File 1", type: .file, size: 14, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)

		let downloadTaskRecord = try DownloadTaskRecord(correspondingItem: XCTUnwrap(itemMetadata.id), replaceExisting: true, localURL: localURL)
		let downloadTask = DownloadTask(taskRecord: downloadTaskRecord, itemMetadata: itemMetadata, cloudPath: cloudPath, onURLSessionTaskCreation: nil)

		let taskExecutor = createTaskExecutor(provider: cloudProviderMock)

		_ = try await taskExecutor.execute(task: downloadTask)
		let localContent = try Data(contentsOf: localURL)
		XCTAssertEqual(cloudProviderMock.files[cloudPath.path], localContent)
		XCTAssertNotEqual(existingLocalContentData, localContent)
		let cachedLocalFileInfo = cachedFileManagerMock.cachedLocalFileInfo[itemID]
		XCTAssertNotNil(cachedLocalFileInfo)
		let lastModifiedDate = cachedLocalFileInfo?.lastModifiedDate
		XCTAssertNotNil(lastModifiedDate)
		XCTAssertEqual(cloudProviderMock.lastModifiedDate[cloudPath.path], lastModifiedDate)

		XCTAssertEqual(1, metadataManagerMock.updatedMetadata.count)
		XCTAssertEqual(ItemStatus.isUploaded, metadataManagerMock.updatedMetadata[0].statusCode)
		XCTAssertEqual(1, downloadTaskManagerMock.removedTasks.count)
		XCTAssertEqual(downloadTaskRecord, downloadTaskManagerMock.removedTasks[0])
	}

	func testDownloadPostProcessingForReplaceExisting() throws {
		let cloudPath = CloudPath("/File 1")
		let itemID: Int64 = 2
		let itemMetadata = ItemMetadata(id: itemID, name: "File 1", type: .file, size: 14, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)

		let localURL = tmpDirectory.appendingPathComponent("localItem.txt", isDirectory: false)
		let existingLocalContent = "Old Local FileContent"
		try existingLocalContent.write(to: localURL, atomically: true, encoding: .utf8)

		let downloadDestination = tmpDirectory.appendingPathComponent("localItem-12345.txt", isDirectory: false)
		let downloadedContent = "Downloaded FileContent"
		try downloadedContent.write(to: downloadDestination, atomically: true, encoding: .utf8)

		let lastModifiedDate = Date(timeIntervalSince1970: 0)

		let taskExecutor = createTaskExecutor(provider: cloudProviderMock)

		let item = try taskExecutor.downloadPostProcessing(for: itemMetadata, lastModifiedDate: lastModifiedDate, localURL: localURL, downloadDestination: downloadDestination)
		XCTAssert(FileManager.default.fileExists(atPath: localURL.path))
		XCTAssertFalse(FileManager.default.fileExists(atPath: downloadDestination.path))
		let localURLContent = try String(contentsOf: localURL, encoding: .utf8)
		XCTAssertEqual(downloadedContent, localURLContent)
		XCTAssertEqual(localURL, item.localURL)
		XCTAssert(item.newestVersionLocallyCached)
		XCTAssertEqual(itemMetadata, item.metadata)

		guard let localCachedFileInfo = try cachedFileManagerMock.getLocalCachedFileInfo(for: itemID) else {
			XCTFail("No LocalCachedFileInfo found")
			return
		}
		XCTAssertEqual(lastModifiedDate, localCachedFileInfo.lastModifiedDate)
		XCTAssertEqual(localURL, localCachedFileInfo.localURL)
	}

	func testDownloadPostProcessingForNewFile() throws {
		let cloudPath = CloudPath("/File 1")
		let itemID: Int64 = 2
		let itemMetadata = ItemMetadata(id: itemID, name: "File 1", type: .file, size: 14, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)

		let localURL = tmpDirectory.appendingPathComponent("localItem.txt", isDirectory: false)
		let downloadedContent = "Downloaded FileContent"
		try downloadedContent.write(to: localURL, atomically: true, encoding: .utf8)

		let lastModifiedDate = Date(timeIntervalSince1970: 0)

		let taskExecutor = createTaskExecutor(provider: cloudProviderMock)

		let item = try taskExecutor.downloadPostProcessing(for: itemMetadata, lastModifiedDate: lastModifiedDate, localURL: localURL, downloadDestination: localURL)
		XCTAssert(FileManager.default.fileExists(atPath: localURL.path))
		let localURLContent = try String(contentsOf: localURL, encoding: .utf8)
		XCTAssertEqual(downloadedContent, localURLContent)
		XCTAssertEqual(localURL, item.localURL)
		XCTAssert(item.newestVersionLocallyCached)
		XCTAssertEqual(itemMetadata, item.metadata)

		guard let localCachedFileInfo = try cachedFileManagerMock.getLocalCachedFileInfo(for: itemID) else {
			XCTFail("No LocalCachedFileInfo found")
			return
		}
		XCTAssertEqual(lastModifiedDate, localCachedFileInfo.lastModifiedDate)
		XCTAssertEqual(localURL, localCachedFileInfo.localURL)
	}

	private func createTaskExecutor(provider: CloudProvider, limiter: ConcurrencyLimiter = ConcurrencyLimiter(label: "Test Downloads", maxConcurrentOperations: 1)) -> DownloadTaskExecutor {
		return DownloadTaskExecutor(domainIdentifier: .test, provider: provider, itemMetadataManager: metadataManagerMock, cachedFileManager: cachedFileManagerMock, downloadTaskManager: downloadTaskManagerMock, limiter: limiter)
	}
}

extension DownloadTaskRecord: Equatable {
	public static func == (lhs: DownloadTaskRecord, rhs: DownloadTaskRecord) -> Bool {
		return lhs.correspondingItem == rhs.correspondingItem && lhs.replaceExisting == rhs.replaceExisting && lhs.localURL == rhs.localURL
	}
}
