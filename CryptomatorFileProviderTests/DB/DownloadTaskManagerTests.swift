//
//  DownloadTaskManagerTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 19.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import GRDB
import XCTest
@testable import CryptomatorFileProvider

class DownloadTaskManagerTests: XCTestCase {
	var manager: DownloadTaskDBManager!
	var itemMetadataManager: ItemMetadataDBManager!
	var inMemoryDB: DatabaseQueue!

	override func setUpWithError() throws {
		inMemoryDB = DatabaseQueue()
		try DatabaseHelper.migrate(inMemoryDB)
		manager = try DownloadTaskDBManager(database: inMemoryDB)
		itemMetadataManager = ItemMetadataDBManager(database: inMemoryDB)
	}

	func testCreateAndGetTaskRecord() throws {
		let createdTask = try createTestTask()
		let fetchedTask = try getTaskRecord(for: createdTask.itemMetadata.id!)
		XCTAssertEqual(fetchedTask, createdTask.taskRecord)
		XCTAssertEqual(createdTask.itemMetadata.id, fetchedTask.correspondingItem)
		XCTAssertEqual(createdTask.taskRecord.localURL, fetchedTask.localURL)
		XCTAssert(fetchedTask.replaceExisting)
	}

	func testRemoveTaskRecord() throws {
		let createdTask = try createTestTask()
		try manager.removeTaskRecord(createdTask.taskRecord)
		XCTAssertThrowsError(try getTaskRecord(for: createdTask.itemMetadata.id!)) { error in
			guard case DBManagerError.taskNotFound = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}
	}

	private func createTestTask() throws -> DownloadTask {
		let cloudPath = CloudPath("/Test")
		let itemMetadata = ItemMetadata(name: "Test", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
		try itemMetadataManager.cacheMetadata(itemMetadata)
		let localURL = URL(string: "/Test")!
		return try manager.createTask(for: itemMetadata, replaceExisting: true, localURL: localURL, onURLSessionTaskCreation: nil)
	}

	private func getTaskRecord(for id: Int64) throws -> DownloadTaskRecord {
		try inMemoryDB.read({ db in
			guard let task = try DownloadTaskRecord.fetchOne(db, key: id) else {
				throw DBManagerError.taskNotFound
			}
			return task
		})
	}
}
