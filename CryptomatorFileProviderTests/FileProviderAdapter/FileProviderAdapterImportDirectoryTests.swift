//
//  FileProviderAdapterImportDirectoryTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 21.03.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import XCTest
@testable import CryptomatorFileProvider
@testable import Promises

class FileProviderAdapterImportDirectoryTests: FileProviderAdapterTestCase {
	private lazy var localFileURL = tmpDirectory.appendingPathComponent("test.txt")

	override func setUpWithError() throws {
		try super.setUpWithError()
		let fileContent = "Content"
		try fileContent.write(to: localFileURL, atomically: true, encoding: .utf8)
	}

	func testImportDirectory() throws {
		localURLProviderMock.itemIdentifierDirectoryURLForItemWithPersistentIdentifierClosure = {
			return self.tmpDirectory.appendingPathComponent($0.rawValue)
		}
		metadataManagerMock.cachedMetadata[1] = ItemMetadata(item: .init(name: "/", cloudPath: CloudPath("/"), itemType: .folder, lastModifiedDate: nil, size: nil), withParentID: 1)
		let provider = CloudProviderGraphMock()
		let scheduler = WorkflowSchedulerMock(maxParallelUploads: 2, maxParallelDownloads: 2)
		let adapter = FileProviderAdapter(domainIdentifier: .test, uploadTaskManager: uploadTaskManagerMock, cachedFileManager: cachedFileManagerMock, itemMetadataManager: metadataManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, itemEnumerationTaskManager: itemEnumerationTaskManagerMock, downloadTaskManager: downloadTaskManagerMock, scheduler: scheduler, provider: provider, coordinator: fileCoordinator, localURLProvider: localURLProviderMock, taskRegistrator: taskRegistratorMock)
		var parentIdentifier: NSFileProviderItemIdentifier = .rootContainer

		for _ in 0 ..< 5 {
			parentIdentifier = try createDirectoryWithFiles(adapter: adapter, parentIdentifier: parentIdentifier).itemIdentifier
		}
		let expectation = XCTestExpectation()
		DispatchQueue.global().async {
			XCTAssertEqual(.success, scheduler.dispatchGroup.wait(timeout: .now() + 9))
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 10)
	}

	private func createDirectoryWithFiles(adapter: FileProviderAdapter, parentIdentifier: NSFileProviderItemIdentifier) throws -> NSFileProviderItem {
		let createDirectoryPromise = adapter.createDirectory(withName: "1", inParentItemIdentifier: parentIdentifier)
		wait(for: createDirectoryPromise, timeout: 1.0)
		let firstDirectoryItem = try XCTUnwrap(createDirectoryPromise.value ?? nil)

		let importDocumentPromise = adapter.importDocument(at: localFileURL, toParentItemIdentifier: firstDirectoryItem.itemIdentifier)
		wait(for: importDocumentPromise, timeout: 1.0)
		return firstDirectoryItem
	}

	class CloudProviderGraphMock: CloudProvider {
		var virtualCloudFileSystem = CloudFileGraphHandler()
		var currentFiles = [String: CloudItemMetadata]()

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

	class WorkflowSchedulerMock: WorkflowScheduler {
		let dispatchGroup = DispatchGroup()

		override func schedule<T>(_ workflow: Workflow<T>) -> Promise<T> {
			dispatchGroup.enter()
			return super.schedule(workflow).then { value -> T in
				self.dispatchGroup.leave()
				return value
			}.catch { error in
				XCTFail("failed with error: \(error)")
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
}

extension FileProviderAdapterType {
	func createDirectory(withName name: String, inParentItemIdentifier parentIdentifier: NSFileProviderItemIdentifier) -> Promise<NSFileProviderItem?> {
		return Promise<NSFileProviderItem?> { fulfill, reject in
			self.createDirectory(withName: name, inParentItemIdentifier: parentIdentifier, completionHandler: { item, error in
				if let error = error {
					reject(error)
				} else {
					fulfill(item)
				}
			})
		}
	}
}
