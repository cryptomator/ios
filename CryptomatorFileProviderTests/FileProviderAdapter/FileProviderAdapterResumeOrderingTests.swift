//
//  FileProviderAdapterResumeOrderingTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Tobias Hagemann on 17.06.26.
//  Copyright © 2026 Skymatic GmbH. All rights reserved.
//

import FileProvider
import Foundation
import XCTest
@testable import CryptomatorCommonCore
@testable import CryptomatorFileProvider

/// A WebDAV transfer task must be resumed only *after* `NSFileProviderManager.register(_:forItemWithIdentifier:)`
/// completes. Resuming beforehand starts the transfer before the system is tracking it, which loses progress
/// reporting and can leave the File Provider hanging (issue #449). Registration must still resume on failure so a
/// transfer is never silently dropped (issue #272).
final class FileProviderAdapterResumeOrderingTests: FileProviderAdapterTestCase {
	private let downloadIdentifier = NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: 2)
	private let uploadIdentifier = NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: 3)

	override func setUpWithError() throws {
		try super.setUpWithError()
		metadataManagerMock.cachedMetadata[2] = ItemMetadata(id: 2, name: "download.txt", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		metadataManagerMock.cachedMetadata[3] = ItemMetadata(id: 3, name: "upload.txt", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, isPlaceholderItem: false)
	}

	// MARK: - Download

	func testDownloadResumesTaskOnlyAfterRegistrationCompletes() throws {
		let adapter = createFullyMockedAdapter()
		let task = ResumeRecordingURLSessionTask()
		_ = adapter.downloadFile(with: downloadIdentifier, to: URL(fileURLWithPath: "/dev/null"))
		let onURLSessionTaskCreation = try XCTUnwrap(downloadTaskManagerMock.lastOnURLSessionTaskCreation)

		onURLSessionTaskCreation(task)

		XCTAssertTrue(taskRegistratorMock.registerForItemWithIdentifierCompletionHandlerCalled)
		XCTAssertEqual(task.resumeCallCount, 0, "the download must not be resumed before registration completes")

		let completion = try XCTUnwrap(taskRegistratorMock.registerForItemWithIdentifierCompletionHandlerReceivedArguments?.completion)
		completion(nil)
		XCTAssertEqual(task.resumeCallCount, 1)
	}

	func testDownloadResumesTaskEvenWhenRegistrationFails() throws {
		let adapter = createFullyMockedAdapter()
		let task = ResumeRecordingURLSessionTask()
		_ = adapter.downloadFile(with: downloadIdentifier, to: URL(fileURLWithPath: "/dev/null"))
		let onURLSessionTaskCreation = try XCTUnwrap(downloadTaskManagerMock.lastOnURLSessionTaskCreation)

		onURLSessionTaskCreation(task)
		let completion = try XCTUnwrap(taskRegistratorMock.registerForItemWithIdentifierCompletionHandlerReceivedArguments?.completion)
		completion(NSError(domain: "test", code: 1))

		XCTAssertEqual(task.resumeCallCount, 1, "a failed registration must still resume the download")
	}

	// MARK: - Upload

	func testUploadResumesTaskOnlyAfterRegistrationCompletes() throws {
		let adapter = createFullyMockedAdapter()
		let task = ResumeRecordingURLSessionTask()
		let taskRecord = UploadTaskRecord(correspondingItem: 3, lastFailedUploadDate: nil, uploadErrorCode: nil, uploadErrorDomain: nil, uploadStartedAt: Date())

		_ = adapter.uploadFile(taskRecord: taskRecord, itemIdentifier: uploadIdentifier)
		let onURLSessionTaskCreation = try XCTUnwrap(uploadTaskManagerMock.getTaskForOnURLSessionTaskCreationReceivedArguments?.onURLSessionTaskCreation)

		onURLSessionTaskCreation(task)
		XCTAssertEqual(task.resumeCallCount, 0, "the upload must not be resumed before registration completes")

		let completion = try XCTUnwrap(taskRegistratorMock.registerForItemWithIdentifierCompletionHandlerReceivedArguments?.completion)
		completion(nil)
		XCTAssertEqual(task.resumeCallCount, 1)
	}

	func testUploadResumesTaskEvenWhenRegistrationFails() throws {
		let adapter = createFullyMockedAdapter()
		let task = ResumeRecordingURLSessionTask()
		let taskRecord = UploadTaskRecord(correspondingItem: 3, lastFailedUploadDate: nil, uploadErrorCode: nil, uploadErrorDomain: nil, uploadStartedAt: Date())

		_ = adapter.uploadFile(taskRecord: taskRecord, itemIdentifier: uploadIdentifier)
		let onURLSessionTaskCreation = try XCTUnwrap(uploadTaskManagerMock.getTaskForOnURLSessionTaskCreationReceivedArguments?.onURLSessionTaskCreation)

		onURLSessionTaskCreation(task)
		let completion = try XCTUnwrap(taskRegistratorMock.registerForItemWithIdentifierCompletionHandlerReceivedArguments?.completion)
		completion(NSError(domain: "test", code: 1))

		XCTAssertEqual(task.resumeCallCount, 1, "a failed registration must still resume the upload")
	}
}

private final class ResumeRecordingURLSessionTask: URLSessionTask, @unchecked Sendable {
	private(set) var resumeCallCount = 0

	override func resume() {
		resumeCallCount += 1
	}

	override func cancel() {}
}
