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
}
