//
//  DeletionTaskManagerTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 12.09.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

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
		let dbQueue = try DataBaseHelper.getDBMigratedQueue(at: dbURL.path)
		manager = try DeletionTaskManager(with: dbQueue)
		metadataManager = MetadataManager(with: dbQueue)
	}

	override func tearDownWithError() throws {
		manager = nil
		metadataManager = nil
		try FileManager.default.removeItem(at: tmpDirURL)
	}

	func testCreateAndGetTask() throws {
		let remoteURL = URL(fileURLWithPath: "/Test", isDirectory: false)
		let itemMetadata = ItemMetadata(name: "Test", type: .file, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: remoteURL.relativePath, isPlaceholderItem: false)
		try metadataManager.cacheMetadata(itemMetadata)
		try manager.createTask(for: itemMetadata)
		let fetchedTask = try manager.getTask(for: itemMetadata.id!)
		XCTAssertEqual(itemMetadata.id, fetchedTask.correspondingItem)
		XCTAssertEqual(itemMetadata.parentId, fetchedTask.parentId)
		XCTAssertEqual(remoteURL, fetchedTask.remoteURL)
	}

	func testRemoveTask() throws {
		let remoteURL = URL(fileURLWithPath: "/Test", isDirectory: false)
		let itemMetadata = ItemMetadata(name: "Test", type: .file, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: remoteURL.relativePath, isPlaceholderItem: false)
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
		let remoteURL = URL(fileURLWithPath: "/Test", isDirectory: false)
		let itemMetadata = ItemMetadata(name: "Test", type: .file, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: remoteURL.relativePath, isPlaceholderItem: false)
		try metadataManager.cacheMetadata(itemMetadata)
		try manager.createTask(for: itemMetadata)
		let folderRemoteURL = URL(fileURLWithPath: "/Folder", isDirectory: true)
		let folderMetadata = ItemMetadata(name: "Folder", type: .folder, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: folderRemoteURL.relativePath, isPlaceholderItem: false)
		try metadataManager.cacheMetadata(folderMetadata)
		try manager.createTask(for: folderMetadata)
		let subfolderRemoteURL = URL(fileURLWithPath: "/Folder/SubFolder/", isDirectory: true)
		let subfolderMetadata = ItemMetadata(name: "SubFolder", type: .folder, size: nil, parentId: folderMetadata.id!, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: subfolderRemoteURL.relativePath, isPlaceholderItem: false)
		try metadataManager.cacheMetadata(subfolderMetadata)
		try manager.createTask(for: subfolderMetadata)
		let fileInsideFolderRemoteURL = URL(fileURLWithPath: "/Folder/FileInsideFolder", isDirectory: false)
		let fileInsideFolderMetadata = ItemMetadata(name: "FileInsideFolder", type: .file, size: nil, parentId: folderMetadata.id!, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: fileInsideFolderRemoteURL.relativePath, isPlaceholderItem: false)
		try metadataManager.cacheMetadata(fileInsideFolderMetadata)
		try manager.createTask(for: fileInsideFolderMetadata)
		let fetchedTasks = try manager.getTasksForItemsWhichWere(in: folderMetadata.id!)
		XCTAssertEqual(2, fetchedTasks.count)
		XCTAssert(fetchedTasks.contains(where: { $0.correspondingItem == fileInsideFolderMetadata.id && $0.remoteURL == fileInsideFolderRemoteURL }))
		XCTAssert(fetchedTasks.contains(where: { $0.correspondingItem == subfolderMetadata.id && $0.remoteURL == subfolderRemoteURL }))
	}
}
