//
//  DeletionTaskManagerTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 12.09.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import XCTest
@testable import CryptomatorFileProvider

class DeletionTaskManagerTests: XCTestCase {
	var manager: DeletionTaskManager!
	var metadataManager: MetadataManager!
	var tmpDirURL: URL!
	override func setUpWithError() throws {
		tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: tmpDirURL, withIntermediateDirectories: true)
		let dbURL = tmpDirURL.appendingPathComponent("db.sqlite", isDirectory: false)
		let dbQueue = try DatabaseHelper.getMigratedDB(at: dbURL)
		manager = try DeletionTaskManager(with: dbQueue)
		metadataManager = MetadataManager(with: dbQueue)
	}

	override func tearDownWithError() throws {
		manager = nil
		metadataManager = nil
		try FileManager.default.removeItem(at: tmpDirURL)
	}

	func testCreateAndGetTask() throws {
		let cloudPath = CloudPath("/Test")
		let itemMetadata = ItemMetadata(name: "Test", type: .file, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
		try metadataManager.cacheMetadata(itemMetadata)
		try manager.createTask(for: itemMetadata)
		let fetchedTask = try manager.getTask(for: itemMetadata.id!)
		XCTAssertEqual(itemMetadata.id, fetchedTask.correspondingItem)
		XCTAssertEqual(itemMetadata.parentId, fetchedTask.parentId)
		XCTAssertEqual(cloudPath, fetchedTask.cloudPath)
	}

	func testRemoveTask() throws {
		let cloudPath = CloudPath("/Test")
		let itemMetadata = ItemMetadata(name: "Test", type: .file, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
		try metadataManager.cacheMetadata(itemMetadata)
		try manager.createTask(for: itemMetadata)
		let fetchedTask = try manager.getTask(for: itemMetadata.id!)
		try manager.removeTask(fetchedTask)
		XCTAssertThrowsError(try manager.getTask(for: itemMetadata.id!)) { error in
			guard case TaskError.taskNotFound = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}
	}

	func testGetTasksWhichWereIn() throws {
		let cloudPath = CloudPath("/Test")
		let itemMetadata = ItemMetadata(name: "Test", type: .file, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
		try metadataManager.cacheMetadata(itemMetadata)
		try manager.createTask(for: itemMetadata)
		let folderCloudPath = CloudPath("/Folder")
		let folderMetadata = ItemMetadata(name: "Folder", type: .folder, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: folderCloudPath, isPlaceholderItem: false)
		try metadataManager.cacheMetadata(folderMetadata)
		try manager.createTask(for: folderMetadata)
		let subfolderCloudPath = CloudPath("/Folder/SubFolder/")
		let subfolderMetadata = ItemMetadata(name: "SubFolder", type: .folder, size: nil, parentId: folderMetadata.id!, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: subfolderCloudPath, isPlaceholderItem: false)
		try metadataManager.cacheMetadata(subfolderMetadata)
		try manager.createTask(for: subfolderMetadata)
		let fileInsideFolderCloudPath = CloudPath("/Folder/FileInsideFolder")
		let fileInsideFolderMetadata = ItemMetadata(name: "FileInsideFolder", type: .file, size: nil, parentId: folderMetadata.id!, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: fileInsideFolderCloudPath, isPlaceholderItem: false)
		try metadataManager.cacheMetadata(fileInsideFolderMetadata)
		try manager.createTask(for: fileInsideFolderMetadata)
		let fetchedTasks = try manager.getTasksForItemsWhichWere(in: folderMetadata.id!)
		XCTAssertEqual(2, fetchedTasks.count)
		XCTAssert(fetchedTasks.contains(where: { $0.correspondingItem == fileInsideFolderMetadata.id && $0.cloudPath == fileInsideFolderCloudPath }))
		XCTAssert(fetchedTasks.contains(where: { $0.correspondingItem == subfolderMetadata.id && $0.cloudPath == subfolderCloudPath }))
	}
}
