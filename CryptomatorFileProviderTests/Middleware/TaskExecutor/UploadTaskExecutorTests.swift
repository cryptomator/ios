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
@testable import Promises

class UploadTaskExecutorTests: CloudTaskExecutorTestCase {
	func testUploadFile() throws {
		let expectation = XCTestExpectation()
		let itemID: Int64 = 2
		let localURL = tmpDirectory.appendingPathComponent("FileToBeUploaded", isDirectory: false)
		try "TestContent".write(to: localURL, atomically: true, encoding: .utf8)
		let cloudPath = CloudPath("/FileToBeUploaded")
		let progressManagerMock = ProgressManagerMock()
		let itemMetadata = ItemMetadata(id: itemID, name: "FileToBeUploaded", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, isPlaceholderItem: true, isCandidateForCacheCleanup: false)
		cachedFileManagerMock.cachedLocalFileInfo[itemID] = LocalCachedFileInfo(lastModifiedDate: nil, correspondingItem: itemID, localLastModifiedDate: Date(), localURL: localURL)

		let uploadTaskExecutor = UploadTaskExecutor(domainIdentifier: .test, provider: cloudProviderMock, cachedFileManager: cachedFileManagerMock, itemMetadataManager: metadataManagerMock, uploadTaskManager: uploadTaskManagerMock, progressManager: progressManagerMock)

		let mockedCloudDate = Date(timeIntervalSinceReferenceDate: 0)
		cloudProviderMock.lastModifiedDate[cloudPath.path] = mockedCloudDate
		let uploadTaskRecord = UploadTaskRecord(correspondingItem: itemID, lastFailedUploadDate: nil, uploadErrorCode: nil, uploadErrorDomain: nil, uploadStartedAt: nil)
		let uploadTask = UploadTask(taskRecord: uploadTaskRecord, itemMetadata: itemMetadata, cloudPath: cloudPath, onURLSessionTaskCreation: nil)
		uploadTaskExecutor.execute(task: uploadTask).then { _ in
			XCTAssertEqual(Data("TestContent".utf8), self.cloudProviderMock.createdFiles["/FileToBeUploaded"])

			XCTAssertEqual(1, self.metadataManagerMock.updatedMetadata.count)
			let updatedItemMetadata = self.metadataManagerMock.updatedMetadata[0]
			XCTAssertEqual(ItemStatus.isUploaded, updatedItemMetadata.statusCode)
			XCTAssertFalse(updatedItemMetadata.isPlaceholderItem)

			let cachedFileInfo = self.cachedFileManagerMock.cachedLocalFileInfo[itemID]
			let lastModifiedDate = cachedFileInfo?.lastModifiedDate
			XCTAssertNotNil(lastModifiedDate)
			XCTAssertEqual(self.cloudProviderMock.lastModifiedDate[cloudPath.path], lastModifiedDate)

			// Verify that the upload task has been removed
			XCTAssertEqual([itemMetadata.id], self.uploadTaskManagerMock.removeTaskRecordForReceivedInvocations)

			// Verify that the corresponding upload progress has been saved
			XCTAssertEqual(NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: itemID), progressManagerMock.saveProgressForReceivedArguments?.itemIdentifier)
			XCTAssertEqual(1, progressManagerMock.saveProgressForCallsCount)
		}
		.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 5.0)
	}

	func testUploadFileFailForMissingLocalCachedFileInfo() throws {
		let localURL = tmpDirectory.appendingPathComponent("FileToBeUploaded", isDirectory: false)
		try "TestContent".write(to: localURL, atomically: true, encoding: .utf8)
		let cloudPath = CloudPath("/FileToBeUploaded")
		let itemMetadata = ItemMetadata(id: 2, name: "FileToBeUploaded", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, isPlaceholderItem: true, isCandidateForCacheCleanup: false)

		let mockedCloudDate = Date(timeIntervalSinceReferenceDate: 0)
		cloudProviderMock.lastModifiedDate[cloudPath.path] = mockedCloudDate

		let uploadTaskExecutor = UploadTaskExecutor(domainIdentifier: .test, provider: cloudProviderMock, cachedFileManager: cachedFileManagerMock, itemMetadataManager: metadataManagerMock, uploadTaskManager: uploadTaskManagerMock)

		let uploadTaskRecord = try UploadTaskRecord(correspondingItem: XCTUnwrap(itemMetadata.id), lastFailedUploadDate: nil, uploadErrorCode: nil, uploadErrorDomain: nil, uploadStartedAt: nil)
		let uploadTask = UploadTask(taskRecord: uploadTaskRecord, itemMetadata: itemMetadata, cloudPath: cloudPath, onURLSessionTaskCreation: nil)

		let promise = uploadTaskExecutor.execute(task: uploadTask)
		try assertUploadErrorReported(by: promise, expectedError: NSFileProviderError(.noSuchItem)._nsError, itemMetadata: itemMetadata, localURL: nil)
	}

	func testUploadFileFailForFailingLocalCachedFileInfoLookup() throws {
		let cloudPath = CloudPath("/FileToBeUploaded")
		let itemMetadata = ItemMetadata(id: 2, name: "FileToBeUploaded", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, isPlaceholderItem: true, isCandidateForCacheCleanup: false)
		cachedFileManagerMock.getLocalCachedFileInfoForThrowableError = CloudTaskTestError.correctPassthrough

		let uploadTaskExecutor = UploadTaskExecutor(domainIdentifier: .test, provider: cloudProviderMock, cachedFileManager: cachedFileManagerMock, itemMetadataManager: metadataManagerMock, uploadTaskManager: uploadTaskManagerMock)

		let uploadTaskRecord = try UploadTaskRecord(correspondingItem: XCTUnwrap(itemMetadata.id), lastFailedUploadDate: nil, uploadErrorCode: nil, uploadErrorDomain: nil, uploadStartedAt: nil)
		let uploadTask = UploadTask(taskRecord: uploadTaskRecord, itemMetadata: itemMetadata, cloudPath: cloudPath, onURLSessionTaskCreation: nil)

		let promise = uploadTaskExecutor.execute(task: uploadTask)
		try assertUploadErrorReported(by: promise, expectedError: CloudTaskTestError.correctPassthrough as NSError, itemMetadata: itemMetadata, localURL: nil)
	}

	func testUploadFileFailForMissingLocalFile() throws {
		let localURL = tmpDirectory.appendingPathComponent("MissingFile", isDirectory: false)
		let cloudPath = CloudPath("/MissingFile")
		let itemMetadata = ItemMetadata(id: 2, name: "MissingFile", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, isPlaceholderItem: true, isCandidateForCacheCleanup: false)
		cachedFileManagerMock.cachedLocalFileInfo[2] = LocalCachedFileInfo(lastModifiedDate: nil, correspondingItem: 2, localLastModifiedDate: Date(), localURL: localURL)

		let uploadTaskExecutor = UploadTaskExecutor(domainIdentifier: .test, provider: cloudProviderMock, cachedFileManager: cachedFileManagerMock, itemMetadataManager: metadataManagerMock, uploadTaskManager: uploadTaskManagerMock)

		let uploadTaskRecord = try UploadTaskRecord(correspondingItem: XCTUnwrap(itemMetadata.id), lastFailedUploadDate: nil, uploadErrorCode: nil, uploadErrorDomain: nil, uploadStartedAt: nil)
		let uploadTask = UploadTask(taskRecord: uploadTaskRecord, itemMetadata: itemMetadata, cloudPath: cloudPath, onURLSessionTaskCreation: nil)

		let promise = uploadTaskExecutor.execute(task: uploadTask)
		try assertUploadErrorReported(by: promise, expectedError: NSFileProviderError(.noSuchItem)._nsError, itemMetadata: itemMetadata, localURL: localURL)
	}

	func testUploadFileFailForUnreadableLocalFile() throws {
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

		let uploadTaskExecutor = UploadTaskExecutor(domainIdentifier: .test, provider: cloudProviderMock, cachedFileManager: cachedFileManagerMock, itemMetadataManager: metadataManagerMock, uploadTaskManager: uploadTaskManagerMock)

		let uploadTaskRecord = try UploadTaskRecord(correspondingItem: XCTUnwrap(itemMetadata.id), lastFailedUploadDate: nil, uploadErrorCode: nil, uploadErrorDomain: nil, uploadStartedAt: nil)
		let uploadTask = UploadTask(taskRecord: uploadTaskRecord, itemMetadata: itemMetadata, cloudPath: cloudPath, onURLSessionTaskCreation: nil)

		let promise = uploadTaskExecutor.execute(task: uploadTask)
		wait(for: promise)
		let updatedItem = try XCTUnwrap(promise.value)
		let uploadingError = try XCTUnwrap(updatedItem.uploadingError as NSError?)
		XCTAssertEqual(NSCocoaErrorDomain, uploadingError.domain)
		XCTAssertEqual(CocoaError.fileReadNoPermission.rawValue, uploadingError.code)
	}

	func testUploadFileWithInconsistencyCheck() throws {
		let expectation = XCTestExpectation()
		let localURL = tmpDirectory.appendingPathComponent("FileToBeUploaded", isDirectory: false)
		try "TestContent".write(to: localURL, atomically: true, encoding: .utf8)
		let cloudPath = CloudPath("/FileToBeUploaded")
		let itemMetadata = ItemMetadata(id: 2, name: "FileToBeUploaded", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, isPlaceholderItem: true, isCandidateForCacheCleanup: false)
		cachedFileManagerMock.cachedLocalFileInfo[2] = LocalCachedFileInfo(lastModifiedDate: nil, correspondingItem: 2, localLastModifiedDate: Date(), localURL: localURL)

		let cloudProviderUploadInconsistencyMock = CloudProviderUploadInconsistencyMock()
		let mockedCloudDate = Date(timeIntervalSinceReferenceDate: 0)
		cloudProviderUploadInconsistencyMock.lastModifiedDate[cloudPath.path] = mockedCloudDate

		let uploadTaskExecutor = UploadTaskExecutor(domainIdentifier: .test, provider: cloudProviderUploadInconsistencyMock, cachedFileManager: cachedFileManagerMock, itemMetadataManager: metadataManagerMock, uploadTaskManager: uploadTaskManagerMock)

		let uploadTaskRecord = try UploadTaskRecord(correspondingItem: XCTUnwrap(itemMetadata.id), lastFailedUploadDate: nil, uploadErrorCode: nil, uploadErrorDomain: nil, uploadStartedAt: nil)
		let uploadTask = UploadTask(taskRecord: uploadTaskRecord, itemMetadata: itemMetadata, cloudPath: cloudPath, onURLSessionTaskCreation: nil)

		uploadTaskExecutor.execute(task: uploadTask).then { item in
			// Verify that the file has been modified since the upload began.
			XCTAssertNotEqual(Data("TestContent".utf8), cloudProviderUploadInconsistencyMock.createdFiles["/FileToBeUploaded"])

			XCTAssertEqual(1, self.metadataManagerMock.updatedMetadata.count)
			let updatedItemMetadata = self.metadataManagerMock.updatedMetadata[0]
			XCTAssertEqual(ItemStatus.isUploaded, updatedItemMetadata.statusCode)
			XCTAssertFalse(updatedItemMetadata.isPlaceholderItem)

			// Verify that there is no longer an entry about the cached file and the ( outdated ) locally cached file has been removed.
			XCTAssertTrue(self.cachedFileManagerMock.removeCachedFile.contains(2))

			XCTAssertFalse(item.newestVersionLocallyCached)
			XCTAssertNil(item.localURL)
			XCTAssertNil(item.error)

			// Verify that the upload task has been removed
			XCTAssertEqual([itemMetadata.id], self.uploadTaskManagerMock.removeTaskRecordForReceivedInvocations)
		}
		.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 5.0)
	}

	func testUploadFileFailReportsUploadError() throws {
		let localURL = tmpDirectory.appendingPathComponent("itemNotFound.txt", isDirectory: false)
		try "".write(to: localURL, atomically: true, encoding: .utf8)
		let cloudPath = CloudPath("/itemNotFound.txt")
		let itemMetadata = ItemMetadata(id: 2, name: "itemNotFound.txt", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, isPlaceholderItem: true, isCandidateForCacheCleanup: false)
		cachedFileManagerMock.cachedLocalFileInfo[2] = LocalCachedFileInfo(lastModifiedDate: nil, correspondingItem: 2, localLastModifiedDate: Date(), localURL: localURL)

		let errorCloudProviderMock = CloudProviderErrorMock()
		errorCloudProviderMock.uploadFileResponse = { _, _, _ in
			Promise(CloudProviderError.noInternetConnection)
		}

		let uploadTaskExecutor = UploadTaskExecutor(domainIdentifier: .test, provider: errorCloudProviderMock, cachedFileManager: cachedFileManagerMock, itemMetadataManager: metadataManagerMock, uploadTaskManager: uploadTaskManagerMock)

		let uploadTaskRecord = try UploadTaskRecord(correspondingItem: XCTUnwrap(itemMetadata.id), lastFailedUploadDate: nil, uploadErrorCode: nil, uploadErrorDomain: nil, uploadStartedAt: nil)
		let uploadTask = UploadTask(taskRecord: uploadTaskRecord, itemMetadata: itemMetadata, cloudPath: cloudPath, onURLSessionTaskCreation: nil)

		let promise = uploadTaskExecutor.execute(task: uploadTask)
		try assertUploadErrorReported(by: promise, expectedError: NSFileProviderError(.serverUnreachable)._nsError, itemMetadata: itemMetadata, localURL: localURL)
	}

	private func assertUploadErrorReported(by promise: Promise<FileProviderItem>, expectedError: NSError, itemMetadata: ItemMetadata, localURL: URL?, file: StaticString = #filePath, line: UInt = #line) throws {
		wait(for: promise, file: file, line: line)
		let updatedItem = try XCTUnwrap(promise.value, file: file, line: line)
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

	private class CloudProviderUploadInconsistencyMock: CustomCloudProviderMock {
		override func uploadFile(from localURL: URL, to cloudPath: CloudPath, replaceExisting: Bool, onTaskCreation: ((URLSessionUploadTask?) -> Void)?) -> Promise<CloudItemMetadata> {
			precondition(localURL.isFileURL)
			precondition(!localURL.hasDirectoryPath)
			do {
				var data = try Data(contentsOf: localURL)
				// simulate file change from 3rd party device, leading to inconsistent CloudItemMetadata
				data.append(Data("foo".utf8))
				createdFiles[cloudPath.path] = data
				return Promise(CloudItemMetadata(name: cloudPath.lastPathComponent, cloudPath: cloudPath, itemType: .file, lastModifiedDate: lastModifiedDate[cloudPath.path] ?? nil, size: data.count))
			} catch {
				return Promise(error)
			}
		}
	}
}
