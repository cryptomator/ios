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
		inMemoryDB = try DatabaseQueue()
		try DatabaseHelper.migrate(inMemoryDB)
		manager = try DownloadTaskDBManager(database: inMemoryDB, itemMetadataManager: ItemMetadataDBManager(database: inMemoryDB))
		itemMetadataManager = ItemMetadataDBManager(database: inMemoryDB)
	}

	func testCreateAndGetTaskRecord() throws {
		let createdTask = try createTestTask()
		let fetchedTask = try getTaskRecord(for: XCTUnwrap(createdTask.itemMetadata.id))
		XCTAssertEqual(fetchedTask, createdTask.taskRecord)
		XCTAssertEqual(createdTask.itemMetadata.id, fetchedTask.correspondingItem)
		XCTAssertEqual(createdTask.taskRecord.localURL, fetchedTask.localURL)
		XCTAssert(fetchedTask.replaceExisting)
	}

	func testInitWipesPendingDownloadTasksOnly() throws {
		// Init must wipe only download tasks, not the enumeration table.
		let freshDB = try DatabaseQueue()
		try DatabaseHelper.migrate(freshDB)
		let metadataManager = ItemMetadataDBManager(database: freshDB)

		let downloadItem = ItemMetadata(name: "DL.txt", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		let enumItem = ItemMetadata(name: "Folder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try metadataManager.cacheMetadata(downloadItem)
		try metadataManager.cacheMetadata(enumItem)
		try freshDB.write { db in
			try DownloadTaskRecord(correspondingItem: downloadItem.id!, replaceExisting: false, localURL: URL(string: "/tmp/dl")!).save(db)
			try ItemEnumerationTaskRecord(correspondingItem: enumItem.id!, pageToken: nil).save(db)
		}

		_ = try DownloadTaskDBManager(database: freshDB, itemMetadataManager: metadataManager)

		try freshDB.read { db in
			XCTAssertEqual(0, try DownloadTaskRecord.fetchCount(db), "init should wipe pending download tasks")
			XCTAssertEqual(1, try ItemEnumerationTaskRecord.fetchCount(db), "init must not touch the enumeration table")
		}
	}

	func testRemoveTaskRecord() throws {
		let createdTask = try createTestTask()
		try manager.removeTaskRecord(createdTask.taskRecord)
		XCTAssertThrowsError(try getTaskRecord(for: XCTUnwrap(createdTask.itemMetadata.id))) { error in
			guard case DBManagerError.taskNotFound = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}
	}

	private func createTestTask() throws -> DownloadTask {
		let cloudPath = CloudPath("/Test")
		let itemMetadata = ItemMetadata(name: "Test", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
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
