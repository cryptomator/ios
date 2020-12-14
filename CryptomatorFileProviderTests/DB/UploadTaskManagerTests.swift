//
//  UploadTaskManagerTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 07.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import FileProvider
import GRDB
import XCTest
@testable import CryptomatorFileProvider
class UploadTaskManagerTests: XCTestCase {
	var manager: UploadTaskManager!
	var tmpDirURL: URL!
	var dbPool: DatabasePool!
	override func setUpWithError() throws {
		tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: tmpDirURL, withIntermediateDirectories: true)
		let dbURL = tmpDirURL.appendingPathComponent("db.sqlite", isDirectory: false)
		dbPool = try DatabaseHelper.getMigratedDB(at: dbURL)
		manager = UploadTaskManager(with: dbPool)
	}

	override func tearDownWithError() throws {
		manager = nil
		dbPool = nil
		try FileManager.default.removeItem(at: tmpDirURL)
	}

	func testCachedAndFetchEntry() throws {
		_ = try manager.createNewTask(for: MetadataManager.rootContainerId)
		guard let fetchedUploadTask = try manager.getTask(for: MetadataManager.rootContainerId) else {
			XCTFail("UploadTask not found")
			return
		}
		XCTAssertEqual(MetadataManager.rootContainerId, fetchedUploadTask.correspondingItem)
		XCTAssertNil(fetchedUploadTask.lastFailedUploadDate)
		XCTAssertNil(fetchedUploadTask.uploadErrorCode)
		XCTAssertNil(fetchedUploadTask.uploadErrorDomain)
	}

	func testUpdateTask() throws {
		_ = try manager.createNewTask(for: MetadataManager.rootContainerId)
		let lastFailedUploadDate = Date(timeIntervalSinceReferenceDate: 0)
		let error = NSFileProviderError(.serverUnreachable)
		try manager.updateTask(with: MetadataManager.rootContainerId, lastFailedUploadDate: lastFailedUploadDate, uploadErrorCode: error.errorCode, uploadErrorDomain: NSFileProviderError.errorDomain)
		guard let fetchedUploadTask = try manager.getTask(for: MetadataManager.rootContainerId) else {
			XCTFail("UploadTask not found")
			return
		}
		XCTAssertEqual(MetadataManager.rootContainerId, fetchedUploadTask.correspondingItem)
		XCTAssertEqual(lastFailedUploadDate, fetchedUploadTask.lastFailedUploadDate)
		XCTAssertEqual(error.errorCode, fetchedUploadTask.uploadErrorCode)
		XCTAssertEqual(NSFileProviderError.errorDomain, fetchedUploadTask.uploadErrorDomain)
	}

	func testUpdateNonExistentTaskFailsWithTaskNotFound() throws {
		XCTAssertThrowsError(try manager.updateTask(with: 2, lastFailedUploadDate: Date(), uploadErrorCode: 0, uploadErrorDomain: "")) { error in
			guard case TaskError.taskNotFound = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}
	}

	func testDeleteCascadeWorks() throws {
		_ = try manager.createNewTask(for: MetadataManager.rootContainerId)
		let taskBeforeRemoval = try manager.getTask(for: MetadataManager.rootContainerId)
		XCTAssertNotNil(taskBeforeRemoval)
		let itemManager = MetadataManager(with: dbPool)
		try itemManager.removeItemMetadata(with: MetadataManager.rootContainerId)
		let taskAfterRemoval = try manager.getTask(for: MetadataManager.rootContainerId)
		XCTAssertNil(taskAfterRemoval)
	}

	func testGetCorrespondingTasks() throws {
		let savedTask = try manager.createNewTask(for: MetadataManager.rootContainerId)
		let ids = [MetadataManager.rootContainerId + 1, MetadataManager.rootContainerId, MetadataManager.rootContainerId + 3]
		let tasks = try manager.getCorrespondingTasks(ids: ids)
		XCTAssertEqual(3, tasks.count)
		XCTAssertNil(tasks[0])
		XCTAssertNil(tasks[2])
		XCTAssertEqual(savedTask.correspondingItem, tasks[1]?.correspondingItem)
	}
}
