//
//  FileProviderAdapterTestCase.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 04.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Dependencies
import Foundation
import XCTest
@testable import CryptomatorCommonCore
@testable import CryptomatorFileProvider

class FileProviderAdapterTestCase: CloudTaskExecutorTestCase {
	let fileCoordinatorPurposeIdentifier = "FileProviderAdapterTestCase"
	var adapter: FileProviderAdapter!
	var localURLProviderMock: LocalURLProviderMock!
	var fullVersionCheckerMock: FullVersionCheckerMock!
	var fileProviderItemUpdateDelegateMock: FileProviderItemUpdateDelegateMock!
	var taskRegistratorMock: SessionTaskRegistratorMock!

	override func setUp() async throws {
		try await super.setUp()
		localURLProviderMock = LocalURLProviderMock()
		localURLProviderMock.domainIdentifier = .test
		fileProviderItemUpdateDelegateMock = FileProviderItemUpdateDelegateMock()
		fullVersionCheckerMock = FullVersionCheckerMock()
		fullVersionCheckerMock.isFullVersion = true
		taskRegistratorMock = SessionTaskRegistratorMock()
		adapter = withDependencies {
			$0.fullVersionChecker = fullVersionCheckerMock
		} operation: {
			FileProviderAdapter(domainIdentifier: .test,
			                    uploadTaskManager: uploadTaskManagerMock,
			                    cachedFileManager: cachedFileManagerMock,
			                    itemMetadataManager: metadataManagerMock,
			                    reparentTaskManager: reparentTaskManagerMock,
			                    deletionTaskManager: deletionTaskManagerMock,
			                    itemEnumerationTaskManager: itemEnumerationTaskManagerMock,
			                    downloadTaskManager: downloadTaskManagerMock,
			                    scheduler: WorkflowScheduler(),
			                    maxParallelUploads: 1,
			                    maxParallelDownloads: 1,
			                    provider: cloudProviderMock,
			                    fileCoordinatorPurposeIdentifier: fileCoordinatorPurposeIdentifier,
			                    notificator: fileProviderItemUpdateDelegateMock,
			                    localURLProvider: localURLProviderMock,
			                    taskRegistrator: taskRegistratorMock)
		}
		uploadTaskManagerMock.createNewTaskRecordForClosure = {
			return UploadTaskRecord(correspondingItem: $0.id!, lastFailedUploadDate: nil, uploadErrorCode: nil, uploadErrorDomain: nil, uploadStartedAt: Date())
		}
		let metadataManagerMock = metadataManagerMock!
		uploadTaskManagerMock.getTaskForOnURLSessionTaskCreationClosure = { taskRecord, onURLSessionTaskCreation in
			let id = taskRecord.correspondingItem
			let metadata = try XCTUnwrap(metadataManagerMock.cachedMetadata[id])
			let cloudPath = try metadataManagerMock.getCloudPath(for: id)
			return UploadTask(taskRecord: taskRecord, itemMetadata: metadata, cloudPath: cloudPath, onURLSessionTaskCreation: onURLSessionTaskCreation)
		}
	}

	class WorkflowSchedulerMock: WorkflowScheduler {
		override func schedule<T>(_ workflow: Workflow<T>) async throws -> T {
			throw CloudTaskTestError.correctPassthrough
		}
	}

	/// @unchecked Sendable: provider calls touch the graph under `lock`; tests touch it only while no workflow runs
	final class CloudProviderGraphMock: CloudProvider, @unchecked Sendable {
		let virtualCloudFileSystem = CloudFileGraphHandler()
		/// Fails a single node without failing its siblings.
		var failureByCloudPath: [CloudPath: Error] {
			get { lock.withLock { failures } }
			set { lock.withLock { failures = newValue } }
		}

		private var failures = [CloudPath: Error]()
		private let lock = NSLock()

		private func getItem(at cloudPath: CloudPath) -> CloudFileGraphNode? {
			return lock.withLock { virtualCloudFileSystem.getItem(at: cloudPath) }
		}

		private func createItem(at cloudPath: CloudPath, metadata: CloudItemMetadata) throws {
			try lock.withLock { try virtualCloudFileSystem.createItem(at: cloudPath, metadata: metadata) }
		}

		@concurrent
		func fetchItemMetadata(at cloudPath: CloudPath) async throws -> CloudItemMetadata {
			guard let metadata = getItem(at: cloudPath)?.metadata else {
				throw CloudProviderError.itemNotFound
			}
			return metadata
		}

		@concurrent
		func fetchItemList(forFolderAt cloudPath: CloudPath, withPageToken pageToken: String?) async throws -> CloudItemList {
			throw MockError.notMocked
		}

		@concurrent
		func downloadFile(from cloudPath: CloudPath, to localURL: URL, progress: Progress?, onTaskCreation: URLSessionDownloadTaskCreationHook?) async throws -> CloudItemMetadata {
			throw MockError.notMocked
		}

		@concurrent
		func uploadFile(from localURL: URL, to cloudPath: CloudPath, replaceExisting: Bool, progress: Progress?, onTaskCreation: URLSessionUploadTaskCreationHook?) async throws -> CloudItemMetadata {
			if let error = failureByCloudPath[cloudPath] {
				throw error
			}
			try await Task.sleep(for: .seconds(1))
			let data = try Data(contentsOf: localURL)
			let metadata = CloudItemMetadata(name: cloudPath.lastPathComponent, cloudPath: cloudPath, itemType: .file, lastModifiedDate: nil, size: data.count)
			try createItem(at: cloudPath, metadata: metadata)
			return metadata
		}

		@concurrent
		func createFolder(at cloudPath: CloudPath) async throws {
			if let error = failureByCloudPath[cloudPath] {
				throw error
			}
			let metadata = CloudItemMetadata(name: cloudPath.lastPathComponent, cloudPath: cloudPath, itemType: .folder, lastModifiedDate: nil, size: nil)
			try await Task.sleep(for: .seconds(0.5))
			try createItem(at: cloudPath, metadata: metadata)
		}

		@concurrent
		func deleteFile(at cloudPath: CloudPath) async throws {
			throw MockError.notMocked
		}

		@concurrent
		func deleteFolder(at cloudPath: CloudPath) async throws {
			throw MockError.notMocked
		}

		@concurrent
		func moveFile(from sourceCloudPath: CloudPath, to targetCloudPath: CloudPath) async throws {
			throw MockError.notMocked
		}

		@concurrent
		func moveFolder(from sourceCloudPath: CloudPath, to targetCloudPath: CloudPath) async throws {
			throw MockError.notMocked
		}
	}

	class GraphWorkflowSchedulerMock: WorkflowScheduler {
		/// Off for tests whose injected failure makes a scheduled workflow throw.
		var failsTestOnRejection = true

		override func schedule<T>(_ workflow: Workflow<T>) async throws -> T {
			do {
				return try await super.schedule(workflow)
			} catch {
				if failsTestOnRejection {
					XCTFail("failed with error: \(error)")
				}
				throw error
			}
		}
	}

	class CloudFileGraphNode {
		var children = [CloudFileGraphNode]()
		let metadata: CloudItemMetadata

		init(metadata: CloudItemMetadata) {
			self.metadata = metadata
		}
	}

	struct CloudFileGraphHandler {
		let root = CloudFileGraphNode(metadata: .init(name: "/", cloudPath: CloudPath("/"), itemType: .folder, lastModifiedDate: nil, size: nil))

		func createItem(at path: CloudPath, metadata: CloudItemMetadata) throws {
			let partialPaths = path.getPartialCloudPaths().dropFirst().dropLast()
			var currentParentNode = root

			for partialPath in partialPaths {
				guard let currentNode = currentParentNode.children.first(where: { $0.metadata.cloudPath == partialPath }) else {
					throw CloudProviderError.parentFolderDoesNotExist
				}
				currentParentNode = currentNode
			}
			if currentParentNode.children.contains(where: { $0.metadata.cloudPath == path }) {
				throw CloudProviderError.itemAlreadyExists
			}
			currentParentNode.children.append(.init(metadata: metadata))
		}

		func getItem(at path: CloudPath) -> CloudFileGraphNode? {
			let partialPaths = path.getPartialCloudPaths().dropFirst()
			var currentParentNode = root

			for partialPath in partialPaths {
				guard let currentNode = currentParentNode.children.first(where: { $0.metadata.cloudPath == partialPath }) else {
					return nil
				}
				currentParentNode = currentNode
			}
			return currentParentNode
		}
	}

	/// Unlike `createFullyMockedAdapter`, its workflows really run against the virtual cloud.
	func createPackageAdapter(provider: CloudProviderGraphMock, scheduler: GraphWorkflowSchedulerMock) -> FileProviderAdapter {
		return withDependencies {
			$0.fullVersionChecker = fullVersionCheckerMock
		} operation: {
			FileProviderAdapter(domainIdentifier: .test, uploadTaskManager: uploadTaskManagerMock, cachedFileManager: cachedFileManagerMock, itemMetadataManager: metadataManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, itemEnumerationTaskManager: itemEnumerationTaskManagerMock, downloadTaskManager: downloadTaskManagerMock, scheduler: scheduler, maxParallelUploads: 2, maxParallelDownloads: 2, provider: provider, fileCoordinatorPurposeIdentifier: fileCoordinatorPurposeIdentifier, notificator: fileProviderItemUpdateDelegateMock, localURLProvider: localURLProviderMock, taskRegistrator: taskRegistratorMock)
		}
	}

	func createFullyMockedAdapter() -> FileProviderAdapter {
		return withDependencies {
			$0.fullVersionChecker = fullVersionCheckerMock
		} operation: {
			FileProviderAdapter(domainIdentifier: .test, uploadTaskManager: uploadTaskManagerMock, cachedFileManager: cachedFileManagerMock, itemMetadataManager: metadataManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, itemEnumerationTaskManager: itemEnumerationTaskManagerMock, downloadTaskManager: downloadTaskManagerMock, scheduler: WorkflowSchedulerMock(), maxParallelUploads: 1, maxParallelDownloads: 1, provider: cloudProviderMock, fileCoordinatorPurposeIdentifier: fileCoordinatorPurposeIdentifier, localURLProvider: localURLProviderMock, taskRegistrator: taskRegistratorMock)
		}
	}

	/// Unlike `createFullyMockedAdapter`, its workflows really run against the passed provider.
	func createAdapter(provider: CloudProvider) -> FileProviderAdapter {
		return withDependencies {
			$0.fullVersionChecker = fullVersionCheckerMock
		} operation: {
			FileProviderAdapter(domainIdentifier: .test, uploadTaskManager: uploadTaskManagerMock, cachedFileManager: cachedFileManagerMock, itemMetadataManager: metadataManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, itemEnumerationTaskManager: itemEnumerationTaskManagerMock, downloadTaskManager: downloadTaskManagerMock, scheduler: WorkflowScheduler(), maxParallelUploads: 1, maxParallelDownloads: 1, provider: provider, fileCoordinatorPurposeIdentifier: fileCoordinatorPurposeIdentifier, localURLProvider: localURLProviderMock, taskRegistrator: taskRegistratorMock)
		}
	}
}

extension FileProviderAdapterType {
	func createDirectory(withName name: String, inParentItemIdentifier parentIdentifier: NSFileProviderItemIdentifier) async throws -> FileProviderItem? {
		return try await withCheckedThrowingContinuation { continuation in
			createDirectory(withName: name, inParentItemIdentifier: parentIdentifier) { item, error in
				if let error = error {
					continuation.resume(throwing: error)
				} else {
					continuation.resume(returning: item as? FileProviderItem)
				}
			}
		}
	}

	func renameItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toName itemName: String) async throws -> FileProviderItem? {
		return try await withCheckedThrowingContinuation { continuation in
			renameItem(withIdentifier: itemIdentifier, toName: itemName) { item, error in
				if let error = error {
					continuation.resume(throwing: error)
				} else {
					continuation.resume(returning: item as? FileProviderItem)
				}
			}
		}
	}

	func reparentItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier, toParentItemWithIdentifier parentItemIdentifier: NSFileProviderItemIdentifier) async throws -> FileProviderItem? {
		return try await withCheckedThrowingContinuation { continuation in
			reparentItem(withIdentifier: itemIdentifier, toParentItemWithIdentifier: parentItemIdentifier, newName: nil) { item, error in
				if let error = error {
					continuation.resume(throwing: error)
				} else {
					continuation.resume(returning: item as? FileProviderItem)
				}
			}
		}
	}

	func deleteItem(withIdentifier itemIdentifier: NSFileProviderItemIdentifier) async throws {
		try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
			deleteItem(withIdentifier: itemIdentifier) { error in
				if let error = error {
					continuation.resume(throwing: error)
				} else {
					continuation.resume()
				}
			}
		}
	}

	func startProvidingItem(at url: URL) async throws {
		try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
			startProvidingItem(at: url) { error in
				if let error = error {
					continuation.resume(throwing: error)
				} else {
					continuation.resume()
				}
			}
		}
	}
}

extension UploadTaskRecord: Equatable {
	public static func == (lhs: UploadTaskRecord, rhs: UploadTaskRecord) -> Bool {
		lhs.correspondingItem == rhs.correspondingItem && lhs.lastFailedUploadDate == rhs.lastFailedUploadDate && lhs.uploadErrorCode == rhs.uploadErrorCode && lhs.uploadErrorDomain == rhs.uploadErrorDomain && lhs.uploadStartedAt == rhs.uploadStartedAt
	}
}

private extension CloudPath {
	/// `/AAA/BBB/example.txt` yields `["/", "/AAA/", "/AAA/BBB/", "/AAA/BBB/example.txt"]`.
	func getPartialCloudPaths() -> [CloudPath] {
		var partialCloudPaths = [self]
		var cloudPath = self
		while cloudPath.pathComponents.count > 1 {
			cloudPath = cloudPath.deletingLastPathComponent()
			partialCloudPaths.append(cloudPath)
		}
		return partialCloudPaths.reversed()
	}
}

extension NSFileProviderDomainIdentifier {
	static let test = NSFileProviderDomainIdentifier("Test")
}
