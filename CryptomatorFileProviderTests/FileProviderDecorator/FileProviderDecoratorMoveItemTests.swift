//
//  FileProviderDecoratorMoveItemTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 22.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import XCTest
@testable import CryptomatorFileProvider

class FileProviderDecoratorMoveItemTests: FileProviderDecoratorTestCase {
	func testMoveItemLocallyOnlyNameChanged() throws {
		let sourceCloudPath = CloudPath("/Test.txt")
		let targetCloudPath = CloudPath("/RenamedTest.txt")
		let itemMetadata = ItemMetadata(name: "Test.txt", type: .file, size: nil, parentId: MetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: sourceCloudPath, isPlaceholderItem: false)
		try decorator.itemMetadataManager.cacheMetadata(itemMetadata)
		let itemIdentifier = NSFileProviderItemIdentifier(rawValue: String(itemMetadata.id!))
		let newName = "RenamedTest.txt"
		let item = try decorator.moveItemLocally(withIdentifier: itemIdentifier, toParentItemWithIdentifier: nil, newName: newName)
		XCTAssertEqual(newName, item.filename)
		XCTAssertEqual(NSFileProviderItemIdentifier.rootContainer, item.parentItemIdentifier)
		XCTAssertEqual(itemIdentifier, item.itemIdentifier)
		XCTAssertEqual(ItemStatus.isUploading, item.metadata.statusCode)
		XCTAssertEqual(targetCloudPath, item.metadata.cloudPath)
		guard let fetchedItemMetadata = try decorator.itemMetadataManager.getCachedMetadata(for: itemMetadata.id!) else {
			XCTFail("No Metadata in DB")
			return
		}
		XCTAssertEqual(newName, fetchedItemMetadata.name)
		XCTAssertEqual(MetadataDBManager.rootContainerId, fetchedItemMetadata.parentId)
		XCTAssertEqual(ItemStatus.isUploading, fetchedItemMetadata.statusCode)
		XCTAssertEqual(targetCloudPath, fetchedItemMetadata.cloudPath)
		let reparenTask = try decorator.reparentTaskManager.getTask(for: itemMetadata.id!)
		XCTAssertEqual(itemMetadata.id!, reparenTask.correspondingItem)
		XCTAssertEqual(sourceCloudPath, reparenTask.sourceCloudPath)
		XCTAssertEqual(targetCloudPath, reparenTask.targetCloudPath)
	}

	func testMoveItemLocallyOnlyParentChanged() throws {
		let sourceCloudPath = CloudPath("/Test.txt")
		let targetCloudPath = CloudPath("/Folder/Test.txt")
		let itemMetadata = ItemMetadata(name: "Test.txt", type: .file, size: nil, parentId: MetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: sourceCloudPath, isPlaceholderItem: false)
		let targetParentCloudPath = CloudPath("/Folder/")
		let newParentItemMetadata = ItemMetadata(name: "Folder", type: .folder, size: nil, parentId: MetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: targetParentCloudPath, isPlaceholderItem: false)
		try decorator.itemMetadataManager.cacheMetadatas([itemMetadata, newParentItemMetadata])

		let itemIdentifier = NSFileProviderItemIdentifier(rawValue: String(itemMetadata.id!))
		let parentItemIdentifier = NSFileProviderItemIdentifier(rawValue: String(newParentItemMetadata.id!))
		let item = try decorator.moveItemLocally(withIdentifier: itemIdentifier, toParentItemWithIdentifier: parentItemIdentifier, newName: nil)
		XCTAssertEqual("Test.txt", item.filename)
		XCTAssertEqual(parentItemIdentifier, item.parentItemIdentifier)
		XCTAssertEqual(itemIdentifier, item.itemIdentifier)
		XCTAssertEqual(ItemStatus.isUploading, item.metadata.statusCode)
		XCTAssertEqual(targetCloudPath, item.metadata.cloudPath)
		guard let fetchedItemMetadata = try decorator.itemMetadataManager.getCachedMetadata(for: itemMetadata.id!) else {
			XCTFail("No Metadata in DB")
			return
		}
		XCTAssertEqual("Test.txt", fetchedItemMetadata.name)
		XCTAssertEqual(newParentItemMetadata.id, fetchedItemMetadata.parentId)
		XCTAssertEqual(ItemStatus.isUploading, fetchedItemMetadata.statusCode)
		XCTAssertEqual(targetCloudPath, fetchedItemMetadata.cloudPath)
		let reparenTask = try decorator.reparentTaskManager.getTask(for: itemMetadata.id!)
		XCTAssertEqual(itemMetadata.id!, reparenTask.correspondingItem)
		XCTAssertEqual(sourceCloudPath, reparenTask.sourceCloudPath)
		XCTAssertEqual(targetCloudPath, reparenTask.targetCloudPath)
	}

	func testMoveItemLocally() throws {
		let sourceCloudPath = CloudPath("/Test.txt")
		let targetCloudPath = CloudPath("/Folder/RenamedTest.txt")
		let itemMetadata = ItemMetadata(name: "Test.txt", type: .file, size: nil, parentId: MetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: sourceCloudPath, isPlaceholderItem: false)
		let targetParentCloudPath = CloudPath("/Folder/")
		let newParentItemMetadata = ItemMetadata(name: "Folder", type: .folder, size: nil, parentId: MetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: targetParentCloudPath, isPlaceholderItem: false)
		try decorator.itemMetadataManager.cacheMetadatas([itemMetadata, newParentItemMetadata])

		let itemIdentifier = NSFileProviderItemIdentifier(rawValue: String(itemMetadata.id!))
		let parentItemIdentifier = NSFileProviderItemIdentifier(rawValue: String(newParentItemMetadata.id!))
		let newName = "RenamedTest.txt"
		let item = try decorator.moveItemLocally(withIdentifier: itemIdentifier, toParentItemWithIdentifier: parentItemIdentifier, newName: newName)
		XCTAssertEqual(newName, item.filename)
		XCTAssertEqual(parentItemIdentifier, item.parentItemIdentifier)
		XCTAssertEqual(itemIdentifier, item.itemIdentifier)
		XCTAssertEqual(ItemStatus.isUploading, item.metadata.statusCode)
		XCTAssertEqual(targetCloudPath, item.metadata.cloudPath)
		guard let fetchedItemMetadata = try decorator.itemMetadataManager.getCachedMetadata(for: itemMetadata.id!) else {
			XCTFail("No Metadata in DB")
			return
		}
		XCTAssertEqual(newName, fetchedItemMetadata.name)
		XCTAssertEqual(newParentItemMetadata.id, fetchedItemMetadata.parentId)
		XCTAssertEqual(ItemStatus.isUploading, fetchedItemMetadata.statusCode)
		XCTAssertEqual(targetCloudPath, fetchedItemMetadata.cloudPath)
		let reparenTask = try decorator.reparentTaskManager.getTask(for: itemMetadata.id!)
		XCTAssertEqual(itemMetadata.id!, reparenTask.correspondingItem)
		XCTAssertEqual(sourceCloudPath, reparenTask.sourceCloudPath)
		XCTAssertEqual(targetCloudPath, reparenTask.targetCloudPath)
	}

	func testMoveFileInCloud() throws {
		let sourceCloudPath = CloudPath("/Test.txt")
		let targetCloudPath = CloudPath("/Folder/RenamedTest.txt")
		let itemMetadata = ItemMetadata(name: "Test.txt", type: .file, size: nil, parentId: MetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: sourceCloudPath, isPlaceholderItem: false)
		let targetParentCloudPath = CloudPath("/Folder/")
		let newParentItemMetadata = ItemMetadata(name: "Folder", type: .folder, size: nil, parentId: MetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: targetParentCloudPath, isPlaceholderItem: false)
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
			XCTAssertEqual(self.mockedProvider.movedFiles[sourceCloudPath.path], targetCloudPath.path)
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
		let cloudPath = CloudPath("/Test.txt")
		let itemMetadata = ItemMetadata(name: "Test.txt", type: .file, size: nil, parentId: MetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)

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
			XCTAssert(self.mockedProvider.movedFiles[cloudPath.path]?.hasPrefix("/FileAlreadyExists (") ?? false)
			XCTAssert(self.mockedProvider.movedFiles[cloudPath.path]?.hasSuffix(").txt") ?? false)
			XCTAssertEqual(30, self.mockedProvider.movedFiles[cloudPath.path]?.count)
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
		let cloudPath = CloudPath("/Test.txt")
		let itemMetadata = ItemMetadata(name: "Test.txt", type: .file, size: nil, parentId: MetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)

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
