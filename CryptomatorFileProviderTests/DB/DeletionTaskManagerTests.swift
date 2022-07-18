//
//  DeletionTaskManagerTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 12.09.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import GRDB
import XCTest
@testable import CryptomatorFileProvider

class DeletionTaskManagerTests: XCTestCase {
	var manager: DeletionTaskDBManager!
	var itemMetadataManager: ItemMetadataDBManager!

	override func setUpWithError() throws {
		let inMemoryDB = DatabaseQueue()
		try DatabaseHelper.migrate(inMemoryDB)
		manager = try DeletionTaskDBManager(database: inMemoryDB)
		itemMetadataManager = ItemMetadataDBManager(database: inMemoryDB)
	}

	func testCreateAndGetTaskRecord() throws {
		let cloudPath = CloudPath("/Test")
		let itemMetadata = ItemMetadata(name: "Test", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
		try itemMetadataManager.cacheMetadata(itemMetadata)
		let createdTask = try manager.createTaskRecord(for: itemMetadata)
		let fetchedTask = try manager.getTaskRecord(for: itemMetadata.id!)
		XCTAssertEqual(fetchedTask, createdTask)
		XCTAssertEqual(itemMetadata.id, fetchedTask.correspondingItem)
		XCTAssertEqual(itemMetadata.parentID, fetchedTask.parentID)
		XCTAssertEqual(cloudPath, fetchedTask.cloudPath)
	}

	func testRemoveTaskRecord() throws {
		let cloudPath = CloudPath("/Test")
		let itemMetadata = ItemMetadata(name: "Test", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
		try itemMetadataManager.cacheMetadata(itemMetadata)
		let createdTask = try manager.createTaskRecord(for: itemMetadata)
		try manager.removeTaskRecord(createdTask)
		XCTAssertThrowsError(try manager.getTaskRecord(for: itemMetadata.id!)) { error in
			guard case DBManagerError.taskNotFound = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}
	}

	func testGetTaskRecordsWhichWereIn() throws {
		let cloudPath = CloudPath("/Test")
		let itemMetadata = ItemMetadata(name: "Test", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
		try itemMetadataManager.cacheMetadata(itemMetadata)
		_ = try manager.createTaskRecord(for: itemMetadata)
		let folderCloudPath = CloudPath("/Folder")
		let folderMetadata = ItemMetadata(name: "Folder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: folderCloudPath, isPlaceholderItem: false)
		try itemMetadataManager.cacheMetadata(folderMetadata)
		_ = try manager.createTaskRecord(for: folderMetadata)
		let subfolderCloudPath = CloudPath("/Folder/SubFolder/")
		let subfolderMetadata = ItemMetadata(name: "SubFolder", type: .folder, size: nil, parentID: folderMetadata.id!, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: subfolderCloudPath, isPlaceholderItem: false)
		try itemMetadataManager.cacheMetadata(subfolderMetadata)
		_ = try manager.createTaskRecord(for: subfolderMetadata)
		let fileInsideFolderCloudPath = CloudPath("/Folder/FileInsideFolder")
		let fileInsideFolderMetadata = ItemMetadata(name: "FileInsideFolder", type: .file, size: nil, parentID: folderMetadata.id!, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: fileInsideFolderCloudPath, isPlaceholderItem: false)
		try itemMetadataManager.cacheMetadata(fileInsideFolderMetadata)
		_ = try manager.createTaskRecord(for: fileInsideFolderMetadata)
		let fetchedTasks = try manager.getTaskRecordsForItemsWhichWere(in: folderMetadata.id!)
		XCTAssertEqual(2, fetchedTasks.count)
		XCTAssert(fetchedTasks.contains(where: { $0.correspondingItem == fileInsideFolderMetadata.id && $0.cloudPath == fileInsideFolderCloudPath }))
		XCTAssert(fetchedTasks.contains(where: { $0.correspondingItem == subfolderMetadata.id && $0.cloudPath == subfolderCloudPath }))
	}

	func testGetTask() throws {
		let cloudPath = CloudPath("/Test")
		let itemMetadata = ItemMetadata(name: "Test", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
		try itemMetadataManager.cacheMetadata(itemMetadata)
		let taskRecord = try manager.createTaskRecord(for: itemMetadata)
		let fetchedTask = try manager.getTask(for: taskRecord)
		XCTAssertEqual(itemMetadata, fetchedTask.itemMetadata)
		XCTAssertEqual(itemMetadata.id, fetchedTask.taskRecord.correspondingItem)
		XCTAssertEqual(itemMetadata.parentID, fetchedTask.taskRecord.parentID)
		XCTAssertEqual(cloudPath, fetchedTask.taskRecord.cloudPath)
	}
}

extension DeletionTaskRecord: Equatable {
	public static func == (lhs: DeletionTaskRecord, rhs: DeletionTaskRecord) -> Bool {
		lhs.cloudPath == rhs.cloudPath && lhs.correspondingItem == rhs.correspondingItem && lhs.itemType == rhs.itemType && lhs.parentID == rhs.parentID
	}
}
