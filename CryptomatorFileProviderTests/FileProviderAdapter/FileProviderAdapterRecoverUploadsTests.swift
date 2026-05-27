//
//  FileProviderAdapterRecoverUploadsTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Tobias Hagemann.
//  Copyright © 2026 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Dependencies
import Foundation
import Promises
import XCTest
@testable import CryptomatorCommonCore
@testable import CryptomatorFileProvider

class FileProviderAdapterRecoverUploadsTests: FileProviderAdapterTestCase {
	let itemID: Int64 = 2

	func testRecoverStuckUploads_noActiveUploads() {
		uploadTaskManagerMock.getActiveUploadTaskRecordsReturnValue = []
		uploadTaskManagerMock.getRetryableUploadTaskRecordsReturnValue = []

		adapter.recoverStuckUploads()

		XCTAssertEqual(1, uploadTaskManagerMock.getActiveUploadTaskRecordsCallsCount)
		XCTAssertEqual(1, uploadTaskManagerMock.getRetryableUploadTaskRecordsCallsCount)
		XCTAssertFalse(uploadTaskManagerMock.removeTaskRecordForCalled)
	}

	func testRecoverStuckUploads_removesOrphanedTaskRecord() {
		let taskRecord = UploadTaskRecord(correspondingItem: itemID, lastFailedUploadDate: nil, uploadErrorCode: nil, uploadErrorDomain: nil, uploadStartedAt: Date())
		uploadTaskManagerMock.getActiveUploadTaskRecordsReturnValue = [taskRecord]
		// No metadata exists for this item
		metadataManagerMock.cachedMetadata.removeAll()

		adapter.recoverStuckUploads()

		XCTAssertEqual(1, uploadTaskManagerMock.removeTaskRecordForCallsCount)
		XCTAssertEqual(itemID, uploadTaskManagerMock.removeTaskRecordForReceivedId)
	}

	func testRecoverStuckUploads_marksErrorWhenLocalFileMissing() throws {
		let cloudPath = CloudPath("/File.txt")
		let itemMetadata = ItemMetadata(id: itemID, name: "File.txt", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, cloudPath: cloudPath, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(itemMetadata)

		let taskRecord = UploadTaskRecord(correspondingItem: itemID, lastFailedUploadDate: nil, uploadErrorCode: nil, uploadErrorDomain: nil, uploadStartedAt: Date())
		uploadTaskManagerMock.getActiveUploadTaskRecordsReturnValue = [taskRecord]
		// No cached file info exists

		adapter.recoverStuckUploads()

		XCTAssertTrue(uploadTaskManagerMock.updateTaskRecordWithLastFailedUploadDateUploadErrorCodeUploadErrorDomainCalled)
		let updateArgs = uploadTaskManagerMock.updateTaskRecordWithLastFailedUploadDateUploadErrorCodeUploadErrorDomainReceivedArguments
		XCTAssertEqual(itemID, updateArgs?.id)
		XCTAssertEqual(NSFileProviderErrorDomain, updateArgs?.uploadErrorDomain)
		XCTAssertEqual(NSFileProviderError(.noSuchItem).errorCode, updateArgs?.uploadErrorCode)
	}

	func testRecoverStuckUploads_reschedulesWhenLocalFileExists() throws {
		let cloudPath = CloudPath("/File.txt")
		let itemMetadata = ItemMetadata(id: itemID, name: "File.txt", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, cloudPath: cloudPath, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(itemMetadata)

		// Create a local file
		let localURL = tmpDirectory.appendingPathComponent("File.txt")
		try "TestContent".write(to: localURL, atomically: true, encoding: .utf8)
		try cachedFileManagerMock.cacheLocalFileInfo(for: itemID, localURL: localURL, lastModifiedDate: Date())

		let taskRecord = UploadTaskRecord(correspondingItem: itemID, lastFailedUploadDate: nil, uploadErrorCode: nil, uploadErrorDomain: nil, uploadStartedAt: Date())
		uploadTaskManagerMock.getActiveUploadTaskRecordsReturnValue = [taskRecord]

		let adapter = createFullyMockedAdapter()
		adapter.recoverStuckUploads()

		// Verify the upload was re-registered
		XCTAssertTrue(uploadTaskManagerMock.createNewTaskRecordForCalled)
		XCTAssertEqual(itemID, uploadTaskManagerMock.createNewTaskRecordForReceivedInvocations.last?.id)
	}

	// MARK: - Connectivity-Failed Upload Retry

	func testRecoverStuckUploads_retriesConnectivityFailedUploads() throws {
		let cloudPath = CloudPath("/OfflineFile.txt")
		let itemMetadata = ItemMetadata(id: itemID, name: "OfflineFile.txt", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .uploadError, cloudPath: cloudPath, isPlaceholderItem: true)
		try metadataManagerMock.cacheMetadata(itemMetadata)

		// Create a local file
		let localURL = tmpDirectory.appendingPathComponent("OfflineFile.txt")
		try "OfflineContent".write(to: localURL, atomically: true, encoding: .utf8)
		try cachedFileManagerMock.cacheLocalFileInfo(for: itemID, localURL: localURL, lastModifiedDate: Date())

		let serverUnreachableError = NSFileProviderError(.serverUnreachable) as NSError
		let taskRecord = UploadTaskRecord(correspondingItem: itemID, lastFailedUploadDate: Date(), uploadErrorCode: serverUnreachableError.code, uploadErrorDomain: serverUnreachableError.domain, uploadStartedAt: Date())
		uploadTaskManagerMock.getActiveUploadTaskRecordsReturnValue = []
		uploadTaskManagerMock.getRetryableUploadTaskRecordsReturnValue = [taskRecord]

		let adapter = createFullyMockedAdapter()
		adapter.recoverStuckUploads()

		// Verify the upload was re-registered
		XCTAssertTrue(uploadTaskManagerMock.createNewTaskRecordForCalled)
		XCTAssertEqual(itemID, uploadTaskManagerMock.createNewTaskRecordForReceivedInvocations.last?.id)
	}

	func testRecoverStuckUploads_noRetryableUploads() {
		uploadTaskManagerMock.getActiveUploadTaskRecordsReturnValue = []
		uploadTaskManagerMock.getRetryableUploadTaskRecordsReturnValue = []

		adapter.recoverStuckUploads()

		XCTAssertEqual(1, uploadTaskManagerMock.getActiveUploadTaskRecordsCallsCount)
		XCTAssertEqual(1, uploadTaskManagerMock.getRetryableUploadTaskRecordsCallsCount)
		XCTAssertFalse(uploadTaskManagerMock.createNewTaskRecordForCalled)
	}

	func testRecoverStuckUploads_removesOrphanedRetryableTaskRecord() {
		let serverUnreachableError = NSFileProviderError(.serverUnreachable) as NSError
		let taskRecord = UploadTaskRecord(correspondingItem: itemID, lastFailedUploadDate: Date(), uploadErrorCode: serverUnreachableError.code, uploadErrorDomain: serverUnreachableError.domain, uploadStartedAt: Date())
		uploadTaskManagerMock.getActiveUploadTaskRecordsReturnValue = []
		uploadTaskManagerMock.getRetryableUploadTaskRecordsReturnValue = [taskRecord]
		// No metadata exists for this item
		metadataManagerMock.cachedMetadata.removeAll()

		adapter.recoverStuckUploads()

		XCTAssertEqual(1, uploadTaskManagerMock.removeTaskRecordForCallsCount)
		XCTAssertEqual(itemID, uploadTaskManagerMock.removeTaskRecordForReceivedId)
	}

	func testRecoverStuckUploads_marksErrorForRetryableUploadWithMissingLocalFile() throws {
		let cloudPath = CloudPath("/OfflineFile.txt")
		let itemMetadata = ItemMetadata(id: itemID, name: "OfflineFile.txt", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .uploadError, cloudPath: cloudPath, isPlaceholderItem: true)
		try metadataManagerMock.cacheMetadata(itemMetadata)
		// No cached file info exists

		let serverUnreachableError = NSFileProviderError(.serverUnreachable) as NSError
		let taskRecord = UploadTaskRecord(correspondingItem: itemID, lastFailedUploadDate: Date(), uploadErrorCode: serverUnreachableError.code, uploadErrorDomain: serverUnreachableError.domain, uploadStartedAt: Date())
		uploadTaskManagerMock.getActiveUploadTaskRecordsReturnValue = []
		uploadTaskManagerMock.getRetryableUploadTaskRecordsReturnValue = [taskRecord]

		adapter.recoverStuckUploads()

		// Verify it was marked as noSuchItem error (not serverUnreachable, to prevent infinite retry)
		XCTAssertTrue(uploadTaskManagerMock.updateTaskRecordWithLastFailedUploadDateUploadErrorCodeUploadErrorDomainCalled)
		let updateArgs = uploadTaskManagerMock.updateTaskRecordWithLastFailedUploadDateUploadErrorCodeUploadErrorDomainReceivedArguments
		XCTAssertEqual(itemID, updateArgs?.id)
		XCTAssertEqual(NSFileProviderErrorDomain, updateArgs?.uploadErrorDomain)
		XCTAssertEqual(NSFileProviderError(.noSuchItem).errorCode, updateArgs?.uploadErrorCode)
	}
}
