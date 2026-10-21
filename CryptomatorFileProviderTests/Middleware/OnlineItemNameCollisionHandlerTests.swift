//
//  OnlineItemNameCollisionHandlerTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 25.05.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import GRDB
import XCTest
@testable import CryptomatorFileProvider

@MainActor
class OnlineItemNameCollisionHandlerTests: XCTestCase {
	var middleware: OnlineItemNameCollisionHandler<Void>!
	var itemMetadataManager: ItemMetadataDBManager!
	var tmpDirURL: URL!
	var dbPool: DatabaseWriter!

	override func setUp() async throws {
		try await super.setUp()
		tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: tmpDirURL, withIntermediateDirectories: true)
		let dbURL = tmpDirURL.appendingPathComponent("db.sqlite", isDirectory: false)
		dbPool = try DatabaseHelper.default.getMigratedDB(at: dbURL, purposeIdentifier: "unit-test")
		itemMetadataManager = ItemMetadataDBManager(database: dbPool)

		middleware = OnlineItemNameCollisionHandler(itemMetadataManager: itemMetadataManager)
	}

	override func tearDown() async throws {
		middleware = nil
		itemMetadataManager = nil
		dbPool = nil
		try FileManager.default.removeItem(at: tmpDirURL)
		try await super.tearDown()
	}

	func testHandleCollision() async throws {
		let originalCloudPath = CloudPath("/foo.txt")
		let workflowMock = WorkflowMiddlewareMock<Void> { task in
			if task.cloudPath == originalCloudPath {
				throw CloudProviderError.itemAlreadyExists
			}
		}
		let itemMetadata = ItemMetadata(name: "foo.txt", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, isPlaceholderItem: true)
		try itemMetadataManager.cacheMetadata(itemMetadata)
		middleware.setNext(AnyWorkflowMiddleware(workflowMock))
		try await middleware.execute(task: FolderCreationTask(itemMetadata: itemMetadata, cloudPath: originalCloudPath))
		let itemID = try XCTUnwrap(itemMetadata.id)
		let cachedItemMetadata = try XCTUnwrap(itemMetadataManager.getCachedMetadata(for: itemID), "ItemMetadata not found in DB")

		// Check that the path has been changed to a collision-free path.

		XCTAssert(cachedItemMetadata.name.hasPrefix("foo ("))
		XCTAssert(cachedItemMetadata.name.hasSuffix(").txt"))
		XCTAssertEqual(15, cachedItemMetadata.name.count)

		let cachedCloudPath = (try? itemMetadataManager.getCloudPath(for: itemID)) ?? CloudPath("/")
		XCTAssert(cachedCloudPath.path.hasPrefix("/foo ("))
		XCTAssert(cachedCloudPath.path.hasSuffix(").txt"))
		XCTAssertEqual(16, cachedCloudPath.path.count)

		// Check that the remaining item metadata properties have not changed.

		XCTAssertEqual(CloudItemType.file, cachedItemMetadata.type)
		XCTAssertNil(cachedItemMetadata.size)
		XCTAssertEqual(NSFileProviderItemIdentifier.rootContainerDatabaseValue, cachedItemMetadata.parentID)
		XCTAssertEqual(ItemStatus.isUploading, cachedItemMetadata.statusCode)
		XCTAssertTrue(cachedItemMetadata.isPlaceholderItem)

		XCTAssertEqual(itemMetadata, cachedItemMetadata)
	}

	func testRetryOnlyOnce() async throws {
		let workflowMock = WorkflowMiddlewareMock<Void> { _ in
			throw CloudProviderError.itemAlreadyExists
		}
		let itemMetadata = ItemMetadata(name: "foo.txt", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, isPlaceholderItem: true)
		try itemMetadataManager.cacheMetadata(itemMetadata)
		middleware.setNext(AnyWorkflowMiddleware(workflowMock))
		let sampleCloudPath = CloudPath("/foo.txt")
		await XCTAssertThrowsAsyncError(try await middleware.execute(task: FolderCreationTask(itemMetadata: itemMetadata, cloudPath: sampleCloudPath))) { error in
			guard case CloudProviderError.itemAlreadyExists = error else {
				XCTFail("Workflow failed with wrong error: \(error)")
				return
			}
		}
		let itemID = try XCTUnwrap(itemMetadata.id)
		let cachedItemMetadata = try XCTUnwrap(itemMetadataManager.getCachedMetadata(for: itemID), "ItemMetadata not found in DB")

		// Check that the path has been changed to a collision-free path anyway.
		XCTAssert(cachedItemMetadata.name.hasPrefix("foo ("))
		XCTAssert(cachedItemMetadata.name.hasSuffix(").txt"))
		XCTAssertEqual(15, cachedItemMetadata.name.count)

		let cachedCloudPath = (try? itemMetadataManager.getCloudPath(for: itemID)) ?? CloudPath("/")
		XCTAssert(cachedCloudPath.path.hasPrefix("/foo ("))
		XCTAssert(cachedCloudPath.path.hasSuffix(").txt"))
		XCTAssertEqual(16, cachedCloudPath.path.count)

		// Check that the remaining item metadata properties have not changed.
		XCTAssertEqual(CloudItemType.file, cachedItemMetadata.type)
		XCTAssertNil(cachedItemMetadata.size)
		XCTAssertEqual(NSFileProviderItemIdentifier.rootContainerDatabaseValue, cachedItemMetadata.parentID)
		XCTAssertEqual(ItemStatus.isUploading, cachedItemMetadata.statusCode)
		XCTAssertTrue(cachedItemMetadata.isPlaceholderItem)
	}

	func testNoRenameForFailDisposition() async throws {
		var executedCloudPaths = [CloudPath]()
		let workflowMock = WorkflowMiddlewareMock<Void> { task in
			executedCloudPaths.append(task.cloudPath)
			throw CloudProviderError.itemAlreadyExists
		}
		let itemMetadata = ItemMetadata(name: "Attachments", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, isPlaceholderItem: true)
		try itemMetadataManager.cacheMetadata(itemMetadata)
		middleware.setNext(AnyWorkflowMiddleware(workflowMock))
		let sampleCloudPath = CloudPath("/Attachments")
		await XCTAssertThrowsAsyncError(try await middleware.execute(task: FolderCreationTask(itemMetadata: itemMetadata, cloudPath: sampleCloudPath, onlineCollisionDisposition: .fail))) { error in
			guard case CloudProviderError.itemAlreadyExists = error else {
				XCTFail("Workflow failed with wrong error: \(error)")
				return
			}
		}
		// The retry is what creates the renamed object remotely, so it must not have happened at all.
		XCTAssertEqual([sampleCloudPath], executedCloudPaths)
		let itemID = try XCTUnwrap(itemMetadata.id)
		let cachedItemMetadata = try XCTUnwrap(itemMetadataManager.getCachedMetadata(for: itemID), "ItemMetadata not found in DB")
		XCTAssertEqual("Attachments", cachedItemMetadata.name)
	}

	/// The middleware is also installed for uploads and reparents, which never opt out and must keep renaming.
	func testTaskWithoutOwnDispositionStillRenames() async throws {
		let originalCloudPath = CloudPath("/foo.txt")
		var executedCloudPaths = [CloudPath]()
		let workflowMock = WorkflowMiddlewareMock<Void> { task in
			executedCloudPaths.append(task.cloudPath)
			if task.cloudPath == originalCloudPath {
				throw CloudProviderError.itemAlreadyExists
			}
		}
		let itemMetadata = ItemMetadata(name: "foo.txt", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, isPlaceholderItem: true)
		try itemMetadataManager.cacheMetadata(itemMetadata)
		let taskRecord = try UploadTaskRecord(correspondingItem: XCTUnwrap(itemMetadata.id), lastFailedUploadDate: nil, uploadErrorCode: nil, uploadErrorDomain: nil, uploadStartedAt: Date())
		let task = UploadTask(taskRecord: taskRecord, itemMetadata: itemMetadata, cloudPath: originalCloudPath, onURLSessionTaskCreation: nil)
		XCTAssertEqual(.renameAndRetry, task.onlineCollisionDisposition)
		middleware.setNext(AnyWorkflowMiddleware(workflowMock))
		try await middleware.execute(task: task)
		XCTAssertEqual(2, executedCloudPaths.count, "Did not retry under a collision-free path")
		XCTAssertNotEqual(originalCloudPath, executedCloudPaths.last)
	}

	func testRetryKeepsTheTaskCreationHook() async throws {
		let originalCloudPath = CloudPath("/foo.txt")
		var retriedTask: UploadTask?
		let workflowMock = WorkflowMiddlewareMock<Void> { task in
			if task.cloudPath == originalCloudPath {
				throw CloudProviderError.itemAlreadyExists
			}
			retriedTask = task as? UploadTask
		}
		let itemMetadata = ItemMetadata(name: "foo.txt", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, isPlaceholderItem: true)
		try itemMetadataManager.cacheMetadata(itemMetadata)
		let hookInvoked = XCTestExpectation(description: "Task creation hook invoked")
		let taskRecord = try UploadTaskRecord(correspondingItem: XCTUnwrap(itemMetadata.id), lastFailedUploadDate: nil, uploadErrorCode: nil, uploadErrorDomain: nil, uploadStartedAt: Date())
		let task = UploadTask(taskRecord: taskRecord, itemMetadata: itemMetadata, cloudPath: originalCloudPath, onURLSessionTaskCreation: { _ in
			hookInvoked.fulfill()
		})
		middleware.setNext(AnyWorkflowMiddleware(workflowMock))
		try await middleware.execute(task: task)
		let retriedHook = try XCTUnwrap(retriedTask?.onURLSessionTaskCreation, "Did not retry with the task creation hook")
		try await retriedHook(URLSession.shared.uploadTask(with: URLRequest(url: XCTUnwrap(URL(string: "https://example.com/"))), from: Data()))
		await fulfillment(of: [hookInvoked], timeout: 1.0)
	}

	func testNoRetryForDifferentError() async throws {
		let workflowMock = WorkflowMiddlewareMock<Void> { _ in
			throw CloudProviderError.itemNotFound
		}
		let itemMetadata = ItemMetadata(name: "foo.txt", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, isPlaceholderItem: true)
		try itemMetadataManager.cacheMetadata(itemMetadata)
		middleware.setNext(AnyWorkflowMiddleware(workflowMock))
		let sampleCloudPath = CloudPath("/foo.txt")
		await XCTAssertThrowsAsyncError(try await middleware.execute(task: FolderCreationTask(itemMetadata: itemMetadata, cloudPath: sampleCloudPath))) { error in
			guard case CloudProviderError.itemNotFound = error else {
				XCTFail("Workflow failed with wrong error: \(error)")
				return
			}
		}
		let itemID = try XCTUnwrap(itemMetadata.id)
		let cachedItemMetadata = try XCTUnwrap(itemMetadataManager.getCachedMetadata(for: itemID), "ItemMetadata not found in DB")

		// Check that the item metadata properties have not changed.
		XCTAssertEqual("foo.txt", cachedItemMetadata.name)
		XCTAssertEqual(CloudItemType.file, cachedItemMetadata.type)
		XCTAssertNil(cachedItemMetadata.size)
		XCTAssertEqual(NSFileProviderItemIdentifier.rootContainerDatabaseValue, cachedItemMetadata.parentID)
		XCTAssertEqual(ItemStatus.isUploading, cachedItemMetadata.statusCode)
		XCTAssertTrue(cachedItemMetadata.isPlaceholderItem)
	}
}
