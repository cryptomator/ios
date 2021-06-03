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
	var tmpDirURL: URL!
	var dbPool: DatabasePool!
	override func setUpWithError() throws {
		tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: tmpDirURL, withIntermediateDirectories: true)
		let dbURL = tmpDirURL.appendingPathComponent("db.sqlite", isDirectory: false)
		dbPool = try DatabaseHelper.getMigratedDB(at: dbURL)
		manager = UploadTaskDBManager(with: dbPool)
	}

	override func tearDownWithError() throws {
		manager = nil
		dbPool = nil
		try FileManager.default.removeItem(at: tmpDirURL)
	}

	func testCachedAndFetchEntry() throws {
		_ = try manager.createNewTaskRecord(for: MetadataDBManager.rootContainerId)
		guard let fetchedUploadTask = try manager.getTaskRecord(for: MetadataDBManager.rootContainerId) else {
			XCTFail("UploadTask not found")
			return
		}
		XCTAssertEqual(MetadataDBManager.rootContainerId, fetchedUploadTask.correspondingItem)
		XCTAssertNil(fetchedUploadTask.lastFailedUploadDate)
		XCTAssertNil(fetchedUploadTask.uploadErrorCode)
		XCTAssertNil(fetchedUploadTask.uploadErrorDomain)
	}

	func testUpdateTaskRecord() throws {
		_ = try manager.createNewTaskRecord(for: MetadataDBManager.rootContainerId)
		let lastFailedUploadDate = Date(timeIntervalSinceReferenceDate: 0)
		let error = NSFileProviderError(.serverUnreachable)
		try manager.updateTaskRecord(with: MetadataDBManager.rootContainerId, lastFailedUploadDate: lastFailedUploadDate, uploadErrorCode: error.errorCode, uploadErrorDomain: NSFileProviderError.errorDomain)
		guard let fetchedUploadTask = try manager.getTaskRecord(for: MetadataDBManager.rootContainerId) else {
			XCTFail("UploadTask not found")
			return
		}
		XCTAssertEqual(MetadataDBManager.rootContainerId, fetchedUploadTask.correspondingItem)
		XCTAssertEqual(lastFailedUploadDate, fetchedUploadTask.lastFailedUploadDate)
		XCTAssertEqual(error.errorCode, fetchedUploadTask.uploadErrorCode)
		XCTAssertEqual(NSFileProviderError.errorDomain, fetchedUploadTask.uploadErrorDomain)
	}

	func testUpdateNonExistentTaskRecordFailsWithTaskNotFound() throws {
		XCTAssertThrowsError(try manager.updateTaskRecord(with: 2, lastFailedUploadDate: Date(), uploadErrorCode: 0, uploadErrorDomain: "")) { error in
			guard case TaskError.taskNotFound = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}
	}

	func testDeleteCascadeWorks() throws {
		_ = try manager.createNewTaskRecord(for: MetadataDBManager.rootContainerId)
		let taskBeforeRemoval = try manager.getTaskRecord(for: MetadataDBManager.rootContainerId)
		XCTAssertNotNil(taskBeforeRemoval)
		let itemManager = MetadataDBManager(with: dbPool)
		try itemManager.removeItemMetadata(with: MetadataDBManager.rootContainerId)
		let taskAfterRemoval = try manager.getTaskRecord(for: MetadataDBManager.rootContainerId)
		XCTAssertNil(taskAfterRemoval)
	}

	func testGetCorrespondingTaskRecords() throws {
		let savedTask = try manager.createNewTaskRecord(for: MetadataDBManager.rootContainerId)
		let ids = [MetadataDBManager.rootContainerId + 1, MetadataDBManager.rootContainerId, MetadataDBManager.rootContainerId + 3]
		let tasks = try manager.getCorrespondingTaskRecords(ids: ids)
		XCTAssertEqual(3, tasks.count)
		XCTAssertNil(tasks[0])
		XCTAssertNil(tasks[2])
		XCTAssertEqual(savedTask.correspondingItem, tasks[1]?.correspondingItem)
	}

	func testGetTask() throws {
		let cloudPath = CloudPath("/Test")
		let metadataManager = MetadataDBManager(with: dbPool)
		let itemMetadata = ItemMetadata(name: "Test", type: .file, size: nil, parentId: MetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
		try metadataManager.cacheMetadata(itemMetadata)
		let taskRecord = try manager.createNewTaskRecord(for: itemMetadata.id!)
		let fetchedTask = try manager.getTask(for: taskRecord)
		XCTAssertEqual(itemMetadata, fetchedTask.itemMetadata)
		XCTAssertEqual(itemMetadata.id, fetchedTask.taskRecord.correspondingItem)
	}
}
