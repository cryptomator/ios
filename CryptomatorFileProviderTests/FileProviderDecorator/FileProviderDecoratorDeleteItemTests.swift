//
//  FileProviderDecoratorDeleteItemTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 12.09.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import XCTest
@testable import CryptomatorFileProvider

class FileProviderDecoratorDeleteItemTests: FileProviderDecoratorTestCase {
	func testDeleteItemLocally() throws {
		let remoteURL = URL(fileURLWithPath: "/Test.txt", isDirectory: false)
		let itemMetadata = ItemMetadata(name: "Test.txt", type: .file, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: remoteURL.path, isPlaceholderItem: false)
		try decorator.itemMetadataManager.cacheMetadata(itemMetadata)
		let itemIdentifier = NSFileProviderItemIdentifier(rawValue: String(itemMetadata.id!))
		try decorator.deleteItemLocally(withIdentifier: itemIdentifier)
		guard try decorator.itemMetadataManager.getCachedMetadata(for: itemMetadata.id!) == nil else {
			XCTFail("Metadata is still in DB")
			return
		}
		let deletionTask = try decorator.deletionTaskManager.getTask(for: itemMetadata.id!)
		XCTAssertEqual(remoteURL, deletionTask.remoteURL)
		XCTAssertEqual(itemMetadata.id, deletionTask.correspondingItem)
		XCTAssertEqual(itemMetadata.parentId, deletionTask.parentId)
	}

	func testDeleteItemLocallyWithCachedFile() throws {
		let remoteURL = URL(fileURLWithPath: "/Test.txt", isDirectory: false)
		let itemMetadata = ItemMetadata(name: "Test.txt", type: .file, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: remoteURL.path, isPlaceholderItem: false)
		try decorator.itemMetadataManager.cacheMetadata(itemMetadata)
		let itemIdentifier = NSFileProviderItemIdentifier(rawValue: String(itemMetadata.id!))
		try decorator.cachedFileManager.cacheLocalFileInfo(for: 2, lastModifiedDate: Date(timeIntervalSinceReferenceDate: 0))
		let identifier = NSFileProviderItemIdentifier("2")
		guard let localURLForItem = decorator.urlForItem(withPersistentIdentifier: identifier) else {
			XCTFail("localURLForItem is nil")
			return
		}
		try FileManager.default.createDirectory(at: localURLForItem.deletingLastPathComponent(), withIntermediateDirectories: false, attributes: nil)
		let content = "TestLocalContent"
		try content.write(to: localURLForItem, atomically: true, encoding: .utf8)
		XCTAssert(FileManager.default.fileExists(atPath: localURLForItem.path))
		try decorator.deleteItemLocally(withIdentifier: itemIdentifier)
		guard try decorator.itemMetadataManager.getCachedMetadata(for: itemMetadata.id!) == nil else {
			XCTFail("Metadata is still in DB")
			return
		}
		let deletionTask = try decorator.deletionTaskManager.getTask(for: itemMetadata.id!)
		XCTAssertEqual(remoteURL, deletionTask.remoteURL)
		XCTAssertEqual(itemMetadata.id, deletionTask.correspondingItem)
		XCTAssertEqual(itemMetadata.parentId, deletionTask.parentId)
		XCTAssertFalse(FileManager.default.fileExists(atPath: localURLForItem.path))
	}

	func testDeleteItemLocallyWithFolder() throws {
		let folderRemoteURL = URL(fileURLWithPath: "/Folder/", isDirectory: true)
		let remoteURL = URL(fileURLWithPath: "/Folder/Test.txt", isDirectory: false)
		let folderItemMetadata = ItemMetadata(name: "Folder", type: .folder, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: folderRemoteURL.path, isPlaceholderItem: false)
		try decorator.itemMetadataManager.cacheMetadata(folderItemMetadata)
		let itemMetadata = ItemMetadata(name: "Test.txt", type: .file, size: nil, parentId: folderItemMetadata.parentId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: remoteURL.path, isPlaceholderItem: false)
		try decorator.itemMetadataManager.cacheMetadata(itemMetadata)
		let folderIdentifier = NSFileProviderItemIdentifier(rawValue: String(folderItemMetadata.id!))
		try decorator.cachedFileManager.cacheLocalFileInfo(for: itemMetadata.id!, lastModifiedDate: Date(timeIntervalSinceReferenceDate: 0))
		let identifier = NSFileProviderItemIdentifier("3")
		guard let localURLForItem = decorator.urlForItem(withPersistentIdentifier: identifier) else {
			XCTFail("localURLForItem is nil")
			return
		}
		try FileManager.default.createDirectory(at: localURLForItem.deletingLastPathComponent(), withIntermediateDirectories: false, attributes: nil)
		let content = "TestLocalContent"
		try content.write(to: localURLForItem, atomically: true, encoding: .utf8)
		XCTAssert(FileManager.default.fileExists(atPath: localURLForItem.path))
		try decorator.deleteItemLocally(withIdentifier: folderIdentifier)
		guard try decorator.itemMetadataManager.getCachedMetadata(for: folderItemMetadata.id!) == nil else {
			XCTFail("Metadata for Folder is still in DB")
			return
		}
		guard try decorator.itemMetadataManager.getCachedMetadata(for: itemMetadata.id!) == nil else {
			XCTFail("Metadata for File is still in DB")
			return
		}
		let folderDeletionTask = try decorator.deletionTaskManager.getTask(for: folderItemMetadata.id!)
		XCTAssertEqual(folderRemoteURL, folderDeletionTask.remoteURL)
		XCTAssertEqual(folderItemMetadata.id, folderDeletionTask.correspondingItem)
		XCTAssertEqual(folderItemMetadata.parentId, folderDeletionTask.parentId)
		XCTAssertThrowsError(try decorator.deletionTaskManager.getTask(for: itemMetadata.id!)) { error in
			guard case TaskError.taskNotFound = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}
		XCTAssertFalse(FileManager.default.fileExists(atPath: localURLForItem.path))
	}

	func testDeleteFileInCloud() throws {
		let remoteURL = URL(fileURLWithPath: "/Test.txt", isDirectory: false)
		let itemMetadata = ItemMetadata(name: "Test.txt", type: .file, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: remoteURL.path, isPlaceholderItem: false)
		try decorator.itemMetadataManager.cacheMetadata(itemMetadata)
		let itemIdentifier = NSFileProviderItemIdentifier(rawValue: String(itemMetadata.id!))
		try decorator.deleteItemLocally(withIdentifier: itemIdentifier)
		XCTAssertEqual(0, mockedProvider.deleted.count)
		let expectation = XCTestExpectation()
		decorator.deleteItemInCloud(withIdentifier: itemIdentifier).then {
			XCTAssertEqual(1, self.mockedProvider.deleted.count)
			XCTAssertEqual(remoteURL.relativePath, self.mockedProvider.deleted[0])
			XCTAssertThrowsError(try self.decorator.deletionTaskManager.getTask(for: itemMetadata.id!)) { error in
				guard case TaskError.taskNotFound = error else {
					XCTFail("Throws the wrong error: \(error)")
					return
				}
			}
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testDeleteItemInCloudFailsWithoutDeletionTask() throws {
		let remoteURL = URL(fileURLWithPath: "/Test.txt", isDirectory: false)
		let itemMetadata = ItemMetadata(name: "Test.txt", type: .file, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: remoteURL.path, isPlaceholderItem: false)
		try decorator.itemMetadataManager.cacheMetadata(itemMetadata)
		let itemIdentifier = NSFileProviderItemIdentifier(rawValue: String(itemMetadata.id!))
		let expectation = XCTestExpectation()
		decorator.deleteItemInCloud(withIdentifier: itemIdentifier).then {
			XCTFail("Promise was not rejected although no DeletionTask exists.")
		}.catch { error in
			guard case TaskError.taskNotFound = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}
}
