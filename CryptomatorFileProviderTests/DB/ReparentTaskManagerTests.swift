//
//  ReparentTaskManagerTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 22.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import XCTest
@testable import CryptomatorFileProvider

class ReparentTaskManagerTests: XCTestCase {
	var manager: ReparentTaskManager!
	var tmpDirURL: URL!
	override func setUpWithError() throws {
		tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: tmpDirURL, withIntermediateDirectories: true)
		let dbURL = tmpDirURL.appendingPathComponent("db.sqlite", isDirectory: false)
		let dbQueue = try DataBaseHelper.getDBMigratedQueue(at: dbURL.path)
		manager = try ReparentTaskManager(with: dbQueue)
	}

	override func tearDownWithError() throws {
		manager = nil
		try FileManager.default.removeItem(at: tmpDirURL)
	}

	func testCreateAndGetTask() throws {
		let oldRemoteURL = URL(fileURLWithPath: "/Test.txt", isDirectory: false)
		let newRemoteURL = URL(fileURLWithPath: "/Foo.txt", isDirectory: false)
		try manager.createTask(for: 1, oldRemoteURL: oldRemoteURL, newRemoteURL: newRemoteURL, oldParentId: 2, newParentId: 3)
		let fetchedTask = try manager.getTask(for: 1)
		XCTAssertEqual(1, fetchedTask.correspondingItem)
		XCTAssertEqual(oldRemoteURL, fetchedTask.oldRemoteURL)
		XCTAssertEqual(newRemoteURL, fetchedTask.newRemoteURL)
		XCTAssertEqual(2, fetchedTask.oldParentId)
		XCTAssertEqual(3, fetchedTask.newParentId)
	}

	func testDeleteTask() throws {
		let oldRemoteURL = URL(fileURLWithPath: "/Test.txt", isDirectory: false)
		let newRemoteURL = URL(fileURLWithPath: "/Foo.txt", isDirectory: false)
		try manager.createTask(for: 1, oldRemoteURL: oldRemoteURL, newRemoteURL: newRemoteURL, oldParentId: 2, newParentId: 3)
		let task = try manager.getTask(for: 1)
		try manager.removeTask(task)
		XCTAssertThrowsError(try manager.getTask(for: 1)) { error in
			guard case TaskError.taskNotFound = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}
	}

	func testGetTasksWithOldParentIdWithDirectoryChange() throws {
		let oldRemoteURL = URL(fileURLWithPath: "/Test.txt", isDirectory: false)
		let newRemoteURL = URL(fileURLWithPath: "/Foo/Bar.txt", isDirectory: false)
		let oldParentId: Int64 = 2
		let newParentId: Int64 = 3
		try manager.createTask(for: 1, oldRemoteURL: oldRemoteURL, newRemoteURL: newRemoteURL, oldParentId: oldParentId, newParentId: newParentId)

		let retrievedTasks = try manager.getTasksForItemsWhichWere(in: oldParentId)
		XCTAssertEqual(1, retrievedTasks.count)
		XCTAssertEqual(1, retrievedTasks[0].correspondingItem)
		XCTAssertEqual(oldRemoteURL, retrievedTasks[0].oldRemoteURL)
		XCTAssertEqual(newRemoteURL, retrievedTasks[0].newRemoteURL)
		XCTAssertEqual(oldParentId, retrievedTasks[0].oldParentId)
		XCTAssertEqual(newParentId, retrievedTasks[0].newParentId)
	}

	func testGetTasksWithOldParentIdOnlyRename() throws {
		let oldRemoteURL = URL(fileURLWithPath: "/Test.txt", isDirectory: false)
		let oldParentId: Int64 = 2
		let newParentId = oldParentId
		let newRemoteURL = URL(fileURLWithPath: "/Test2 - Only Renamed.txt", isDirectory: false)
		try manager.createTask(for: 1, oldRemoteURL: oldRemoteURL, newRemoteURL: newRemoteURL, oldParentId: oldParentId, newParentId: oldParentId)
		let retrievedTasks = try manager.getTasksForItemsWhichWere(in: oldParentId)
		XCTAssertEqual(1, retrievedTasks.count)
		XCTAssertEqual(1, retrievedTasks[0].correspondingItem)
		XCTAssertEqual(oldRemoteURL, retrievedTasks[0].oldRemoteURL)
		XCTAssertEqual(newRemoteURL, retrievedTasks[0].newRemoteURL)
		XCTAssertEqual(oldParentId, retrievedTasks[0].oldParentId)
		XCTAssertEqual(newParentId, retrievedTasks[0].newParentId)
	}

	func testGetTasksWithNewParentIdWithDirectoryChange() throws {
		let oldRemoteURL = URL(fileURLWithPath: "/Test.txt", isDirectory: false)
		let newRemoteURL = URL(fileURLWithPath: "/Foo/Bar.txt", isDirectory: false)
		let oldParentId: Int64 = 2
		let newParentId: Int64 = 3
		try manager.createTask(for: 1, oldRemoteURL: oldRemoteURL, newRemoteURL: newRemoteURL, oldParentId: oldParentId, newParentId: newParentId)

		let retrievedTasks = try manager.getTasksForItemsWhichAreSoon(in: newParentId)
		XCTAssertEqual(1, retrievedTasks.count)
		XCTAssertEqual(1, retrievedTasks[0].correspondingItem)
		XCTAssertEqual(oldRemoteURL, retrievedTasks[0].oldRemoteURL)
		XCTAssertEqual(newRemoteURL, retrievedTasks[0].newRemoteURL)
		XCTAssertEqual(oldParentId, retrievedTasks[0].oldParentId)
		XCTAssertEqual(newParentId, retrievedTasks[0].newParentId)
	}

	func testGetTasksWithNewParentIdOnlyRename() throws {
		let oldRemoteURL = URL(fileURLWithPath: "/Test.txt", isDirectory: false)
		let oldParentId: Int64 = 2
		let newParentId = oldParentId
		let newRemoteURL = URL(fileURLWithPath: "/Test2 - Only Renamed.txt", isDirectory: false)
		try manager.createTask(for: 1, oldRemoteURL: oldRemoteURL, newRemoteURL: newRemoteURL, oldParentId: oldParentId, newParentId: oldParentId)
		let retrievedTasks = try manager.getTasksForItemsWhichAreSoon(in: newParentId)
		XCTAssertEqual(1, retrievedTasks.count)
		XCTAssertEqual(1, retrievedTasks[0].correspondingItem)
		XCTAssertEqual(oldRemoteURL, retrievedTasks[0].oldRemoteURL)
		XCTAssertEqual(newRemoteURL, retrievedTasks[0].newRemoteURL)
		XCTAssertEqual(oldParentId, retrievedTasks[0].oldParentId)
		XCTAssertEqual(newParentId, retrievedTasks[0].newParentId)
	}
}

extension ReparentTask: Equatable {
	public static func == (lhs: ReparentTask, rhs: ReparentTask) -> Bool {
		return lhs.correspondingItem == rhs.correspondingItem &&
			lhs.oldRemoteURL == rhs.oldRemoteURL &&
			lhs.newRemoteURL == rhs.newRemoteURL &&
			lhs.oldParentId == rhs.oldParentId &&
			lhs.newParentId == rhs.newParentId
	}
}
