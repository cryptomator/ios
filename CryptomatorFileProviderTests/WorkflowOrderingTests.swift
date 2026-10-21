//
//  WorkflowOrderingTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Tobias Hagemann on 15.10.26.
//  Copyright © 2026 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import os
import XCTest
@testable import CryptomatorFileProvider

class WorkflowOrderingTests: CloudTaskExecutorTestCase {
	var provider: CloudProviderErrorMock!
	var workflowFactory: WorkflowFactory!
	let scheduler = WorkflowScheduler()
	let events = EventLog()

	override func setUp() async throws {
		try await super.setUp()
		provider = CloudProviderErrorMock()
		workflowFactory = WorkflowFactory(provider: provider,
		                                  uploadTaskManager: uploadTaskManagerMock,
		                                  cachedFileManager: cachedFileManagerMock,
		                                  itemMetadataManager: metadataManagerMock,
		                                  reparentTaskManager: reparentTaskManagerMock,
		                                  deletionTaskManager: deletionTaskManagerMock,
		                                  itemEnumerationTaskManager: itemEnumerationTaskManagerMock,
		                                  downloadTaskManager: downloadTaskManagerMock,
		                                  maxParallelUploads: 1,
		                                  maxParallelDownloads: 1,
		                                  domainIdentifier: .test)
	}

	func testBlockedUploadDoesNotOccupyTheOnlyUploadPermit() async throws {
		let release = OneShotSignal<Void>()
		provider.deleteFolderResponse = { _ in
			try await release.value
		}
		let unrelatedUploadReached = XCTestExpectation(description: "Unrelated upload reached the provider")
		let blockedUploadReached = XCTestExpectation(description: "Blocked upload reached the provider")
		provider.uploadFileResponse = { [events] _, cloudPath, _ in
			events.append("uploadFile \(cloudPath.path)")
			if cloudPath == CloudPath("/y/g") {
				unrelatedUploadReached.fulfill()
			} else {
				blockedUploadReached.fulfill()
			}
			return CloudItemMetadata(name: cloudPath.lastPathComponent, cloudPath: cloudPath, itemType: .file, lastModifiedDate: nil, size: 0)
		}

		let deletion = schedule(workflowFactory.createWorkflow(for: makeDeletionTask(id: 2, at: CloudPath("/x"))))
		let blockedUpload = try schedule(workflowFactory.createWorkflow(for: makeUploadTask(id: 3, at: CloudPath("/x/f"))))
		let unrelatedUpload = try schedule(workflowFactory.createWorkflow(for: makeUploadTask(id: 4, at: CloudPath("/y/g"))))

		await fulfillment(of: [unrelatedUploadReached], timeout: 2.0)
		events.append("release deletion")
		release.fulfill(())
		await fulfillment(of: [blockedUploadReached], timeout: 2.0)

		_ = try await deletion.value
		_ = try await blockedUpload.value
		_ = try await unrelatedUpload.value
		XCTAssertEqual(["uploadFile /y/g", "release deletion", "uploadFile /x/f"], events.entries)
	}

	func testBlockedDownloadDoesNotOccupyTheOnlyDownloadPermit() async throws {
		let release = OneShotSignal<Void>()
		provider.deleteFolderResponse = { _ in
			try await release.value
		}
		let unrelatedDownloadReached = XCTestExpectation(description: "Unrelated download reached the provider")
		let blockedDownloadReached = XCTestExpectation(description: "Blocked download reached the provider")
		provider.downloadFileResponse = { [events] cloudPath, _ in
			events.append("downloadFile \(cloudPath.path)")
			if cloudPath == CloudPath("/y/g") {
				unrelatedDownloadReached.fulfill()
			} else {
				blockedDownloadReached.fulfill()
			}
			throw CloudProviderError.noInternetConnection
		}

		let deletion = schedule(workflowFactory.createWorkflow(for: makeDeletionTask(id: 2, at: CloudPath("/x"))))
		let blockedDownload = schedule(workflowFactory.createWorkflow(for: makeDownloadTask(id: 3, at: CloudPath("/x/f"))))
		let unrelatedDownload = schedule(workflowFactory.createWorkflow(for: makeDownloadTask(id: 4, at: CloudPath("/y/g"))))

		await fulfillment(of: [unrelatedDownloadReached], timeout: 2.0)
		events.append("release deletion")
		release.fulfill(())
		await fulfillment(of: [blockedDownloadReached], timeout: 2.0)

		_ = try await deletion.value
		_ = await blockedDownload.result
		_ = await unrelatedDownload.result
		XCTAssertEqual(["downloadFile /y/g", "release deletion", "downloadFile /x/f"], events.entries)
	}

	func testUploadBudgetSerializesUnrelatedUploads() async throws {
		let release = OneShotSignal<Void>()
		let firstUploadReached = XCTestExpectation(description: "First upload reached the provider")
		let secondUploadReached = OneShotSignal<Void>()
		let uploadCount = OSAllocatedUnfairLock(initialState: 0)
		provider.uploadFileResponse = { _, cloudPath, _ in
			if uploadCount.withLock({ $0 += 1; return $0 }) == 1 {
				firstUploadReached.fulfill()
				try await release.value
			} else {
				secondUploadReached.fulfill(())
			}
			return CloudItemMetadata(name: cloudPath.lastPathComponent, cloudPath: cloudPath, itemType: .file, lastModifiedDate: nil, size: 0)
		}

		let firstUpload = try schedule(workflowFactory.createWorkflow(for: makeUploadTask(id: 2, at: CloudPath("/x"))))
		let secondUpload = try schedule(workflowFactory.createWorkflow(for: makeUploadTask(id: 3, at: CloudPath("/y"))))

		await fulfillment(of: [firstUploadReached], timeout: 2.0)
		await assertStaysBlocked { try await secondUploadReached.value }
		release.fulfill(())

		_ = try await firstUpload.value
		_ = try await secondUpload.value
	}

	func testDownloadBudgetSerializesUnrelatedDownloads() async {
		let release = OneShotSignal<Void>()
		let firstDownloadReached = XCTestExpectation(description: "First download reached the provider")
		let secondDownloadReached = OneShotSignal<Void>()
		let downloadCount = OSAllocatedUnfairLock(initialState: 0)
		provider.downloadFileResponse = { _, _ in
			if downloadCount.withLock({ $0 += 1; return $0 }) == 1 {
				firstDownloadReached.fulfill()
				try await release.value
			} else {
				secondDownloadReached.fulfill(())
			}
			throw CloudProviderError.noInternetConnection
		}

		let firstDownload = schedule(workflowFactory.createWorkflow(for: makeDownloadTask(id: 2, at: CloudPath("/x"))))
		let secondDownload = schedule(workflowFactory.createWorkflow(for: makeDownloadTask(id: 3, at: CloudPath("/y"))))

		await fulfillment(of: [firstDownloadReached], timeout: 2.0)
		await assertStaysBlocked { try await secondDownloadReached.value }
		release.fulfill(())

		_ = await firstDownload.result
		_ = await secondDownload.result
	}

	func testUploadInFlightDoesNotOccupyTheDownloadBudget() async throws {
		let release = OneShotSignal<Void>()
		let uploadReached = XCTestExpectation(description: "Upload reached the provider")
		provider.uploadFileResponse = { _, cloudPath, _ in
			uploadReached.fulfill()
			try await release.value
			return CloudItemMetadata(name: cloudPath.lastPathComponent, cloudPath: cloudPath, itemType: .file, lastModifiedDate: nil, size: 0)
		}
		let downloadReached = XCTestExpectation(description: "Download reached the provider")
		provider.downloadFileResponse = { _, _ in
			downloadReached.fulfill()
			throw CloudProviderError.noInternetConnection
		}

		let upload = try schedule(workflowFactory.createWorkflow(for: makeUploadTask(id: 2, at: CloudPath("/x"))))
		await fulfillment(of: [uploadReached], timeout: 2.0)
		let download = schedule(workflowFactory.createWorkflow(for: makeDownloadTask(id: 3, at: CloudPath("/y"))))

		await fulfillment(of: [downloadReached], timeout: 2.0)
		release.fulfill(())

		_ = try await upload.value
		_ = await download.result
	}

	func testQueuedUploadKeepsItsCacheWhenItsFileChangesWhileWaitingForAPermit() async throws {
		let release = OneShotSignal<Void>()
		let permitHolderReached = XCTestExpectation(description: "Permit-holding upload reached the provider")
		let queuedUploadReached = OneShotSignal<Void>()
		provider.uploadFileResponse = { localURL, cloudPath, _ in
			if cloudPath == CloudPath("/x") {
				permitHolderReached.fulfill()
				try await release.value
			} else {
				queuedUploadReached.fulfill(())
			}
			let data = try Data(contentsOf: localURL)
			return CloudItemMetadata(name: cloudPath.lastPathComponent, cloudPath: cloudPath, itemType: .file, lastModifiedDate: nil, size: data.count)
		}

		let permitHolder = try schedule(workflowFactory.createWorkflow(for: makeUploadTask(id: 2, at: CloudPath("/x"))))
		await fulfillment(of: [permitHolderReached], timeout: 2.0)
		let queuedUpload = try schedule(workflowFactory.createWorkflow(for: makeUploadTask(id: 3, at: CloudPath("/y"))))
		await assertStaysBlocked { try await queuedUploadReached.value }
		let localURL = try XCTUnwrap(cachedFileManagerMock.cachedLocalFileInfo[3]?.localURL)
		try Data("changed while queued".utf8).write(to: localURL)
		release.fulfill(())

		_ = try await permitHolder.value
		let item = try await queuedUpload.value
		XCTAssertNil(item.uploadingError)
		XCTAssertFalse(cachedFileManagerMock.removeCachedFile.contains(3), "Removed the cache of the version that was uploaded")
		XCTAssertEqual(localURL, cachedFileManagerMock.cachedLocalFileInfo[3]?.localURL)
		XCTAssertTrue(FileManager.default.fileExists(atPath: localURL.path))
	}

	func testFailedDeletionReleasesItsDependents() async throws {
		provider.deleteFolderResponse = { _ in
			throw CloudProviderError.noInternetConnection
		}
		let uploadReached = XCTestExpectation(description: "Dependent upload reached the provider")
		provider.uploadFileResponse = { _, cloudPath, _ in
			uploadReached.fulfill()
			return CloudItemMetadata(name: cloudPath.lastPathComponent, cloudPath: cloudPath, itemType: .file, lastModifiedDate: nil, size: 0)
		}

		let deletion = schedule(workflowFactory.createWorkflow(for: makeDeletionTask(id: 2, at: CloudPath("/x"))))
		let upload = try schedule(workflowFactory.createWorkflow(for: makeUploadTask(id: 3, at: CloudPath("/x"))))

		await fulfillment(of: [uploadReached], timeout: 2.0)
		await XCTAssertThrowsAsyncError(try await deletion.value)
		_ = try await upload.value
	}

	// MARK: - Helpers

	private func schedule<T: Sendable>(_ workflow: Workflow<T>) -> Task<T, Error> {
		return Task {
			try await scheduler.schedule(workflow)
		}
	}

	private func makeDeletionTask(id: Int64, at cloudPath: CloudPath) -> DeletionTask {
		let itemMetadata = ItemMetadata(id: id, name: cloudPath.lastPathComponent, type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		let taskRecord = DeletionTaskRecord(correspondingItem: id, cloudPath: cloudPath, parentID: itemMetadata.parentID, itemType: .folder)
		return DeletionTask(taskRecord: taskRecord, itemMetadata: itemMetadata, cloudPath: cloudPath)
	}

	private func makeUploadTask(id: Int64, at cloudPath: CloudPath) throws -> UploadTask {
		let localURL = tmpDirectory.appendingPathComponent("\(id)", isDirectory: false)
		try Data().write(to: localURL)
		cachedFileManagerMock.cachedLocalFileInfo[id] = LocalCachedFileInfo(lastModifiedDate: nil, correspondingItem: id, localLastModifiedDate: Date(), localURL: localURL)
		let itemMetadata = ItemMetadata(id: id, name: cloudPath.lastPathComponent, type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, isPlaceholderItem: true)
		let taskRecord = UploadTaskRecord(correspondingItem: id, lastFailedUploadDate: nil, uploadErrorCode: nil, uploadErrorDomain: nil, uploadStartedAt: nil)
		return UploadTask(taskRecord: taskRecord, itemMetadata: itemMetadata, cloudPath: cloudPath, onURLSessionTaskCreation: nil)
	}

	private func makeDownloadTask(id: Int64, at cloudPath: CloudPath) -> DownloadTask {
		let itemMetadata = ItemMetadata(id: id, name: cloudPath.lastPathComponent, type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		let taskRecord = DownloadTaskRecord(correspondingItem: id, replaceExisting: false, localURL: tmpDirectory.appendingPathComponent("\(id)", isDirectory: false))
		return DownloadTask(taskRecord: taskRecord, itemMetadata: itemMetadata, cloudPath: cloudPath, onURLSessionTaskCreation: nil)
	}

	final class EventLog: Sendable {
		private let state = OSAllocatedUnfairLock(initialState: [String]())

		var entries: [String] {
			state.withLock { $0 }
		}

		func append(_ entry: String) {
			state.withLock { $0.append(entry) }
		}
	}
}
