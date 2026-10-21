//
//  UploadTaskExecutorTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 26.05.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import XCTest
@testable import CryptomatorFileProvider

class UploadTaskExecutorTests: CloudTaskExecutorTestCase {
	func testUploadFile() async throws {
		let itemID: Int64 = 2
		let localURL = tmpDirectory.appendingPathComponent("FileToBeUploaded", isDirectory: false)
		try "TestContent".write(to: localURL, atomically: true, encoding: .utf8)
		let cloudPath = CloudPath("/FileToBeUploaded")
		let progressManagerMock = ProgressManagerMock()
		let itemMetadata = ItemMetadata(id: itemID, name: "FileToBeUploaded", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, isPlaceholderItem: true, isCandidateForCacheCleanup: false)
		cachedFileManagerMock.cachedLocalFileInfo[itemID] = LocalCachedFileInfo(lastModifiedDate: nil, correspondingItem: itemID, localLastModifiedDate: Date(), localURL: localURL)

		let uploadTaskExecutor = createTaskExecutor(provider: cloudProviderMock, progressManager: progressManagerMock)

		let mockedCloudDate = Date(timeIntervalSinceReferenceDate: 0)
		cloudProviderMock.lastModifiedDate[cloudPath.path] = mockedCloudDate
		let uploadTaskRecord = UploadTaskRecord(correspondingItem: itemID, lastFailedUploadDate: nil, uploadErrorCode: nil, uploadErrorDomain: nil, uploadStartedAt: nil)
		let uploadTask = UploadTask(taskRecord: uploadTaskRecord, itemMetadata: itemMetadata, cloudPath: cloudPath, onURLSessionTaskCreation: nil)
		_ = try await uploadTaskExecutor.execute(task: uploadTask)
		XCTAssertEqual(Data("TestContent".utf8), cloudProviderMock.createdFiles["/FileToBeUploaded"])

		XCTAssertEqual(1, metadataManagerMock.updatedMetadata.count)
		let updatedItemMetadata = metadataManagerMock.updatedMetadata[0]
		XCTAssertEqual(ItemStatus.isUploaded, updatedItemMetadata.statusCode)
		XCTAssertFalse(updatedItemMetadata.isPlaceholderItem)

		let cachedFileInfo = cachedFileManagerMock.cachedLocalFileInfo[itemID]
		let lastModifiedDate = cachedFileInfo?.lastModifiedDate
		XCTAssertNotNil(lastModifiedDate)
		XCTAssertEqual(cloudProviderMock.lastModifiedDate[cloudPath.path], lastModifiedDate)

		// Verify that the upload task has been removed
		XCTAssertEqual([itemMetadata.id], uploadTaskManagerMock.removeTaskRecordForReceivedInvocations)

		// Verify that the corresponding upload progress has been saved
		XCTAssertEqual(NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: itemID), progressManagerMock.saveProgressForReceivedArguments?.itemIdentifier)
		XCTAssertEqual(1, progressManagerMock.saveProgressForCallsCount)
	}

	func testUploadFileForwardsTaskCreationHookToProvider() async throws {
		let localURL = tmpDirectory.appendingPathComponent("FileToBeUploaded", isDirectory: false)
		try "TestContent".write(to: localURL, atomically: true, encoding: .utf8)
		let cloudPath = CloudPath("/FileToBeUploaded")
		let itemMetadata = ItemMetadata(id: 2, name: "FileToBeUploaded", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, isPlaceholderItem: true, isCandidateForCacheCleanup: false)
		cachedFileManagerMock.cachedLocalFileInfo[2] = LocalCachedFileInfo(lastModifiedDate: nil, correspondingItem: 2, localLastModifiedDate: Date(), localURL: localURL)

		let errorCloudProviderMock = CloudProviderErrorMock()
		errorCloudProviderMock.uploadFileResponse = { _, cloudPath, _ in
			CloudItemMetadata(name: cloudPath.lastPathComponent, cloudPath: cloudPath, itemType: .file, lastModifiedDate: nil, size: 11)
		}

		let uploadTaskExecutor = createTaskExecutor(provider: errorCloudProviderMock)

		let hookInvoked = XCTestExpectation(description: "Task creation hook invoked")
		let uploadTaskRecord = try UploadTaskRecord(correspondingItem: XCTUnwrap(itemMetadata.id), lastFailedUploadDate: nil, uploadErrorCode: nil, uploadErrorDomain: nil, uploadStartedAt: nil)
		let uploadTask = UploadTask(taskRecord: uploadTaskRecord, itemMetadata: itemMetadata, cloudPath: cloudPath, onURLSessionTaskCreation: { _ in
			hookInvoked.fulfill()
		})

		_ = try await uploadTaskExecutor.execute(task: uploadTask)
		let receivedHook = try XCTUnwrap(errorCloudProviderMock.uploadFileReceivedOnTaskCreation)
		try await receivedHook(URLSession.shared.uploadTask(with: URLRequest(url: XCTUnwrap(URL(string: "https://example.com/"))), from: Data()))
		await fulfillment(of: [hookInvoked], timeout: 1.0)
	}

	func testUploadFileFailForMissingLocalCachedFileInfo() async throws {
		let localURL = tmpDirectory.appendingPathComponent("FileToBeUploaded", isDirectory: false)
		try "TestContent".write(to: localURL, atomically: true, encoding: .utf8)
		let cloudPath = CloudPath("/FileToBeUploaded")
		let itemMetadata = ItemMetadata(id: 2, name: "FileToBeUploaded", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, isPlaceholderItem: true, isCandidateForCacheCleanup: false)

		let mockedCloudDate = Date(timeIntervalSinceReferenceDate: 0)
		cloudProviderMock.lastModifiedDate[cloudPath.path] = mockedCloudDate

		let uploadTaskExecutor = createTaskExecutor(provider: cloudProviderMock)

		let uploadTaskRecord = try UploadTaskRecord(correspondingItem: XCTUnwrap(itemMetadata.id), lastFailedUploadDate: nil, uploadErrorCode: nil, uploadErrorDomain: nil, uploadStartedAt: nil)
		let uploadTask = UploadTask(taskRecord: uploadTaskRecord, itemMetadata: itemMetadata, cloudPath: cloudPath, onURLSessionTaskCreation: nil)

		let item = try await uploadTaskExecutor.execute(task: uploadTask)
		try assertUploadErrorReported(by: item, expectedError: NSFileProviderError(.noSuchItem)._nsError, itemMetadata: itemMetadata, localURL: nil)
	}

	func testUploadFileFailForFailingLocalCachedFileInfoLookup() async throws {
		let cloudPath = CloudPath("/FileToBeUploaded")
		let itemMetadata = ItemMetadata(id: 2, name: "FileToBeUploaded", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, isPlaceholderItem: true, isCandidateForCacheCleanup: false)
		cachedFileManagerMock.getLocalCachedFileInfoForThrowableError = CloudTaskTestError.correctPassthrough

		let uploadTaskExecutor = createTaskExecutor(provider: cloudProviderMock)

		let uploadTaskRecord = try UploadTaskRecord(correspondingItem: XCTUnwrap(itemMetadata.id), lastFailedUploadDate: nil, uploadErrorCode: nil, uploadErrorDomain: nil, uploadStartedAt: nil)
		let uploadTask = UploadTask(taskRecord: uploadTaskRecord, itemMetadata: itemMetadata, cloudPath: cloudPath, onURLSessionTaskCreation: nil)

		let item = try await uploadTaskExecutor.execute(task: uploadTask)
		try assertUploadErrorReported(by: item, expectedError: CloudTaskTestError.correctPassthrough as NSError, itemMetadata: itemMetadata, localURL: nil)
	}

	func testUploadFileFailForMissingLocalFile() async throws {
		let localURL = tmpDirectory.appendingPathComponent("MissingFile", isDirectory: false)
		let cloudPath = CloudPath("/MissingFile")
		let itemMetadata = ItemMetadata(id: 2, name: "MissingFile", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, isPlaceholderItem: true, isCandidateForCacheCleanup: false)
		cachedFileManagerMock.cachedLocalFileInfo[2] = LocalCachedFileInfo(lastModifiedDate: nil, correspondingItem: 2, localLastModifiedDate: Date(), localURL: localURL)

		let uploadTaskExecutor = createTaskExecutor(provider: cloudProviderMock)

		let uploadTaskRecord = try UploadTaskRecord(correspondingItem: XCTUnwrap(itemMetadata.id), lastFailedUploadDate: nil, uploadErrorCode: nil, uploadErrorDomain: nil, uploadStartedAt: nil)
		let uploadTask = UploadTask(taskRecord: uploadTaskRecord, itemMetadata: itemMetadata, cloudPath: cloudPath, onURLSessionTaskCreation: nil)

		let item = try await uploadTaskExecutor.execute(task: uploadTask)
		try assertUploadErrorReported(by: item, expectedError: NSFileProviderError(.noSuchItem)._nsError, itemMetadata: itemMetadata, localURL: localURL)
	}

	func testUploadFileFailForUnreadableLocalFile() async throws {
		let directoryURL = tmpDirectory.appendingPathComponent("Unreadable", isDirectory: true)
		try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: false)
		let localURL = directoryURL.appendingPathComponent("FileToBeUploaded", isDirectory: false)
		try "TestContent".write(to: localURL, atomically: true, encoding: .utf8)
		try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: directoryURL.path)
		defer {
			try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directoryURL.path)
		}
		let cloudPath = CloudPath("/FileToBeUploaded")
		let itemMetadata = ItemMetadata(id: 2, name: "FileToBeUploaded", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, isPlaceholderItem: true, isCandidateForCacheCleanup: false)
		cachedFileManagerMock.cachedLocalFileInfo[2] = LocalCachedFileInfo(lastModifiedDate: nil, correspondingItem: 2, localLastModifiedDate: Date(), localURL: localURL)

		let uploadTaskExecutor = createTaskExecutor(provider: cloudProviderMock)

		let uploadTaskRecord = try UploadTaskRecord(correspondingItem: XCTUnwrap(itemMetadata.id), lastFailedUploadDate: nil, uploadErrorCode: nil, uploadErrorDomain: nil, uploadStartedAt: nil)
		let uploadTask = UploadTask(taskRecord: uploadTaskRecord, itemMetadata: itemMetadata, cloudPath: cloudPath, onURLSessionTaskCreation: nil)

		let updatedItem = try await uploadTaskExecutor.execute(task: uploadTask)
		let uploadingError = try XCTUnwrap(updatedItem.uploadingError as NSError?)
		XCTAssertEqual(NSCocoaErrorDomain, uploadingError.domain)
		XCTAssertEqual(CocoaError.fileReadNoPermission.rawValue, uploadingError.code)
	}

	func testUploadFileWithInconsistencyCheck() async throws {
		let localURL = tmpDirectory.appendingPathComponent("FileToBeUploaded", isDirectory: false)
		try "TestContent".write(to: localURL, atomically: true, encoding: .utf8)
		let cloudPath = CloudPath("/FileToBeUploaded")
		let itemMetadata = ItemMetadata(id: 2, name: "FileToBeUploaded", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, isPlaceholderItem: true, isCandidateForCacheCleanup: false)
		cachedFileManagerMock.cachedLocalFileInfo[2] = LocalCachedFileInfo(lastModifiedDate: nil, correspondingItem: 2, localLastModifiedDate: Date(), localURL: localURL)

		let cloudProviderUploadInconsistencyMock = CloudProviderUploadInconsistencyMock()
		let mockedCloudDate = Date(timeIntervalSinceReferenceDate: 0)
		cloudProviderUploadInconsistencyMock.lastModifiedDate[cloudPath.path] = mockedCloudDate

		let uploadTaskExecutor = createTaskExecutor(provider: cloudProviderUploadInconsistencyMock)

		let uploadTaskRecord = try UploadTaskRecord(correspondingItem: XCTUnwrap(itemMetadata.id), lastFailedUploadDate: nil, uploadErrorCode: nil, uploadErrorDomain: nil, uploadStartedAt: nil)
		let uploadTask = UploadTask(taskRecord: uploadTaskRecord, itemMetadata: itemMetadata, cloudPath: cloudPath, onURLSessionTaskCreation: nil)

		let item = try await uploadTaskExecutor.execute(task: uploadTask)
		// Verify that the file has been modified since the upload began.
		XCTAssertNotEqual(Data("TestContent".utf8), cloudProviderUploadInconsistencyMock.createdFiles["/FileToBeUploaded"])

		XCTAssertEqual(1, metadataManagerMock.updatedMetadata.count)
		let updatedItemMetadata = metadataManagerMock.updatedMetadata[0]
		XCTAssertEqual(ItemStatus.isUploaded, updatedItemMetadata.statusCode)
		XCTAssertFalse(updatedItemMetadata.isPlaceholderItem)

		// Verify that there is no longer an entry about the cached file and the ( outdated ) locally cached file has been removed.
		XCTAssertTrue(cachedFileManagerMock.removeCachedFile.contains(2))

		XCTAssertFalse(item.newestVersionLocallyCached)
		XCTAssertNil(item.localURL)
		XCTAssertNil(item.error)

		// Verify that the upload task has been removed
		XCTAssertEqual([itemMetadata.id], uploadTaskManagerMock.removeTaskRecordForReceivedInvocations)
	}

	func testUploadFileFailReportsUploadError() async throws {
		let localURL = tmpDirectory.appendingPathComponent("itemNotFound.txt", isDirectory: false)
		try "".write(to: localURL, atomically: true, encoding: .utf8)
		let cloudPath = CloudPath("/itemNotFound.txt")
		let itemMetadata = ItemMetadata(id: 2, name: "itemNotFound.txt", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, isPlaceholderItem: true, isCandidateForCacheCleanup: false)
		cachedFileManagerMock.cachedLocalFileInfo[2] = LocalCachedFileInfo(lastModifiedDate: nil, correspondingItem: 2, localLastModifiedDate: Date(), localURL: localURL)

		let errorCloudProviderMock = CloudProviderErrorMock()
		errorCloudProviderMock.uploadFileResponse = { _, _, _ in
			throw CloudProviderError.noInternetConnection
		}

		let uploadTaskExecutor = createTaskExecutor(provider: errorCloudProviderMock)

		let uploadTaskRecord = try UploadTaskRecord(correspondingItem: XCTUnwrap(itemMetadata.id), lastFailedUploadDate: nil, uploadErrorCode: nil, uploadErrorDomain: nil, uploadStartedAt: nil)
		let uploadTask = UploadTask(taskRecord: uploadTaskRecord, itemMetadata: itemMetadata, cloudPath: cloudPath, onURLSessionTaskCreation: nil)

		let item = try await uploadTaskExecutor.execute(task: uploadTask)
		try assertUploadErrorReported(by: item, expectedError: NSFileProviderError(.serverUnreachable)._nsError, itemMetadata: itemMetadata, localURL: localURL)
	}

	func testUploadFileCancelledByProviderReportsUploadError() async throws {
		let localURL = tmpDirectory.appendingPathComponent("FileToBeUploaded", isDirectory: false)
		try "TestContent".write(to: localURL, atomically: true, encoding: .utf8)
		let cloudPath = CloudPath("/FileToBeUploaded")
		let itemMetadata = ItemMetadata(id: 2, name: "FileToBeUploaded", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, isPlaceholderItem: true, isCandidateForCacheCleanup: false)
		cachedFileManagerMock.cachedLocalFileInfo[2] = LocalCachedFileInfo(lastModifiedDate: nil, correspondingItem: 2, localLastModifiedDate: Date(), localURL: localURL)

		let errorCloudProviderMock = CloudProviderErrorMock()
		errorCloudProviderMock.uploadFileResponse = { _, _, _ in
			throw CancellationError()
		}

		let uploadTaskExecutor = createTaskExecutor(provider: errorCloudProviderMock)

		let uploadTaskRecord = try UploadTaskRecord(correspondingItem: XCTUnwrap(itemMetadata.id), lastFailedUploadDate: nil, uploadErrorCode: nil, uploadErrorDomain: nil, uploadStartedAt: nil)
		let uploadTask = UploadTask(taskRecord: uploadTaskRecord, itemMetadata: itemMetadata, cloudPath: cloudPath, onURLSessionTaskCreation: nil)

		let item = try await uploadTaskExecutor.execute(task: uploadTask)
		try assertUploadErrorReported(by: item, expectedError: CancellationError() as NSError, itemMetadata: itemMetadata, localURL: localURL)
	}

	private func assertUploadErrorReported(by updatedItem: FileProviderItem, expectedError: NSError, itemMetadata: ItemMetadata, localURL: URL?, file: StaticString = #filePath, line: UInt = #line) throws {
		XCTAssertEqual(expectedError, updatedItem.uploadingError as NSError?, file: file, line: line)
		XCTAssertEqual(ItemStatus.uploadError, updatedItem.metadata.statusCode, file: file, line: line)
		XCTAssertEqual(localURL, updatedItem.localURL, file: file, line: line)
		XCTAssertFalse(uploadTaskManagerMock.removeTaskRecordForCalled, "Unexpected removal of the upload task", file: file, line: line)

		let updatedTaskRecordReceivedArguments = uploadTaskManagerMock.updateTaskRecordWithLastFailedUploadDateUploadErrorCodeUploadErrorDomainReceivedArguments

		XCTAssertEqual(itemMetadata.id, updatedTaskRecordReceivedArguments?.id, file: file, line: line)
		XCTAssertEqual(expectedError.code, updatedTaskRecordReceivedArguments?.uploadErrorCode, file: file, line: line)
		XCTAssertEqual(expectedError.domain, updatedTaskRecordReceivedArguments?.uploadErrorDomain, file: file, line: line)
		XCTAssertEqual([itemMetadata], metadataManagerMock.updatedMetadata, file: file, line: line)
	}

	private func createTaskExecutor(provider: CloudProvider, progressManager: CryptomatorFileProvider.ProgressManager = InMemoryProgressManager.shared) -> UploadTaskExecutor {
		return UploadTaskExecutor(domainIdentifier: .test, provider: provider, cachedFileManager: cachedFileManagerMock, itemMetadataManager: metadataManagerMock, uploadTaskManager: uploadTaskManagerMock, limiter: ConcurrencyLimiter(label: "Test Uploads", maxConcurrentOperations: 1), progressManager: progressManager)
	}

	/// @unchecked Sendable: adds no state to `CustomCloudProviderMock`
	private class CloudProviderUploadInconsistencyMock: CustomCloudProviderMock, @unchecked Sendable {
		@concurrent
		override func uploadFile(from localURL: URL, to cloudPath: CloudPath, replaceExisting: Bool, progress: Progress?, onTaskCreation: URLSessionUploadTaskCreationHook?) async throws -> CloudItemMetadata {
			precondition(localURL.isFileURL)
			precondition(!localURL.hasDirectoryPath)
			var data = try Data(contentsOf: localURL)
			// simulate file change from 3rd party device, leading to inconsistent CloudItemMetadata
			data.append(Data("foo".utf8))
			self[dynamicMember: \.createdFiles][cloudPath.path] = data
			return CloudItemMetadata(name: cloudPath.lastPathComponent, cloudPath: cloudPath, itemType: .file, lastModifiedDate: self[dynamicMember: \.lastModifiedDate][cloudPath.path] ?? nil, size: data.count)
		}
	}
}
