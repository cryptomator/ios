//
//  DeletionTaskManagerTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 12.09.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import XCTest
@testable import CryptomatorFileProvider

class DeletionTaskManagerTests: XCTestCase {
	var manager: DeletionTaskDBManager!
	var metadataManager: MetadataDBManager!
	var tmpDirURL: URL!
	override func setUpWithError() throws {
		tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: tmpDirURL, withIntermediateDirectories: true)
		let dbURL = tmpDirURL.appendingPathComponent("db.sqlite", isDirectory: false)
		let dbQueue = try DatabaseHelper.getMigratedDB(at: dbURL)
		manager = try DeletionTaskDBManager(with: dbQueue)
		metadataManager = MetadataDBManager(with: dbQueue)
	}

	override func tearDownWithError() throws {
		manager = nil
		metadataManager = nil
		try FileManager.default.removeItem(at: tmpDirURL)
	}

	func testCreateAndGetTaskRecord() throws {
		let cloudPath = CloudPath("/Test")
		let itemMetadata = ItemMetadata(name: "Test", type: .file, size: nil, parentId: MetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
		try metadataManager.cacheMetadata(itemMetadata)
		try manager.createTaskRecord(for: itemMetadata)
		let fetchedTask = try manager.getTaskRecord(for: itemMetadata.id!)
		XCTAssertEqual(itemMetadata.id, fetchedTask.correspondingItem)
		XCTAssertEqual(itemMetadata.parentId, fetchedTask.parentId)
		XCTAssertEqual(cloudPath, fetchedTask.cloudPath)
	}

	func testRemoveTaskRecord() throws {
		let cloudPath = CloudPath("/Test")
		let itemMetadata = ItemMetadata(name: "Test", type: .file, size: nil, parentId: MetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
		try metadataManager.cacheMetadata(itemMetadata)
		try manager.createTaskRecord(for: itemMetadata)
		let fetchedTask = try manager.getTaskRecord(for: itemMetadata.id!)
		try manager.removeTaskRecord(fetchedTask)
		XCTAssertThrowsError(try manager.getTaskRecord(for: itemMetadata.id!)) { error in
			guard case TaskError.taskNotFound = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}
	}

	func testGetTaskRecordsWhichWereIn() throws {
		let cloudPath = CloudPath("/Test")
		let itemMetadata = ItemMetadata(name: "Test", type: .file, size: nil, parentId: MetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
		try metadataManager.cacheMetadata(itemMetadata)
		try manager.createTaskRecord(for: itemMetadata)
		let folderCloudPath = CloudPath("/Folder")
		let folderMetadata = ItemMetadata(name: "Folder", type: .folder, size: nil, parentId: MetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: folderCloudPath, isPlaceholderItem: false)
		try metadataManager.cacheMetadata(folderMetadata)
		try manager.createTaskRecord(for: folderMetadata)
		let subfolderCloudPath = CloudPath("/Folder/SubFolder/")
		let subfolderMetadata = ItemMetadata(name: "SubFolder", type: .folder, size: nil, parentId: folderMetadata.id!, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: subfolderCloudPath, isPlaceholderItem: false)
		try metadataManager.cacheMetadata(subfolderMetadata)
		try manager.createTaskRecord(for: subfolderMetadata)
		let fileInsideFolderCloudPath = CloudPath("/Folder/FileInsideFolder")
		let fileInsideFolderMetadata = ItemMetadata(name: "FileInsideFolder", type: .file, size: nil, parentId: folderMetadata.id!, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: fileInsideFolderCloudPath, isPlaceholderItem: false)
		try metadataManager.cacheMetadata(fileInsideFolderMetadata)
		try manager.createTaskRecord(for: fileInsideFolderMetadata)
		let fetchedTasks = try manager.getTaskRecordsForItemsWhichWere(in: folderMetadata.id!)
		XCTAssertEqual(2, fetchedTasks.count)
		XCTAssert(fetchedTasks.contains(where: { $0.correspondingItem == fileInsideFolderMetadata.id && $0.cloudPath == fileInsideFolderCloudPath }))
		XCTAssert(fetchedTasks.contains(where: { $0.correspondingItem == subfolderMetadata.id && $0.cloudPath == subfolderCloudPath }))
	}

	func testGetTask() throws {
		let cloudPath = CloudPath("/Test")
		let itemMetadata = ItemMetadata(name: "Test", type: .file, size: nil, parentId: MetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
		try metadataManager.cacheMetadata(itemMetadata)
		let taskRecord = try manager.createTaskRecord(for: itemMetadata)
		let fetchedTask = try manager.getTask(for: taskRecord)
		XCTAssertEqual(itemMetadata, fetchedTask.itemMetadata)
		XCTAssertEqual(itemMetadata.id, fetchedTask.taskRecord.correspondingItem)
		XCTAssertEqual(itemMetadata.parentId, fetchedTask.taskRecord.parentId)
		XCTAssertEqual(cloudPath, fetchedTask.taskRecord.cloudPath)
	}
}
