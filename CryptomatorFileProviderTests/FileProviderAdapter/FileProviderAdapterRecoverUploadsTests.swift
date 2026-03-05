//
//  FileProviderAdapterRecoverUploadsTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Tobias Hagemann.
//  Copyright © 2026 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation
import Promises
import XCTest
@testable import CryptomatorCommonCore
@testable import CryptomatorFileProvider
@testable import Dependencies

class FileProviderAdapterRecoverUploadsTests: FileProviderAdapterTestCase {
	let itemID: Int64 = 2

	func testRecoverStuckUploads_noActiveUploads() {
		uploadTaskManagerMock.getActiveUploadTaskRecordsReturnValue = []

		adapter.recoverStuckUploads()

		XCTAssertEqual(1, uploadTaskManagerMock.getActiveUploadTaskRecordsCallsCount)
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
}
