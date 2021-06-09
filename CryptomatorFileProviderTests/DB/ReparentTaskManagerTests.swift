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
	var tmpDirURL: URL!
	override func setUpWithError() throws {
		tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: tmpDirURL, withIntermediateDirectories: true)
		let dbURL = tmpDirURL.appendingPathComponent("db.sqlite", isDirectory: false)
		let dbPool = try DatabaseHelper.getMigratedDB(at: dbURL)
		manager = try ReparentTaskDBManager(with: dbPool)
	}

	override func tearDownWithError() throws {
		manager = nil
		try FileManager.default.removeItem(at: tmpDirURL)
	}

	#warning("TODO: Fix Test")
	/*
	 func testCreateAndGetTask() throws {
	 	let sourceCloudPath = CloudPath("/Test.txt")
	 	let targetCloudPath = CloudPath("/Foo.txt")
	 	try manager.createTaskRecord(for: 1, oldCloudPath: sourceCloudPath, newCloudPath: targetCloudPath, oldParentId: 2, newParentId: 3)
	 	let fetchedTask = try manager.getTaskRecord(for: 1)
	 	XCTAssertEqual(1, fetchedTask.correspondingItem)
	 	XCTAssertEqual(sourceCloudPath, fetchedTask.sourceCloudPath)
	 	XCTAssertEqual(targetCloudPath, fetchedTask.targetCloudPath)
	 	XCTAssertEqual(2, fetchedTask.oldParentId)
	 	XCTAssertEqual(3, fetchedTask.newParentId)
	 }

	 func testDeleteTask() throws {
	 	let sourceCloudPath = CloudPath("/Test.txt")
	 	let targetCloudPath = CloudPath("/Foo.txt")
	 	try manager.createTaskRecord(for: 1, oldCloudPath: sourceCloudPath, newCloudPath: targetCloudPath, oldParentId: 2, newParentId: 3)
	 	let task = try manager.getTaskRecord(for: 1)
	 	try manager.removeTaskRecord(task)
	 	XCTAssertThrowsError(try manager.getTaskRecord(for: 1)) { error in
	 		guard case TaskError.taskNotFound = error else {
	 			XCTFail("Throws the wrong error: \(error)")
	 			return
	 		}
	 	}
	 }

	 func testGetTasksWithOldParentIdWithDirectoryChange() throws {
	 	let sourceCloudPath = CloudPath("/Test.txt")
	 	let targetCloudPath = CloudPath("/Foo/Bar.txt")
	 	let oldParentId: Int64 = 2
	 	let newParentId: Int64 = 3
	 	try manager.createTaskRecord(for: 1, oldCloudPath: sourceCloudPath, newCloudPath: targetCloudPath, oldParentId: oldParentId, newParentId: newParentId)

	 	let retrievedTasks = try manager.getTaskRecordsForItemsWhichWere(in: oldParentId)
	 	XCTAssertEqual(1, retrievedTasks.count)
	 	XCTAssertEqual(1, retrievedTasks[0].correspondingItem)
	 	XCTAssertEqual(sourceCloudPath, retrievedTasks[0].sourceCloudPath)
	 	XCTAssertEqual(targetCloudPath, retrievedTasks[0].targetCloudPath)
	 	XCTAssertEqual(oldParentId, retrievedTasks[0].oldParentId)
	 	XCTAssertEqual(newParentId, retrievedTasks[0].newParentId)
	 }

	 func testGetTasksWithOldParentIdOnlyRename() throws {
	 	let sourceCloudPath = CloudPath("/Test.txt")
	 	let oldParentId: Int64 = 2
	 	let newParentId = oldParentId
	 	let targetCloudPath = CloudPath("/Test2 - Only Renamed.txt")
	 	try manager.createTaskRecord(for: 1, oldCloudPath: sourceCloudPath, newCloudPath: targetCloudPath, oldParentId: oldParentId, newParentId: oldParentId)
	 	let retrievedTasks = try manager.getTaskRecordsForItemsWhichWere(in: oldParentId)
	 	XCTAssertEqual(1, retrievedTasks.count)
	 	XCTAssertEqual(1, retrievedTasks[0].correspondingItem)
	 	XCTAssertEqual(sourceCloudPath, retrievedTasks[0].sourceCloudPath)
	 	XCTAssertEqual(targetCloudPath, retrievedTasks[0].targetCloudPath)
	 	XCTAssertEqual(oldParentId, retrievedTasks[0].oldParentId)
	 	XCTAssertEqual(newParentId, retrievedTasks[0].newParentId)
	 }

	 func testGetTasksWithNewParentIdWithDirectoryChange() throws {
	 	let sourceCloudPath = CloudPath("/Test.txt")
	 	let targetCloudPath = CloudPath("/Foo/Bar.txt")
	 	let oldParentId: Int64 = 2
	 	let newParentId: Int64 = 3
	 	try manager.createTaskRecord(for: 1, oldCloudPath: sourceCloudPath, newCloudPath: targetCloudPath, oldParentId: oldParentId, newParentId: newParentId)

	 	let retrievedTasks = try manager.getTaskRecordsForItemsWhichAreSoon(in: newParentId)
	 	XCTAssertEqual(1, retrievedTasks.count)
	 	XCTAssertEqual(1, retrievedTasks[0].correspondingItem)
	 	XCTAssertEqual(sourceCloudPath, retrievedTasks[0].sourceCloudPath)
	 	XCTAssertEqual(targetCloudPath, retrievedTasks[0].targetCloudPath)
	 	XCTAssertEqual(oldParentId, retrievedTasks[0].oldParentId)
	 	XCTAssertEqual(newParentId, retrievedTasks[0].newParentId)
	 }

	 func testGetTasksWithNewParentIdOnlyRename() throws {
	 	let sourceCloudPath = CloudPath("/Test.txt")
	 	let oldParentId: Int64 = 2
	 	let newParentId = oldParentId
	 	let targetCloudPath = CloudPath("/Test2 - Only Renamed.txt")
	 	try manager.createTaskRecord(for: 1, oldCloudPath: sourceCloudPath, newCloudPath: targetCloudPath, oldParentId: oldParentId, newParentId: oldParentId)
	 	let retrievedTasks = try manager.getTaskRecordsForItemsWhichAreSoon(in: newParentId)
	 	XCTAssertEqual(1, retrievedTasks.count)
	 	XCTAssertEqual(1, retrievedTasks[0].correspondingItem)
	 	XCTAssertEqual(sourceCloudPath, retrievedTasks[0].sourceCloudPath)
	 	XCTAssertEqual(targetCloudPath, retrievedTasks[0].targetCloudPath)
	 	XCTAssertEqual(oldParentId, retrievedTasks[0].oldParentId)
	 	XCTAssertEqual(newParentId, retrievedTasks[0].newParentId)
	 }
	 */
}

extension ReparentTaskRecord: Equatable {
	public static func == (lhs: ReparentTaskRecord, rhs: ReparentTaskRecord) -> Bool {
		return lhs.correspondingItem == rhs.correspondingItem &&
			lhs.sourceCloudPath == rhs.sourceCloudPath &&
			lhs.targetCloudPath == rhs.targetCloudPath &&
			lhs.oldParentId == rhs.oldParentId &&
			lhs.newParentId == rhs.newParentId
	}
}
