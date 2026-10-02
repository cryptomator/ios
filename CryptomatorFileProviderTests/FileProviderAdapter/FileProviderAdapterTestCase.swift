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
import Promises
import XCTest
@testable import CryptomatorCommonCore
@testable import CryptomatorFileProvider

class FileProviderAdapterTestCase: CloudTaskExecutorTestCase {
	let fileCoordinator = NSFileCoordinator()
	var adapter: FileProviderAdapter!
	var localURLProviderMock: LocalURLProviderMock!
	var fullVersionCheckerMock: FullVersionCheckerMock!
	var fileProviderItemUpdateDelegateMock: FileProviderItemUpdateDelegateMock!
	var taskRegistratorMock: SessionTaskRegistratorMock!

	override func setUpWithError() throws {
		try super.setUpWithError()
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
			                    scheduler: WorkflowScheduler(maxParallelUploads: 1, maxParallelDownloads: 1),
			                    provider: cloudProviderMock,
			                    coordinator: fileCoordinator,
			                    notificator: fileProviderItemUpdateDelegateMock,
			                    localURLProvider: localURLProviderMock,
			                    taskRegistrator: taskRegistratorMock)
		}
		uploadTaskManagerMock.createNewTaskRecordForClosure = {
			return UploadTaskRecord(correspondingItem: $0.id!, lastFailedUploadDate: nil, uploadErrorCode: nil, uploadErrorDomain: nil, uploadStartedAt: Date())
		}
		uploadTaskManagerMock.getTaskForOnURLSessionTaskCreationClosure = {
			let id = $0.correspondingItem
			let metadata = try XCTUnwrap(self.metadataManagerMock.cachedMetadata[id])
			let cloudPath = try self.metadataManagerMock.getCloudPath(for: id)
			return UploadTask(taskRecord: $0, itemMetadata: metadata, cloudPath: cloudPath, onURLSessionTaskCreation: $1)
		}
	}

	class WorkflowSchedulerMock: WorkflowScheduler {
		init() {
			super.init(maxParallelUploads: 1, maxParallelDownloads: 1)
		}

		override func schedule<T>(_ workflow: Workflow<T>) -> Promise<T> {
			return Promise(CloudTaskTestError.correctPassthrough)
		}
	}

	class CloudProviderGraphMock: CloudProvider {
		var virtualCloudFileSystem = CloudFileGraphHandler()
		/// Fails a single node without failing its siblings.
		var failureByCloudPath = [CloudPath: Error]()

		func fetchItemMetadata(at cloudPath: CloudPath) -> Promise<CloudItemMetadata> {
			guard let metadata = virtualCloudFileSystem.getItem(at: cloudPath)?.metadata else {
				return Promise(CloudProviderError.itemNotFound)
			}
			return Promise(metadata)
		}

		func fetchItemList(forFolderAt cloudPath: CloudPath, withPageToken pageToken: String?) -> Promise<CloudItemList> {
			return Promise(MockError.notMocked)
		}

		func downloadFile(from cloudPath: CloudPath, to localURL: URL, onTaskCreation: ((URLSessionDownloadTask?) -> Void)?) -> Promise<Void> {
			return Promise(MockError.notMocked)
		}

		func uploadFile(from localURL: URL, to cloudPath: CloudPath, replaceExisting: Bool, onTaskCreation: ((URLSessionUploadTask?) -> Void)?) -> Promise<CloudItemMetadata> {
			if let error = failureByCloudPath[cloudPath] {
				return Promise(error)
			}
			return Promise(()).delay(1.0).then { _ -> Promise<CloudItemMetadata> in
				do {
					let data = try Data(contentsOf: localURL)
					let metadata = CloudItemMetadata(name: cloudPath.lastPathComponent, cloudPath: cloudPath, itemType: .file, lastModifiedDate: nil, size: data.count)
					try self.virtualCloudFileSystem.createItem(at: cloudPath, metadata: metadata)
					return Promise(metadata)
				} catch {
					return Promise(error)
				}
			}
		}

		func createFolder(at cloudPath: CloudPath) -> Promise<Void> {
			if let error = failureByCloudPath[cloudPath] {
				return Promise(error)
			}
			let metadata = CloudItemMetadata(name: cloudPath.lastPathComponent, cloudPath: cloudPath, itemType: .folder, lastModifiedDate: nil, size: nil)
			return Promise(()).delay(0.5).then { _ -> Promise<Void> in
				do {
					try self.virtualCloudFileSystem.createItem(at: cloudPath, metadata: metadata)
				} catch {
					return Promise(error)
				}
				return Promise(())
			}
		}

		func deleteFile(at cloudPath: CloudPath) -> Promise<Void> {
			return Promise(MockError.notMocked)
		}

		func deleteFolder(at cloudPath: CloudPath) -> Promise<Void> {
			return Promise(MockError.notMocked)
		}

		func moveFile(from sourceCloudPath: CloudPath, to targetCloudPath: CloudPath) -> Promise<Void> {
			return Promise(MockError.notMocked)
		}

		func moveFolder(from sourceCloudPath: CloudPath, to targetCloudPath: CloudPath) -> Promise<Void> {
			return Promise(MockError.notMocked)
		}
	}

	class GraphWorkflowSchedulerMock: WorkflowScheduler {
		let dispatchGroup = DispatchGroup()
		/// Off for tests that inject a failure.
		var failsTestOnRejection = true

		override func schedule<T>(_ workflow: Workflow<T>) -> Promise<T> {
			dispatchGroup.enter()
			return super.schedule(workflow).catch { error in
				if self.failsTestOnRejection {
					XCTFail("failed with error: \(error)")
				}
			}.always {
				// Left in `always`, so an expected rejection settles the group instead of hanging the wait.
				self.dispatchGroup.leave()
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

	func createGraphScheduler() -> GraphWorkflowSchedulerMock {
		return GraphWorkflowSchedulerMock(maxParallelUploads: 2, maxParallelDownloads: 2)
	}

	/// Unlike `createFullyMockedAdapter`, its workflows really run against the virtual cloud.
	func createPackageAdapter(provider: CloudProviderGraphMock, scheduler: GraphWorkflowSchedulerMock) -> FileProviderAdapter {
		return withDependencies {
			$0.fullVersionChecker = fullVersionCheckerMock
		} operation: {
			FileProviderAdapter(domainIdentifier: .test, uploadTaskManager: uploadTaskManagerMock, cachedFileManager: cachedFileManagerMock, itemMetadataManager: metadataManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, itemEnumerationTaskManager: itemEnumerationTaskManagerMock, downloadTaskManager: downloadTaskManagerMock, scheduler: scheduler, provider: provider, coordinator: fileCoordinator, notificator: fileProviderItemUpdateDelegateMock, localURLProvider: localURLProviderMock, taskRegistrator: taskRegistratorMock)
		}
	}

	func createFullyMockedAdapter() -> FileProviderAdapter {
		return withDependencies {
			$0.fullVersionChecker = fullVersionCheckerMock
		} operation: {
			FileProviderAdapter(domainIdentifier: .test, uploadTaskManager: uploadTaskManagerMock, cachedFileManager: cachedFileManagerMock, itemMetadataManager: metadataManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, itemEnumerationTaskManager: itemEnumerationTaskManagerMock, downloadTaskManager: downloadTaskManagerMock, scheduler: WorkflowSchedulerMock(), provider: cloudProviderMock, coordinator: fileCoordinator, localURLProvider: localURLProviderMock, taskRegistrator: taskRegistratorMock)
		}
	}
}

extension UploadTaskRecord: Equatable {
	public static func == (lhs: UploadTaskRecord, rhs: UploadTaskRecord) -> Bool {
		lhs.correspondingItem == rhs.correspondingItem && lhs.lastFailedUploadDate == rhs.lastFailedUploadDate && lhs.uploadErrorCode == rhs.uploadErrorCode && lhs.uploadErrorDomain == rhs.uploadErrorDomain && lhs.uploadStartedAt == rhs.uploadStartedAt
	}
}

extension NSFileProviderDomainIdentifier {
	static let test = NSFileProviderDomainIdentifier("Test")
}
