//
//  OnlineItemNameCollisionHandlerTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 25.05.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import GRDB
import Promises
import XCTest
@testable import CryptomatorFileProvider

class OnlineItemNameCollisionHandlerTests: XCTestCase {
	var middleware: OnlineItemNameCollisionHandler<Void>!
	var itemMetadataManager: ItemMetadataDBManager!
	var tmpDirURL: URL!
	var dbPool: DatabaseWriter!

	override func setUpWithError() throws {
		tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: tmpDirURL, withIntermediateDirectories: true)
		let dbURL = tmpDirURL.appendingPathComponent("db.sqlite", isDirectory: false)
		dbPool = try DatabaseHelper.default.getMigratedDB(at: dbURL, purposeIdentifier: "unit-test")
		itemMetadataManager = ItemMetadataDBManager(database: dbPool)

		middleware = OnlineItemNameCollisionHandler(itemMetadataManager: itemMetadataManager)
	}

	override func tearDownWithError() throws {
		middleware = nil
		itemMetadataManager = nil
		dbPool = nil
		try FileManager.default.removeItem(at: tmpDirURL)
	}

	func testHandleCollision() throws {
		let expectation = XCTestExpectation()
		let originalCloudPath = CloudPath("/foo.txt")
		let workflowMock = WorkflowMiddlewareMock<Void> { task in
			if task.itemMetadata.cloudPath == originalCloudPath {
				return Promise(CloudProviderError.itemAlreadyExists)
			}
			return Promise(())
		}
		let itemMetadata = ItemMetadata(name: "foo.txt", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, cloudPath: originalCloudPath, isPlaceholderItem: true)
		try itemMetadataManager.cacheMetadata(itemMetadata)
		middleware.setNext(AnyWorkflowMiddleware(workflowMock))
		middleware.execute(task: SampleCloudTask(itemMetadata: itemMetadata)).then {
			guard let itemID = itemMetadata.id, let cachedItemMetadata = try self.itemMetadataManager.getCachedMetadata(for: itemID) else {
				XCTFail("ItemMetadata not found in DB")
				return
			}

			// Check that the path has been changed to a collision-free path.

			XCTAssert(cachedItemMetadata.name.hasPrefix("foo ("))
			XCTAssert(cachedItemMetadata.name.hasSuffix(").txt"))
			XCTAssertEqual(15, cachedItemMetadata.name.count)

			XCTAssert(cachedItemMetadata.cloudPath.path.hasPrefix("/foo ("))
			XCTAssert(cachedItemMetadata.cloudPath.path.hasSuffix(").txt"))
			XCTAssertEqual(16, cachedItemMetadata.cloudPath.path.count)

			// Check that the remaining item metadata properties have not changed.

			XCTAssertEqual(CloudItemType.file, cachedItemMetadata.type)
			XCTAssertNil(cachedItemMetadata.size)
			XCTAssertEqual(NSFileProviderItemIdentifier.rootContainerDatabaseValue, cachedItemMetadata.parentID)
			XCTAssertEqual(ItemStatus.isUploading, cachedItemMetadata.statusCode)
			XCTAssertTrue(cachedItemMetadata.isPlaceholderItem)

			XCTAssertEqual(itemMetadata, cachedItemMetadata)
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testRetryOnlyOnce() throws {
		let expectation = XCTestExpectation()
		let workflowMock = WorkflowMiddlewareMock<Void> { _ in
			return Promise(CloudProviderError.itemAlreadyExists)
		}
		let itemMetadata = ItemMetadata(name: "foo.txt", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, cloudPath: CloudPath("/foo.txt"), isPlaceholderItem: true)
		try itemMetadataManager.cacheMetadata(itemMetadata)
		middleware.setNext(AnyWorkflowMiddleware(workflowMock))
		middleware.execute(task: SampleCloudTask(itemMetadata: itemMetadata)).then {
			XCTFail("Promise fulfilled")
		}.catch { error in
			guard case CloudProviderError.itemAlreadyExists = error else {
				XCTFail("Promise rejected with wrong error: \(error)")
				return
			}
			guard let itemID = itemMetadata.id, let cachedItemMetadata = try? self.itemMetadataManager.getCachedMetadata(for: itemID) else {
				XCTFail("ItemMetadata not found in DB")
				return
			}

			// Check that the path has been changed to a collision-free path anyway.
			XCTAssert(cachedItemMetadata.name.hasPrefix("foo ("))
			XCTAssert(cachedItemMetadata.name.hasSuffix(").txt"))
			XCTAssertEqual(15, cachedItemMetadata.name.count)

			XCTAssert(cachedItemMetadata.cloudPath.path.hasPrefix("/foo ("))
			XCTAssert(cachedItemMetadata.cloudPath.path.hasSuffix(").txt"))
			XCTAssertEqual(16, cachedItemMetadata.cloudPath.path.count)

			// Check that the remaining item metadata properties have not changed.
			XCTAssertEqual(CloudItemType.file, cachedItemMetadata.type)
			XCTAssertNil(cachedItemMetadata.size)
			XCTAssertEqual(NSFileProviderItemIdentifier.rootContainerDatabaseValue, cachedItemMetadata.parentID)
			XCTAssertEqual(ItemStatus.isUploading, cachedItemMetadata.statusCode)
			XCTAssertTrue(cachedItemMetadata.isPlaceholderItem)
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testNoRetryForDifferentError() throws {
		let expectation = XCTestExpectation()
		let workflowMock = WorkflowMiddlewareMock<Void> { _ in
			return Promise(CloudProviderError.itemNotFound)
		}
		let itemMetadata = ItemMetadata(name: "foo.txt", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, cloudPath: CloudPath("/foo.txt"), isPlaceholderItem: true)
		try itemMetadataManager.cacheMetadata(itemMetadata)
		middleware.setNext(AnyWorkflowMiddleware(workflowMock))
		middleware.execute(task: SampleCloudTask(itemMetadata: itemMetadata)).then {
			XCTFail("Promise fulfilled")
		}.catch { error in
			guard case CloudProviderError.itemNotFound = error else {
				XCTFail("Promise rejected with wrong error: \(error)")
				return
			}
			guard let itemID = itemMetadata.id, let cachedItemMetadata = try? self.itemMetadataManager.getCachedMetadata(for: itemID) else {
				XCTFail("ItemMetadata not found in DB")
				return
			}

			// Check that the item metadata properties have not changed.
			XCTAssertEqual("foo.txt", cachedItemMetadata.name)
			XCTAssertEqual(CloudPath("/foo.txt"), cachedItemMetadata.cloudPath)
			XCTAssertEqual(CloudItemType.file, cachedItemMetadata.type)
			XCTAssertNil(cachedItemMetadata.size)
			XCTAssertEqual(NSFileProviderItemIdentifier.rootContainerDatabaseValue, cachedItemMetadata.parentID)
			XCTAssertEqual(ItemStatus.isUploading, cachedItemMetadata.statusCode)
			XCTAssertTrue(cachedItemMetadata.isPlaceholderItem)
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	private struct SampleCloudTask: CloudTask {
		let itemMetadata: ItemMetadata
	}
}
