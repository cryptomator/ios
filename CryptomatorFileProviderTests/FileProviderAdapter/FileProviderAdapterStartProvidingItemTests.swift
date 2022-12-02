//
//  FileProviderAdapterStartProvidingItemTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 08.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Promises
import XCTest
@testable import CryptomatorFileProvider

class FileProviderAdapterStartProvidingItemTests: FileProviderAdapterTestCase {
	private let itemID: Int64 = 2
	private let cloudPath = CloudPath("/File 1")
	private lazy var itemMetadata = ItemMetadata(id: 2, name: "File 1", type: .file, size: 14, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
	private lazy var itemDirectory = tmpDirectory.appendingPathComponent("/\(itemID)")
	private lazy var url = itemDirectory.appendingPathComponent("File 1")

	override func setUpWithError() throws {
		try super.setUpWithError()
		try metadataManagerMock.cacheMetadata(itemMetadata)
		try FileManager.default.createDirectory(at: itemDirectory, withIntermediateDirectories: false)
	}

	func testStartProvidingItemNoLocalVersion() throws {
		let expectation = XCTestExpectation()
		XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
		adapter.startProvidingItem(at: url) { [self] error in
			XCTAssertNil(error)
			self.assertNewestVersionDownloaded(localURL: url, cloudPath: cloudPath, itemID: itemID)
			self.assertMetadataUpdated()
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
		assertItemRemovedFromWorkingSet()
	}

	func testStartProvidingItemWithUpToDateLocalVersion() throws {
		simulateExistingLocalFileByDownloadingFile()
		let expectation = XCTestExpectation()
		XCTAssert(FileManager.default.fileExists(atPath: url.path))
		adapter.startProvidingItem(at: url) { [self] error in
			XCTAssertNil(error)
			self.assertNewestVersionDownloaded(localURL: url, cloudPath: cloudPath, itemID: itemID)
			XCTAssertEqual(1, self.metadataManagerMock.updatedMetadata.count, "Unexpected change of cached metadata.")
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
		assertItemRemovedFromWorkingSet()
	}

	func testStartProvidingItemWithOlderLocalVersion() throws {
		simulateExistingLocalFileByDownloadingFile()
		let expectation = XCTestExpectation()

		simulateFileChangeInTheCloud()

		adapter.startProvidingItem(at: url) { [self] error in
			XCTAssertNil(error)
			self.assertNewestVersionDownloaded(localURL: url, cloudPath: cloudPath, itemID: itemID)
			XCTAssertEqual(2, self.metadataManagerMock.updatedMetadata.count)
			XCTAssertEqual(ItemStatus.isUploaded, self.metadataManagerMock.updatedMetadata[0].statusCode)
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
		assertItemRemovedFromWorkingSet()
	}

	func testStartProvidingItemWithConflictingLocalVersion() throws {
		let expectation = XCTestExpectation()
		let rootItemMetadata = ItemMetadata(id: NSFileProviderItemIdentifier.rootContainerDatabaseValue, name: "Home", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/"), isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(rootItemMetadata)

		// Create local folder for conflicting item
		let conflictingItemDirectory = tmpDirectory.appendingPathComponent("3")
		try FileManager.default.createDirectory(at: conflictingItemDirectory, withIntermediateDirectories: false)
		localURLProviderMock.itemIdentifierDirectoryURLForItemWithPersistentIdentifierReturnValue = conflictingItemDirectory

		try "Local changed file content".write(to: url, atomically: true, encoding: .utf8)

		// Simulate a failed upload
		let localCachedFileInfo = LocalCachedFileInfo(lastModifiedDate: nil, correspondingItem: itemID, localLastModifiedDate: Date(timeIntervalSince1970: 0), localURL: url)
		cachedFileManagerMock.cachedLocalFileInfo[itemID] = localCachedFileInfo
		let uploadTaskRecord = UploadTaskRecord(correspondingItem: itemID, lastFailedUploadDate: Date(), uploadErrorCode: NSFileProviderError(.serverUnreachable).errorCode, uploadErrorDomain: NSFileProviderErrorDomain)
		uploadTaskManagerMock.getTaskRecordForClosure = {
			guard self.itemID == $0 else {
				return nil
			}
			return uploadTaskRecord
		}

		simulateFileChangeInTheCloud()

		adapter.startProvidingItem(at: url) { [self] error in
			XCTAssertNil(error)
			assertNewestVersionDownloaded(localURL: url, cloudPath: cloudPath, itemID: itemID)
			XCTAssertEqual(1, uploadTaskManagerMock.createNewTaskRecordForCallsCount)

			guard let localCachedFileInfo = cachedFileManagerMock.cachedLocalFileInfo[3] else {
				XCTFail("localCachedFileInfo is nil")
				return
			}
			XCTAssertEqual(3, localCachedFileInfo.correspondingItem)
			XCTAssert(localCachedFileInfo.localURL.path.hasPrefix(conflictingItemDirectory.path))
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
		assertItemRemovedFromWorkingSet()
		XCTAssertEqual([NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: 3)], localURLProviderMock.itemIdentifierDirectoryURLForItemWithPersistentIdentifierReceivedInvocations)
	}

	func testStartProvidingItemWithTagData() throws {
		simulateExistingLocalFileByDownloadingFile()
		let expectation = XCTestExpectation()

		metadataManagerMock.cachedMetadata[2]?.tagData = Data()
		simulateFileChangeInTheCloud()
		resetFileProviderItemUpdateDelegateMockRemoveItem()

		adapter.startProvidingItem(at: url) { [self] error in
			XCTAssertNil(error)
			self.assertNewestVersionDownloaded(localURL: url, cloudPath: cloudPath, itemID: itemID)
			XCTAssertEqual(2, self.metadataManagerMock.updatedMetadata.count)
			XCTAssertEqual(ItemStatus.isUploaded, self.metadataManagerMock.updatedMetadata[0].statusCode)
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
		XCTAssertFalse(fileProviderItemUpdateDelegateMock.removeItemFromWorkingSetWithCalled)
	}

	func assertNewestVersionDownloaded(localURL: URL, cloudPath: CloudPath, itemID: Int64) {
		XCTAssert(FileManager.default.fileExists(atPath: localURL.path))

		let localContent = try? Data(contentsOf: localURL)
		XCTAssertEqual(cloudProviderMock.files[cloudPath.path], localContent)

		let localCachedFileInfo = cachedFileManagerMock.cachedLocalFileInfo[itemID]
		XCTAssertNotNil(localCachedFileInfo)
		let lastModifiedDate = localCachedFileInfo?.lastModifiedDate
		XCTAssertNotNil(lastModifiedDate)
		XCTAssertEqual(cloudProviderMock.lastModifiedDate[cloudPath.path], lastModifiedDate)
	}

	func assertMetadataUpdated() {
		XCTAssertEqual(1, metadataManagerMock.updatedMetadata.count)
		XCTAssertEqual(ItemStatus.isUploaded, metadataManagerMock.updatedMetadata[0].statusCode)
	}

	private func assertItemRemovedFromWorkingSet() {
		XCTAssertEqual(["\(NSFileProviderDomainIdentifier.test.rawValue):\(itemID)"], fileProviderItemUpdateDelegateMock.removeItemFromWorkingSetWithReceivedInvocations.map { $0.rawValue })
	}

	private func simulateExistingLocalFileByDownloadingFile() {
		let expectation = XCTestExpectation()
		adapter.startProvidingItem(at: url) { [self] error in
			XCTAssertNil(error)
			XCTAssert(FileManager.default.fileExists(atPath: url.path))
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
		assertItemRemovedFromWorkingSet()
		// Reset fileProviderItemUpdateDelegateMock
		resetFileProviderItemUpdateDelegateMockRemoveItem()
	}

	private func resetFileProviderItemUpdateDelegateMockRemoveItem() {
		fileProviderItemUpdateDelegateMock.removeItemFromWorkingSetWithReceivedInvocations = []
		fileProviderItemUpdateDelegateMock.removeItemFromWorkingSetWithCallsCount = 0
		fileProviderItemUpdateDelegateMock.removeItemFromWorkingSetWithReceivedIdentifier = nil
	}

	private func simulateFileChangeInTheCloud() {
		// Simulate an file update in the cloud by enforce an newer lastModifiedDate in the cloud and change the file content in the cloud
		cloudProviderMock.lastModifiedDate[cloudPath.path] = Date(timeIntervalSince1970: 10)
		cloudProviderMock.files[cloudPath.path] = "Updated File 1 content".data(using: .utf8)
	}

	class WorkFlowSchedulerStartProvidingItemMock: WorkflowScheduler {
		init() {
			super.init(maxParallelUploads: 1, maxParallelDownloads: 1)
		}

		override func schedule<T>(_ workflow: Workflow<T>) -> Promise<T> {
			// Ignore UploadTasks to test the conflicting local version DB entries
			if workflow.task is UploadTask {
				return Promise(MockError.notMocked)
			}
			return super.schedule(workflow)
		}
	}
}
