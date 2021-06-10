//
//  ReparentTaskManagerTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 22.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import XCTest
@testable import CryptomatorFileProvider

class ReparentTaskManagerTests: XCTestCase {
	var manager: ReparentTaskDBManager!
	var itemMetadataManager: ItemMetadataDBManager!
	var tmpDirURL: URL!
	override func setUpWithError() throws {
		tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: tmpDirURL, withIntermediateDirectories: true)
		let dbURL = tmpDirURL.appendingPathComponent("db.sqlite", isDirectory: false)
		let dbPool = try DatabaseHelper.getMigratedDB(at: dbURL)
		manager = try ReparentTaskDBManager(with: dbPool)
		itemMetadataManager = ItemMetadataDBManager(with: dbPool)
	}

	override func tearDownWithError() throws {
		itemMetadataManager = nil
		manager = nil
		try FileManager.default.removeItem(at: tmpDirURL)
	}

	func testCreateAndGetTask() throws {
		let sourceCloudPath = CloudPath("/Test.txt")
		let targetCloudPath = CloudPath("/Foo.txt")
		let itemID: Int64 = 2
		let itemMetadata = ItemMetadata(id: itemID, name: "Test.txt", type: .file, size: nil, parentId: itemMetadataManager.getRootContainerID(), lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: sourceCloudPath, isPlaceholderItem: false, isCandidateForCacheCleanup: false)
		try itemMetadataManager.cacheMetadata(itemMetadata)
		let newParentID: Int64 = 3
		let createdTask = try manager.createTaskRecord(for: itemMetadata, targetCloudPath: targetCloudPath, newParentID: newParentID)
		let fetchedTask = try manager.getTaskRecord(for: itemID)
		XCTAssertEqual(createdTask, fetchedTask)
		XCTAssertEqual(itemID, fetchedTask.correspondingItem)
		XCTAssertEqual(sourceCloudPath, fetchedTask.sourceCloudPath)
		XCTAssertEqual(targetCloudPath, fetchedTask.targetCloudPath)
		XCTAssertEqual(itemMetadataManager.getRootContainerID(), fetchedTask.oldParentID)
		XCTAssertEqual(newParentID, fetchedTask.newParentID)
	}

	func testDeleteTask() throws {
		let sourceCloudPath = CloudPath("/Test.txt")
		let targetCloudPath = CloudPath("/Foo.txt")
		let itemID: Int64 = 2
		let itemMetadata = ItemMetadata(id: itemID, name: "Test.txt", type: .file, size: nil, parentId: itemMetadataManager.getRootContainerID(), lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: sourceCloudPath, isPlaceholderItem: false, isCandidateForCacheCleanup: false)
		try itemMetadataManager.cacheMetadata(itemMetadata)
		_ = try manager.createTaskRecord(for: itemMetadata, targetCloudPath: targetCloudPath, newParentID: 3)
		let task = try manager.getTaskRecord(for: itemID)
		try manager.removeTaskRecord(task)
		XCTAssertThrowsError(try manager.getTaskRecord(for: itemID)) { error in
			guard case DBManagerError.taskNotFound = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}
	}

	func testGetTasksWithOldParentIDWithDirectoryChange() throws {
		let sourceCloudPath = CloudPath("/Test.txt")
		let targetCloudPath = CloudPath("/Foo/Bar.txt")

		let itemID: Int64 = 2
		let itemMetadata = ItemMetadata(id: itemID, name: "Test.txt", type: .file, size: nil, parentId: itemMetadataManager.getRootContainerID(), lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: sourceCloudPath, isPlaceholderItem: false, isCandidateForCacheCleanup: false)
		try itemMetadataManager.cacheMetadata(itemMetadata)

		let folderItemID: Int64 = 3
		let folderItemMetadata = ItemMetadata(id: folderItemID, name: "Foo", type: .folder, size: nil, parentId: itemMetadataManager.getRootContainerID(), lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/Foo"), isPlaceholderItem: false, isCandidateForCacheCleanup: false)
		try itemMetadataManager.cacheMetadata(folderItemMetadata)

		_ = try manager.createTaskRecord(for: itemMetadata, targetCloudPath: targetCloudPath, newParentID: folderItemID)

		let retrievedTasks = try manager.getTaskRecordsForItemsWhichWere(in: itemMetadataManager.getRootContainerID())
		XCTAssertEqual(1, retrievedTasks.count)
		XCTAssertEqual(itemID, retrievedTasks[0].correspondingItem)
		XCTAssertEqual(sourceCloudPath, retrievedTasks[0].sourceCloudPath)
		XCTAssertEqual(targetCloudPath, retrievedTasks[0].targetCloudPath)
		XCTAssertEqual(itemMetadataManager.getRootContainerID(), retrievedTasks[0].oldParentID)
		XCTAssertEqual(folderItemID, retrievedTasks[0].newParentID)
	}

	func testGetTasksWithOldParentIDOnlyRename() throws {
		let sourceCloudPath = CloudPath("/Test.txt")
		let targetCloudPath = CloudPath("/Test2 - Only Renamed.txt")

		let itemID: Int64 = 2
		let itemMetadata = ItemMetadata(id: itemID, name: "Test.txt", type: .file, size: nil, parentId: itemMetadataManager.getRootContainerID(), lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: sourceCloudPath, isPlaceholderItem: false, isCandidateForCacheCleanup: false)
		try itemMetadataManager.cacheMetadata(itemMetadata)

		_ = try manager.createTaskRecord(for: itemMetadata, targetCloudPath: targetCloudPath, newParentID: itemMetadataManager.getRootContainerID())
		let retrievedTasks = try manager.getTaskRecordsForItemsWhichWere(in: itemMetadataManager.getRootContainerID())
		XCTAssertEqual(1, retrievedTasks.count)
		XCTAssertEqual(itemID, retrievedTasks[0].correspondingItem)
		XCTAssertEqual(sourceCloudPath, retrievedTasks[0].sourceCloudPath)
		XCTAssertEqual(targetCloudPath, retrievedTasks[0].targetCloudPath)
		XCTAssertEqual(itemMetadataManager.getRootContainerID(), retrievedTasks[0].oldParentID)
		XCTAssertEqual(itemMetadataManager.getRootContainerID(), retrievedTasks[0].newParentID)
	}

	func testGetTasksWithNewParentIdWithDirectoryChange() throws {
		let sourceCloudPath = CloudPath("/Test.txt")
		let targetCloudPath = CloudPath("/Foo/Test.txt")
		let newParentID: Int64 = 3

		let itemID: Int64 = 2
		let itemMetadata = ItemMetadata(id: itemID, name: "Test.txt", type: .file, size: nil, parentId: itemMetadataManager.getRootContainerID(), lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: sourceCloudPath, isPlaceholderItem: false, isCandidateForCacheCleanup: false)
		try itemMetadataManager.cacheMetadata(itemMetadata)

		_ = try manager.createTaskRecord(for: itemMetadata, targetCloudPath: targetCloudPath, newParentID: newParentID)

		let retrievedTasks = try manager.getTaskRecordsForItemsWhichAreSoon(in: newParentID)
		XCTAssertEqual(1, retrievedTasks.count)
		XCTAssertEqual(itemID, retrievedTasks[0].correspondingItem)
		XCTAssertEqual(sourceCloudPath, retrievedTasks[0].sourceCloudPath)
		XCTAssertEqual(targetCloudPath, retrievedTasks[0].targetCloudPath)
		XCTAssertEqual(itemMetadataManager.getRootContainerID(), retrievedTasks[0].oldParentID)
		XCTAssertEqual(newParentID, retrievedTasks[0].newParentID)
	}

	func testGetTasksWithNewParentIdOnlyRename() throws {
		let sourceCloudPath = CloudPath("/Test.txt")
		let targetCloudPath = CloudPath("/Test2 - Only Renamed.txt")

		let itemID: Int64 = 2
		let itemMetadata = ItemMetadata(id: itemID, name: "Test.txt", type: .file, size: nil, parentId: itemMetadataManager.getRootContainerID(), lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: sourceCloudPath, isPlaceholderItem: false, isCandidateForCacheCleanup: false)
		try itemMetadataManager.cacheMetadata(itemMetadata)

		_ = try manager.createTaskRecord(for: itemMetadata, targetCloudPath: targetCloudPath, newParentID: itemMetadataManager.getRootContainerID())

		let retrievedTasks = try manager.getTaskRecordsForItemsWhichAreSoon(in: itemMetadataManager.getRootContainerID())
		XCTAssertEqual(1, retrievedTasks.count)
		XCTAssertEqual(itemID, retrievedTasks[0].correspondingItem)
		XCTAssertEqual(sourceCloudPath, retrievedTasks[0].sourceCloudPath)
		XCTAssertEqual(targetCloudPath, retrievedTasks[0].targetCloudPath)
		XCTAssertEqual(itemMetadataManager.getRootContainerID(), retrievedTasks[0].oldParentID)
		XCTAssertEqual(itemMetadataManager.getRootContainerID(), retrievedTasks[0].newParentID)
	}
}

extension ReparentTaskDBManager {
	func getTaskRecord(for id: Int64) throws -> ReparentTaskRecord {
		try dbPool.read { db in
			guard let task = try ReparentTaskRecord.fetchOne(db, key: id) else {
				throw DBManagerError.taskNotFound
			}
			return task
		}
	}
}

extension ReparentTaskRecord: Equatable {
	public static func == (lhs: ReparentTaskRecord, rhs: ReparentTaskRecord) -> Bool {
		return lhs.correspondingItem == rhs.correspondingItem &&
			lhs.sourceCloudPath == rhs.sourceCloudPath &&
			lhs.targetCloudPath == rhs.targetCloudPath &&
			lhs.oldParentID == rhs.oldParentID &&
			lhs.newParentID == rhs.newParentID
	}
}
