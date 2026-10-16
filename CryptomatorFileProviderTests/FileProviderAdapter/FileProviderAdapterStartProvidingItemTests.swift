//
//  FileProviderAdapterStartProvidingItemTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 08.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import XCTest
@testable import CryptomatorFileProvider

class FileProviderAdapterStartProvidingItemTests: FileProviderAdapterTestCase {
	private let itemID: Int64 = 2
	private let cloudPath = CloudPath("/File 1")
	private lazy var itemMetadata = ItemMetadata(id: 2, name: "File 1", type: .file, size: 14, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
	private lazy var itemDirectory = tmpDirectory.appendingPathComponent("/\(itemID)")
	private lazy var url = itemDirectory.appendingPathComponent("File 1")

	override func setUp() async throws {
		try await super.setUp()
		try metadataManagerMock.cacheMetadata(itemMetadata)
		try FileManager.default.createDirectory(at: itemDirectory, withIntermediateDirectories: false)
	}

	func testStartProvidingItemNoLocalVersion() async throws {
		XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
		try await adapter.startProvidingItem(at: url)
		assertNewestVersionDownloaded(localURL: url, cloudPath: cloudPath, itemID: itemID)
		assertMetadataUpdated()
		assertItemRemovedFromWorkingSet()
	}

	func testStartProvidingItemWithUpToDateLocalVersion() async throws {
		try await simulateExistingLocalFileByDownloadingFile()
		XCTAssert(FileManager.default.fileExists(atPath: url.path))
		try await adapter.startProvidingItem(at: url)
		assertNewestVersionDownloaded(localURL: url, cloudPath: cloudPath, itemID: itemID)
		XCTAssertEqual(1, metadataManagerMock.updatedMetadata.count, "Unexpected change of cached metadata.")
		assertItemRemovedFromWorkingSet()
	}

	func testStartProvidingItemWithOlderLocalVersion() async throws {
		try await simulateExistingLocalFileByDownloadingFile()

		simulateFileChangeInTheCloud()

		try await adapter.startProvidingItem(at: url)
		assertNewestVersionDownloaded(localURL: url, cloudPath: cloudPath, itemID: itemID)
		XCTAssertEqual(2, metadataManagerMock.updatedMetadata.count)
		XCTAssertEqual(ItemStatus.isUploaded, metadataManagerMock.updatedMetadata[0].statusCode)
		assertItemRemovedFromWorkingSet()
	}

	func testStartProvidingItemWithConflictingLocalVersion() async throws {
		let rootItemMetadata = ItemMetadata(id: NSFileProviderItemIdentifier.rootContainerDatabaseValue, name: "Home", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(rootItemMetadata)

		// Create local folder for conflicting item
		let conflictingItemDirectory = tmpDirectory.appendingPathComponent("3")
		try FileManager.default.createDirectory(at: conflictingItemDirectory, withIntermediateDirectories: false)
		localURLProviderMock.itemIdentifierDirectoryURLForItemWithPersistentIdentifierReturnValue = conflictingItemDirectory

		try "Local changed file content".write(to: url, atomically: true, encoding: .utf8)

		// Simulate a failed upload
		let localCachedFileInfo = LocalCachedFileInfo(lastModifiedDate: nil, correspondingItem: itemID, localLastModifiedDate: Date(timeIntervalSince1970: 0), localURL: url)
		cachedFileManagerMock.cachedLocalFileInfo[itemID] = localCachedFileInfo
		let uploadTaskRecord = UploadTaskRecord(correspondingItem: itemID, lastFailedUploadDate: Date(), uploadErrorCode: NSFileProviderError(.serverUnreachable).errorCode, uploadErrorDomain: NSFileProviderErrorDomain, uploadStartedAt: nil)
		let failedUploadItemID = itemID
		uploadTaskManagerMock.getTaskRecordForClosure = {
			guard failedUploadItemID == $0 else {
				return nil
			}
			return uploadTaskRecord
		}

		simulateFileChangeInTheCloud()

		try await adapter.startProvidingItem(at: url)
		assertNewestVersionDownloaded(localURL: url, cloudPath: cloudPath, itemID: itemID)
		XCTAssertEqual(1, uploadTaskManagerMock.createNewTaskRecordForCallsCount)

		let conflictingLocalCachedFileInfo = try XCTUnwrap(cachedFileManagerMock.cachedLocalFileInfo[3])
		XCTAssertEqual(3, conflictingLocalCachedFileInfo.correspondingItem)
		XCTAssert(conflictingLocalCachedFileInfo.localURL.path.hasPrefix(conflictingItemDirectory.path))
		assertItemRemovedFromWorkingSet()
		XCTAssertEqual([NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: 3)], localURLProviderMock.itemIdentifierDirectoryURLForItemWithPersistentIdentifierReceivedInvocations)
		await adapter.awaitWorkflows()
	}

	func testStartProvidingItemWithTagData() async throws {
		try await simulateExistingLocalFileByDownloadingFile()

		metadataManagerMock.cachedMetadata[2]?.tagData = Data()
		simulateFileChangeInTheCloud()
		resetFileProviderItemUpdateDelegateMockRemoveItem()

		try await adapter.startProvidingItem(at: url)
		assertNewestVersionDownloaded(localURL: url, cloudPath: cloudPath, itemID: itemID)
		XCTAssertEqual(2, metadataManagerMock.updatedMetadata.count)
		XCTAssertEqual(ItemStatus.isUploaded, metadataManagerMock.updatedMetadata[0].statusCode)
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

	private func simulateExistingLocalFileByDownloadingFile() async throws {
		try await adapter.startProvidingItem(at: url)
		XCTAssert(FileManager.default.fileExists(atPath: url.path))
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
		cloudProviderMock.files[cloudPath.path] = Data("Updated File 1 content".utf8)
	}

	// MARK: - localFileIsCurrent Offline Fallback

	func testLocalFileIsCurrentReturnsTrueWhenOffline() async throws {
		cloudProviderMock.everyOperationShouldFailWithError = CloudProviderError.noInternetConnection
		let identifier = NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: itemID)
		let isCurrent = try await adapter.localFileIsCurrent(with: identifier)
		XCTAssertTrue(isCurrent)
	}

	func testLocalFileIsCurrentPropagatesNonConnectivityError() async {
		cloudProviderMock.everyOperationShouldFailWithError = CloudProviderError.unauthorized
		let identifier = NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: itemID)
		await XCTAssertThrowsAsyncError(try await adapter.localFileIsCurrent(with: identifier)) { error in
			XCTAssertEqual(NSFileProviderError(.notAuthenticated) as NSError, error as NSError)
		}
	}

	// MARK: - Helpers

	class WorkFlowSchedulerStartProvidingItemMock: WorkflowScheduler {
		override func schedule<T>(_ workflow: Workflow<T>) async throws -> T {
			// Ignore UploadTasks to test the conflicting local version DB entries
			if workflow.task is UploadTask {
				throw MockError.notMocked
			}
			return try await super.schedule(workflow)
		}
	}
}
