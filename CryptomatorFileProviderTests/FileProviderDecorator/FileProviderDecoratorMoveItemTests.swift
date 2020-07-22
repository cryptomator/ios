//
//  FileProviderDecoratorMoveItemTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 22.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import XCTest
@testable import CryptomatorFileProvider
class FileProviderDecoratorMoveItemTests: FileProviderDecoratorTestCase {
	func testMoveItemLocallyOnlyNameChanged() throws {
		let remoteURL = URL(fileURLWithPath: "/Test.txt", isDirectory: false)
		let newRemoteURL = URL(fileURLWithPath: "/RenamedTest.txt", isDirectory: false)
		let itemMetadata = ItemMetadata(name: "Test.txt", type: .file, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: remoteURL.path, isPlaceholderItem: false)
		try decorator.itemMetadataManager.cacheMetadata(itemMetadata)
		let itemIdentifier = NSFileProviderItemIdentifier(rawValue: String(itemMetadata.id!))
		let newName = "RenamedTest.txt"
		let item = try decorator.moveItemLocally(withIdentifier: itemIdentifier, toParentItemWithIdentifier: nil, newName: newName)
		XCTAssertEqual(newName, item.filename)
		XCTAssertEqual(NSFileProviderItemIdentifier.rootContainer, item.parentItemIdentifier)
		XCTAssertEqual(itemIdentifier, item.itemIdentifier)
		XCTAssertEqual(ItemStatus.isUploading, item.metadata.statusCode)
		XCTAssertEqual(newRemoteURL.path, item.metadata.remotePath)
		guard let fetchedItemMetadata = try decorator.itemMetadataManager.getCachedMetadata(for: itemMetadata.id!) else {
			XCTFail("No Metadata in DB")
			return
		}
		XCTAssertEqual(newName, fetchedItemMetadata.name)
		XCTAssertEqual(MetadataManager.rootContainerId, fetchedItemMetadata.parentId)
		XCTAssertEqual(ItemStatus.isUploading, fetchedItemMetadata.statusCode)
		XCTAssertEqual(newRemoteURL.path, fetchedItemMetadata.remotePath)
		let reparenTask = try decorator.reparentTaskManager.getTask(for: itemMetadata.id!)
		XCTAssertEqual(itemMetadata.id!, reparenTask.correspondingItem)
		XCTAssertEqual(remoteURL, reparenTask.oldRemoteURL)
		XCTAssertEqual(newRemoteURL, reparenTask.newRemoteURL)
	}

	func testMoveItemLocallyOnlyParentChanged() throws {
		let remoteURL = URL(fileURLWithPath: "/Test.txt", isDirectory: false)
		let newRemoteURL = URL(fileURLWithPath: "/Folder/Test.txt", isDirectory: false)
		let itemMetadata = ItemMetadata(name: "Test.txt", type: .file, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: remoteURL.path, isPlaceholderItem: false)
		let newParentRemoteURL = URL(fileURLWithPath: "/Folder/", isDirectory: true)
		let newParentItemMetadata = ItemMetadata(name: "Folder", type: .folder, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: newParentRemoteURL.path, isPlaceholderItem: false)
		try decorator.itemMetadataManager.cacheMetadatas([itemMetadata, newParentItemMetadata])

		let itemIdentifier = NSFileProviderItemIdentifier(rawValue: String(itemMetadata.id!))
		let parentItemIdentifier = NSFileProviderItemIdentifier(rawValue: String(newParentItemMetadata.id!))
		let item = try decorator.moveItemLocally(withIdentifier: itemIdentifier, toParentItemWithIdentifier: parentItemIdentifier, newName: nil)
		XCTAssertEqual("Test.txt", item.filename)
		XCTAssertEqual(parentItemIdentifier, item.parentItemIdentifier)
		XCTAssertEqual(itemIdentifier, item.itemIdentifier)
		XCTAssertEqual(ItemStatus.isUploading, item.metadata.statusCode)
		XCTAssertEqual(newRemoteURL.path, item.metadata.remotePath)
		guard let fetchedItemMetadata = try decorator.itemMetadataManager.getCachedMetadata(for: itemMetadata.id!) else {
			XCTFail("No Metadata in DB")
			return
		}
		XCTAssertEqual("Test.txt", fetchedItemMetadata.name)
		XCTAssertEqual(newParentItemMetadata.id, fetchedItemMetadata.parentId)
		XCTAssertEqual(ItemStatus.isUploading, fetchedItemMetadata.statusCode)
		XCTAssertEqual(newRemoteURL.path, fetchedItemMetadata.remotePath)
		let reparenTask = try decorator.reparentTaskManager.getTask(for: itemMetadata.id!)
		XCTAssertEqual(itemMetadata.id!, reparenTask.correspondingItem)
		XCTAssertEqual(remoteURL, reparenTask.oldRemoteURL)
		XCTAssertEqual(newRemoteURL, reparenTask.newRemoteURL)
	}

	func testMoveItemLocally() throws {
		let remoteURL = URL(fileURLWithPath: "/Test.txt", isDirectory: false)
		let newRemoteURL = URL(fileURLWithPath: "/Folder/RenamedTest.txt", isDirectory: false)
		let itemMetadata = ItemMetadata(name: "Test.txt", type: .file, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: remoteURL.path, isPlaceholderItem: false)
		let newParentRemoteURL = URL(fileURLWithPath: "/Folder/", isDirectory: true)
		let newParentItemMetadata = ItemMetadata(name: "Folder", type: .folder, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: newParentRemoteURL.path, isPlaceholderItem: false)
		try decorator.itemMetadataManager.cacheMetadatas([itemMetadata, newParentItemMetadata])

		let itemIdentifier = NSFileProviderItemIdentifier(rawValue: String(itemMetadata.id!))
		let parentItemIdentifier = NSFileProviderItemIdentifier(rawValue: String(newParentItemMetadata.id!))
		let newName = "RenamedTest.txt"
		let item = try decorator.moveItemLocally(withIdentifier: itemIdentifier, toParentItemWithIdentifier: parentItemIdentifier, newName: newName)
		XCTAssertEqual(newName, item.filename)
		XCTAssertEqual(parentItemIdentifier, item.parentItemIdentifier)
		XCTAssertEqual(itemIdentifier, item.itemIdentifier)
		XCTAssertEqual(ItemStatus.isUploading, item.metadata.statusCode)
		XCTAssertEqual(newRemoteURL.path, item.metadata.remotePath)
		guard let fetchedItemMetadata = try decorator.itemMetadataManager.getCachedMetadata(for: itemMetadata.id!) else {
			XCTFail("No Metadata in DB")
			return
		}
		XCTAssertEqual(newName, fetchedItemMetadata.name)
		XCTAssertEqual(newParentItemMetadata.id, fetchedItemMetadata.parentId)
		XCTAssertEqual(ItemStatus.isUploading, fetchedItemMetadata.statusCode)
		XCTAssertEqual(newRemoteURL.path, fetchedItemMetadata.remotePath)
		let reparenTask = try decorator.reparentTaskManager.getTask(for: itemMetadata.id!)
		XCTAssertEqual(itemMetadata.id!, reparenTask.correspondingItem)
		XCTAssertEqual(remoteURL, reparenTask.oldRemoteURL)
		XCTAssertEqual(newRemoteURL, reparenTask.newRemoteURL)
	}

	func testMoveItemInCloud() throws {
		let remoteURL = URL(fileURLWithPath: "/Test.txt", isDirectory: false)
		let newRemoteURL = URL(fileURLWithPath: "/Folder/RenamedTest.txt", isDirectory: false)
		let itemMetadata = ItemMetadata(name: "Test.txt", type: .file, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: remoteURL.path, isPlaceholderItem: false)
		let newParentRemoteURL = URL(fileURLWithPath: "/Folder/", isDirectory: true)
		let newParentItemMetadata = ItemMetadata(name: "Folder", type: .folder, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: newParentRemoteURL.path, isPlaceholderItem: false)
		try decorator.itemMetadataManager.cacheMetadatas([itemMetadata, newParentItemMetadata])

		let itemIdentifier = NSFileProviderItemIdentifier(rawValue: String(itemMetadata.id!))
		let parentItemIdentifier = NSFileProviderItemIdentifier(rawValue: String(newParentItemMetadata.id!))
		let newName = "RenamedTest.txt"
		_ = try decorator.moveItemLocally(withIdentifier: itemIdentifier, toParentItemWithIdentifier: parentItemIdentifier, newName: newName)
		let expectation = XCTestExpectation()
		decorator.moveItemInCloud(withIdentifier: itemIdentifier).then { item in
			XCTAssertEqual(newName, item.filename)
			XCTAssertEqual(parentItemIdentifier, item.parentItemIdentifier)
			XCTAssertEqual(ItemStatus.isUploaded, item.metadata.statusCode)
			XCTAssertEqual(self.mockedProvider.moved[remoteURL.path], newRemoteURL.path)
			XCTAssertThrowsError(try self.decorator.reparentTaskManager.getTask(for: itemMetadata.id!)) { error in
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

	func testMoveItemCloudItemNameCollisionHandling() throws {
		let remoteURL = URL(fileURLWithPath: "/Test.txt", isDirectory: false)
		let itemMetadata = ItemMetadata(name: "Test.txt", type: .file, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: remoteURL.path, isPlaceholderItem: false)

		try decorator.itemMetadataManager.cacheMetadata(itemMetadata)

		let itemIdentifier = NSFileProviderItemIdentifier(rawValue: String(itemMetadata.id!))

		let newName = "FileAlreadyExists.txt"
		_ = try decorator.moveItemLocally(withIdentifier: itemIdentifier, toParentItemWithIdentifier: nil, newName: newName)
		let expectation = XCTestExpectation()
		decorator.moveItemInCloud(withIdentifier: itemIdentifier).then { item in
			XCTAssertEqual(ItemStatus.isUploaded, item.metadata.statusCode)
			XCTAssertNotEqual("FileAlreadyExists.txt", item.filename)
			XCTAssertEqual(NSFileProviderItemIdentifier.rootContainer, item.parentItemIdentifier)
			// Ensure that the file with the collision hash was moved
			XCTAssert(self.mockedProvider.moved[remoteURL.path]?.hasPrefix("/FileAlreadyExists (") ?? false)
			XCTAssert(self.mockedProvider.moved[remoteURL.path]?.hasSuffix(").txt") ?? false)
			XCTAssertEqual(30, self.mockedProvider.moved[remoteURL.path]?.count)
			XCTAssertThrowsError(try self.decorator.reparentTaskManager.getTask(for: itemMetadata.id!)) { error in
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
		wait(for: [expectation], timeout: 2.0)
	}

	func testMoveItemInCloudReportsErrorWithFileProviderItem() throws {
		let remoteURL = URL(fileURLWithPath: "/Test.txt", isDirectory: false)
		let itemMetadata = ItemMetadata(name: "Test.txt", type: .file, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: remoteURL.path, isPlaceholderItem: false)

		try decorator.itemMetadataManager.cacheMetadata(itemMetadata)

		let itemIdentifier = NSFileProviderItemIdentifier(rawValue: String(itemMetadata.id!))

		let newName = "quotaInsufficient.txt"
		_ = try decorator.moveItemLocally(withIdentifier: itemIdentifier, toParentItemWithIdentifier: nil, newName: newName)
		let expectation = XCTestExpectation()
		decorator.moveItemInCloud(withIdentifier: itemIdentifier).then { item in
			XCTAssertEqual(ItemStatus.uploadError, item.metadata.statusCode)
			XCTAssertEqual("quotaInsufficient.txt", item.filename)
			XCTAssertEqual(NSFileProviderItemIdentifier.rootContainer, item.parentItemIdentifier)
			guard let actualError = item.uploadingError as NSError? else {
				XCTFail("Item has no Error")
				return
			}
			let expectedError = NSFileProviderError(.insufficientQuota) as NSError
			XCTAssertTrue(expectedError.isEqual(actualError))
			XCTAssertThrowsError(try self.decorator.reparentTaskManager.getTask(for: itemMetadata.id!)) { error in
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
		wait(for: [expectation], timeout: 2.0)
	}
}
