//
//  MaintenanceManagerTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 18.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import GRDB
import XCTest
@testable import CryptomatorFileProvider

class MaintenanceManagerTests: XCTestCase {
	var manager: MaintenanceDBManager!
	var itemMetadataManager: ItemMetadataDBManager!
	var uploadTaskManager: UploadTaskDBManager!
	var reparentTaskManager: ReparentTaskDBManager!
	var deletionTaskManager: DeletionTaskDBManager!
	var itemEnumerationTaskManager: ItemEnumerationTaskDBManager!
	var downloadTaskManager: DownloadTaskDBManager!
	var inMemoryDB: DatabaseQueue!

	override func setUpWithError() throws {
		inMemoryDB = DatabaseQueue()
		try DatabaseHelper.migrate(inMemoryDB)
		manager = MaintenanceDBManager(database: inMemoryDB)
		itemMetadataManager = ItemMetadataDBManager(database: inMemoryDB)
		uploadTaskManager = UploadTaskDBManager(database: inMemoryDB)
		reparentTaskManager = try ReparentTaskDBManager(database: inMemoryDB)
		deletionTaskManager = try DeletionTaskDBManager(database: inMemoryDB)
		itemEnumerationTaskManager = try ItemEnumerationTaskDBManager(database: inMemoryDB)
		downloadTaskManager = try DownloadTaskDBManager(database: inMemoryDB)
	}

	func testPreventEnablingMaintenanceModeTwice() throws {
		try manager.enableMaintenanceMode()

		XCTAssertThrowsError(try manager.enableMaintenanceMode()) { error in
			XCTAssertEqual(.runningCloudTask, error as? MaintenanceModeError)
		}
	}

	// MARK: - Prevent the creation of New tasks when in maintenance mode

	func testPreventCreatingUploadTasks() throws {
		let itemMetadata = ItemMetadata(name: "Test", type: .file, size: nil, parentID: 1, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/Test"), isPlaceholderItem: false)
		try itemMetadataManager.cacheMetadata(itemMetadata)

		// Prevent INSERT
		try manager.enableMaintenanceMode()
		try checkThrowsMaintenanceError(uploadTaskManager.createNewTaskRecord(for: itemMetadata))
	}

	func testPreventCreatingReparentTasks() throws {
		let itemMetadata = ItemMetadata(name: "Test", type: .file, size: nil, parentID: 1, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/Test"), isPlaceholderItem: false)
		try itemMetadataManager.cacheMetadata(itemMetadata)

		// Prevent INSERT
		try manager.enableMaintenanceMode()
		try checkThrowsMaintenanceError(reparentTaskManager.createTaskRecord(for: itemMetadata, targetCloudPath: CloudPath("Foo"), newParentID: 1))
	}

	func testPreventCreatingDeletionTasks() throws {
		let itemMetadata = ItemMetadata(name: "Test", type: .file, size: nil, parentID: 1, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/Test"), isPlaceholderItem: false)
		try itemMetadataManager.cacheMetadata(itemMetadata)

		// Prevent INSERT
		try manager.enableMaintenanceMode()
		try checkThrowsMaintenanceError(deletionTaskManager.createTaskRecord(for: itemMetadata))
	}

	func testPreventCreatingItemEnumerationTasks() throws {
		let itemMetadata = ItemMetadata(name: "Test", type: .file, size: nil, parentID: 1, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/Test"), isPlaceholderItem: false)
		try itemMetadataManager.cacheMetadata(itemMetadata)

		// Prevent INSERT
		try manager.enableMaintenanceMode()
		try checkThrowsMaintenanceError(itemEnumerationTaskManager.createTask(for: itemMetadata, pageToken: nil))
	}

	func testPreventCreatingDownloadTasks() throws {
		let itemMetadata = ItemMetadata(name: "Test", type: .file, size: nil, parentID: 1, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/Test"), isPlaceholderItem: false)
		try itemMetadataManager.cacheMetadata(itemMetadata)

		// Prevent INSERT
		try manager.enableMaintenanceMode()
		try checkThrowsMaintenanceError(downloadTaskManager.createTask(for: itemMetadata, replaceExisting: true, localURL: URL(string: "/Test")!, onURLSessionTaskCreation: nil))
	}

	// MARK: - Prevent enabling maintenance mode for running tasks

	func testPreventEnablingMaintenanceModeForRunningUploadTask() throws {
		let itemMetadata = ItemMetadata(name: "Test", type: .file, size: nil, parentID: 1, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/Test"), isPlaceholderItem: false)
		try itemMetadataManager.cacheMetadata(itemMetadata)
		_ = try uploadTaskManager.createNewTaskRecord(for: itemMetadata)
		try assertOnlyFalseAllowedForInsertOrUpdate()
	}

	func testAllowMaintenanceModeForFailedUploadTask() throws {
		let itemMetadata = ItemMetadata(name: "Test", type: .file, size: nil, parentID: 1, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/Test"), isPlaceholderItem: false)
		try itemMetadataManager.cacheMetadata(itemMetadata)
		var task = try uploadTaskManager.createNewTaskRecord(for: itemMetadata)

		// Simualte failed upload task
		try uploadTaskManager.updateTaskRecord(&task, error: NSError(domain: "Test", code: -100, userInfo: nil))
		try manager.enableMaintenanceMode()
	}

	func testPreventEnablingMaintenanceModeForRunningReparentTask() throws {
		let itemMetadata = ItemMetadata(name: "Test", type: .file, size: nil, parentID: 1, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/Test"), isPlaceholderItem: false)
		try itemMetadataManager.cacheMetadata(itemMetadata)
		_ = try reparentTaskManager.createTaskRecord(for: itemMetadata, targetCloudPath: CloudPath("Foo"), newParentID: 1)
		try assertOnlyFalseAllowedForInsertOrUpdate()
	}

	func testPreventEnablingMaintenanceModeForRunningDeletionTask() throws {
		let itemMetadata = ItemMetadata(name: "Test", type: .file, size: nil, parentID: 1, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/Test"), isPlaceholderItem: false)
		try itemMetadataManager.cacheMetadata(itemMetadata)
		_ = try deletionTaskManager.createTaskRecord(for: itemMetadata)
		try assertOnlyFalseAllowedForInsertOrUpdate()
	}

	func testPreventEnablingMaintenanceModeForRunningItemEnumerationTask() throws {
		let itemMetadata = ItemMetadata(name: "Test", type: .file, size: nil, parentID: 1, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/Test"), isPlaceholderItem: false)
		try itemMetadataManager.cacheMetadata(itemMetadata)
		_ = try itemEnumerationTaskManager.createTask(for: itemMetadata, pageToken: nil)
		try assertOnlyFalseAllowedForInsertOrUpdate()
	}

	func testPreventEnablingMaintenanceModeForRunningDownloadTask() throws {
		let itemMetadata = ItemMetadata(name: "Test", type: .file, size: nil, parentID: 1, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/Test"), isPlaceholderItem: false)
		try itemMetadataManager.cacheMetadata(itemMetadata)
		_ = try downloadTaskManager.createTask(for: itemMetadata, replaceExisting: false, localURL: URL(string: "/Test")!, onURLSessionTaskCreation: nil)
		try assertOnlyFalseAllowedForInsertOrUpdate()
	}

	func checkThrowsMaintenanceError<T>(_ expression: @autoclosure () throws -> T) {
		XCTAssertThrowsError(try expression()) { error in
			guard let databaseError = error as? DatabaseError else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
			XCTAssertEqual("Maintenance Mode", databaseError.message)
		}
	}

	func checkThrowsRunningTaskError<T>(_ expression: @autoclosure () throws -> T) {
		XCTAssertThrowsError(try expression()) { error in
			guard case MaintenanceModeError.runningCloudTask = error else {
				XCTFail("Promise rejected with wrong error: \(error)")
				return
			}
		}
	}

	func assertOnlyFalseAllowedForInsertOrUpdate() throws {
		// Prevent INSERT true
		try checkThrowsRunningTaskError(manager.enableMaintenanceMode())

		// Allow INSERT false
		try manager.disableMaintenanceMode()

		// Allow UPDATE with false
		try manager.disableMaintenanceMode()

		// Prevent UPDATE with true
		try checkThrowsRunningTaskError(manager.enableMaintenanceMode())
	}
}
