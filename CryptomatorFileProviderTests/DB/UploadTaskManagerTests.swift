//
//  UploadTaskManagerTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 07.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import FileProvider
import GRDB
import XCTest
@testable import CryptomatorFileProvider

class UploadTaskManagerTests: XCTestCase {
	var manager: UploadTaskDBManager!
	var itemMetadataManager: ItemMetadataDBManager!
	var inMemoryDB: DatabaseQueue!

	override func setUpWithError() throws {
		inMemoryDB = try DatabaseQueue()
		try DatabaseHelper.migrate(inMemoryDB)
		manager = UploadTaskDBManager(database: inMemoryDB)
		itemMetadataManager = ItemMetadataDBManager(database: inMemoryDB)
	}

	func testCachedAndFetchEntry() throws {
		let itemMetadata = ItemMetadata(name: "Test", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/Test"), isPlaceholderItem: true)
		try itemMetadataManager.cacheMetadata(itemMetadata)
		_ = try manager.createNewTaskRecord(for: itemMetadata)
		guard let fetchedUploadTask = try manager.getTaskRecord(for: XCTUnwrap(itemMetadata.id)) else {
			XCTFail("UploadTask not found")
			return
		}
		XCTAssertEqual(itemMetadata.id, fetchedUploadTask.correspondingItem)
		XCTAssertNil(fetchedUploadTask.lastFailedUploadDate)
		XCTAssertNil(fetchedUploadTask.uploadErrorCode)
		XCTAssertNil(fetchedUploadTask.uploadErrorDomain)
	}

	func testUpdateTaskRecord() throws {
		let itemMetadata = ItemMetadata(name: "Test", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/Test"), isPlaceholderItem: true)
		try itemMetadataManager.cacheMetadata(itemMetadata)
		_ = try manager.createNewTaskRecord(for: itemMetadata)
		let lastFailedUploadDate = Date(timeIntervalSinceReferenceDate: 0)
		let error = NSFileProviderError(.serverUnreachable)
		try manager.updateTaskRecord(with: XCTUnwrap(itemMetadata.id), lastFailedUploadDate: lastFailedUploadDate, uploadErrorCode: error.errorCode, uploadErrorDomain: NSFileProviderError.errorDomain)
		guard let fetchedUploadTask = try manager.getTaskRecord(for: XCTUnwrap(itemMetadata.id)) else {
			XCTFail("UploadTask not found")
			return
		}
		XCTAssertEqual(itemMetadata.id, fetchedUploadTask.correspondingItem)
		XCTAssertEqual(lastFailedUploadDate, fetchedUploadTask.lastFailedUploadDate)
		XCTAssertEqual(error.errorCode, fetchedUploadTask.uploadErrorCode)
		XCTAssertEqual(NSFileProviderError.errorDomain, fetchedUploadTask.uploadErrorDomain)
	}

	func testUpdateNonExistentTaskRecordFailsWithTaskNotFound() throws {
		XCTAssertThrowsError(try manager.updateTaskRecord(with: 2, lastFailedUploadDate: Date(), uploadErrorCode: 0, uploadErrorDomain: "")) { error in
			guard case DBManagerError.taskNotFound = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}
	}

	func testDeleteCascadeWorks() throws {
		let itemMetadata = ItemMetadata(name: "Test", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/Test"), isPlaceholderItem: true)
		try itemMetadataManager.cacheMetadata(itemMetadata)
		_ = try manager.createNewTaskRecord(for: itemMetadata)
		let taskBeforeRemoval = try manager.getTaskRecord(for: XCTUnwrap(itemMetadata.id))
		XCTAssertNotNil(taskBeforeRemoval)
		let itemManager = ItemMetadataDBManager(database: inMemoryDB)
		try itemManager.removeItemMetadata(with: XCTUnwrap(itemMetadata.id))
		let taskAfterRemoval = try manager.getTaskRecord(for: XCTUnwrap(itemMetadata.id))
		XCTAssertNil(taskAfterRemoval)
	}

	func testGetCorrespondingTaskRecords() throws {
		let itemMetadata = ItemMetadata(name: "Test", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/Test"), isPlaceholderItem: true)
		try itemMetadataManager.cacheMetadata(itemMetadata)
		let savedTask = try manager.createNewTaskRecord(for: itemMetadata)
		let ids = try [XCTUnwrap(itemMetadata.id) + 1, XCTUnwrap(itemMetadata.id), XCTUnwrap(itemMetadata.id) - 1]
		let tasks = try manager.getCorrespondingTaskRecords(ids: ids)
		XCTAssertEqual(3, tasks.count)
		XCTAssertNil(tasks[0])
		XCTAssertNil(tasks[2])
		XCTAssertEqual(savedTask.correspondingItem, tasks[1]?.correspondingItem)
	}

	func testGetTask() throws {
		let cloudPath = CloudPath("/Test")
		let itemMetadataManager = ItemMetadataDBManager(database: inMemoryDB)
		let itemMetadata = ItemMetadata(name: "Test", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
		try itemMetadataManager.cacheMetadata(itemMetadata)
		let taskRecord = try manager.createNewTaskRecord(for: itemMetadata)
		let fetchedTask = try manager.getTask(for: taskRecord, onURLSessionTaskCreation: nil)
		XCTAssertEqual(itemMetadata, fetchedTask.itemMetadata)
		XCTAssertEqual(itemMetadata.id, fetchedTask.taskRecord.correspondingItem)
	}

	// MARK: - getRetryableUploadTaskRecords

	func testGetRetryableUploadTaskRecordsReturnsServerUnreachable() throws {
		try createTaskRecordWithError(domain: NSFileProviderErrorDomain, code: NSFileProviderError(.serverUnreachable).errorCode)
		let retryable = try manager.getRetryableUploadTaskRecords()
		XCTAssertEqual(1, retryable.count)
	}

	func testGetRetryableUploadTaskRecordsExcludesOtherErrorCodes() throws {
		try createTaskRecordWithError(domain: NSFileProviderErrorDomain, code: NSFileProviderError(.noSuchItem).errorCode)
		try createTaskRecordWithError(domain: "com.example.test", code: NSFileProviderError(.serverUnreachable).errorCode)
		let retryable = try manager.getRetryableUploadTaskRecords()
		XCTAssertEqual(0, retryable.count)
	}

	func testGetRetryableUploadTaskRecordsExcludesNilErrorTasks() throws {
		let itemMetadata = ItemMetadata(name: "ActiveUpload", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, cloudPath: CloudPath("/ActiveUpload"), isPlaceholderItem: false)
		try itemMetadataManager.cacheMetadata(itemMetadata)
		_ = try manager.createNewTaskRecord(for: itemMetadata)
		let retryable = try manager.getRetryableUploadTaskRecords()
		XCTAssertEqual(0, retryable.count)
	}

	// MARK: - Helpers

	@discardableResult
	private func createTaskRecordWithError(domain: String, code: Int, name: String? = nil) throws -> UploadTaskRecord {
		let fileName = name ?? "File-\(domain)-\(code)"
		let itemMetadata = ItemMetadata(name: fileName, type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .uploadError, cloudPath: CloudPath("/\(fileName)"), isPlaceholderItem: false)
		try itemMetadataManager.cacheMetadata(itemMetadata)
		_ = try manager.createNewTaskRecord(for: itemMetadata)
		let id = try XCTUnwrap(itemMetadata.id)
		try manager.updateTaskRecord(with: id, lastFailedUploadDate: Date(), uploadErrorCode: code, uploadErrorDomain: domain)
		return try XCTUnwrap(manager.getTaskRecord(for: id))
	}
}
