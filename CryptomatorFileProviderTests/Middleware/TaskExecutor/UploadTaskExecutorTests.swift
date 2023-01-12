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
		let itemMetadata = ItemMetadata(id: itemID, name: "FileToBeUploaded", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, cloudPath: cloudPath, isPlaceholderItem: true, isCandidateForCacheCleanup: false)
		cachedFileManagerMock.cachedLocalFileInfo[itemID] = LocalCachedFileInfo(lastModifiedDate: nil, correspondingItem: itemID, localLastModifiedDate: Date(), localURL: localURL)

		let uploadTaskExecutor = UploadTaskExecutor(domainIdentifier: .test, provider: cloudProviderMock, cachedFileManager: cachedFileManagerMock, itemMetadataManager: metadataManagerMock, uploadTaskManager: uploadTaskManagerMock, progressManager: progressManagerMock)

		let mockedCloudDate = Date(timeIntervalSinceReferenceDate: 0)
		cloudProviderMock.lastModifiedDate[itemMetadata.cloudPath.path] = mockedCloudDate
		let uploadTaskRecord = UploadTaskRecord(correspondingItem: itemID, lastFailedUploadDate: nil, uploadErrorCode: nil, uploadErrorDomain: nil)
		let uploadTask = UploadTask(taskRecord: uploadTaskRecord, itemMetadata: itemMetadata, onURLSessionTaskCreation: nil)
		uploadTaskExecutor.execute(task: uploadTask).then { _ in
			XCTAssertEqual("TestContent".data(using: .utf8), self.cloudProviderMock.createdFiles["/FileToBeUploaded"])

			XCTAssertEqual(1, self.metadataManagerMock.updatedMetadata.count)
			let updatedItemMetadata = self.metadataManagerMock.updatedMetadata[0]
			XCTAssertEqual(ItemStatus.isUploaded, updatedItemMetadata.statusCode)
			XCTAssertFalse(updatedItemMetadata.isPlaceholderItem)

			let cachedFileInfo = self.cachedFileManagerMock.cachedLocalFileInfo[itemID]
			let lastModifiedDate = cachedFileInfo?.lastModifiedDate
			XCTAssertNotNil(lastModifiedDate)
			XCTAssertEqual(self.cloudProviderMock.lastModifiedDate[itemMetadata.cloudPath.path], lastModifiedDate)

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
		wait(for: [expectation], timeout: 1.0)
	}

	func testUploadFileFailForMissingLocalCachedFileInfo() throws {
		let expectation = XCTestExpectation()
		let localURL = tmpDirectory.appendingPathComponent("FileToBeUploaded", isDirectory: false)
		try "TestContent".write(to: localURL, atomically: true, encoding: .utf8)
		let cloudPath = CloudPath("/FileToBeUploaded")
		let itemMetadata = ItemMetadata(id: 2, name: "FileToBeUploaded", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, cloudPath: cloudPath, isPlaceholderItem: true, isCandidateForCacheCleanup: false)

		let mockedCloudDate = Date(timeIntervalSinceReferenceDate: 0)
		cloudProviderMock.lastModifiedDate[itemMetadata.cloudPath.path] = mockedCloudDate

		let uploadTaskExecutor = UploadTaskExecutor(domainIdentifier: .test, provider: cloudProviderMock, cachedFileManager: cachedFileManagerMock, itemMetadataManager: metadataManagerMock, uploadTaskManager: uploadTaskManagerMock)

		let uploadTaskRecord = UploadTaskRecord(correspondingItem: itemMetadata.id!, lastFailedUploadDate: nil, uploadErrorCode: nil, uploadErrorDomain: nil)
		let uploadTask = UploadTask(taskRecord: uploadTaskRecord, itemMetadata: itemMetadata, onURLSessionTaskCreation: nil)

		uploadTaskExecutor.execute(task: uploadTask).then { _ in
			XCTFail("Promise should not fulfill for missing local cached file info")
		}
		.catch { error in
			let expectedError = NSFileProviderError(.noSuchItem) as NSError
			XCTAssertEqual(expectedError, error as NSError?)
			// Verify that the upload task has not been removed
			XCTAssertFalse(self.uploadTaskManagerMock.removeTaskRecordForCalled, "Unexpected removal of the upload task")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testUploadFileWithInconsistencyCheck() throws {
		let expectation = XCTestExpectation()
		let localURL = tmpDirectory.appendingPathComponent("FileToBeUploaded", isDirectory: false)
		try "TestContent".write(to: localURL, atomically: true, encoding: .utf8)
		let cloudPath = CloudPath("/FileToBeUploaded")
		let itemMetadata = ItemMetadata(id: 2, name: "FileToBeUploaded", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, cloudPath: cloudPath, isPlaceholderItem: true, isCandidateForCacheCleanup: false)
		cachedFileManagerMock.cachedLocalFileInfo[2] = LocalCachedFileInfo(lastModifiedDate: nil, correspondingItem: 2, localLastModifiedDate: Date(), localURL: localURL)

		let cloudProviderUploadInconsistencyMock = CloudProviderUploadInconsistencyMock()
		let mockedCloudDate = Date(timeIntervalSinceReferenceDate: 0)
		cloudProviderUploadInconsistencyMock.lastModifiedDate[itemMetadata.cloudPath.path] = mockedCloudDate

		let uploadTaskExecutor = UploadTaskExecutor(domainIdentifier: .test, provider: cloudProviderUploadInconsistencyMock, cachedFileManager: cachedFileManagerMock, itemMetadataManager: metadataManagerMock, uploadTaskManager: uploadTaskManagerMock)

		let uploadTaskRecord = UploadTaskRecord(correspondingItem: itemMetadata.id!, lastFailedUploadDate: nil, uploadErrorCode: nil, uploadErrorDomain: nil)
		let uploadTask = UploadTask(taskRecord: uploadTaskRecord, itemMetadata: itemMetadata, onURLSessionTaskCreation: nil)

		uploadTaskExecutor.execute(task: uploadTask).then { item in
			// Verify that the file has been modified since the upload began.
			XCTAssertNotEqual("TestContent".data(using: .utf8), cloudProviderUploadInconsistencyMock.createdFiles["/FileToBeUploaded"])

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
		wait(for: [expectation], timeout: 1.0)
	}

	func testUploadFileFailReportsUploadError() throws {
		let localURL = tmpDirectory.appendingPathComponent("itemNotFound.txt", isDirectory: false)
		try "".write(to: localURL, atomically: true, encoding: .utf8)
		let cloudPath = CloudPath("/itemNotFound.txt")
		let itemMetadata = ItemMetadata(id: 2, name: "itemNotFound.txt", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, cloudPath: cloudPath, isPlaceholderItem: true, isCandidateForCacheCleanup: false)
		cachedFileManagerMock.cachedLocalFileInfo[2] = LocalCachedFileInfo(lastModifiedDate: nil, correspondingItem: 2, localLastModifiedDate: Date(), localURL: localURL)

		let errorCloudProviderMock = CloudProviderErrorMock()
		errorCloudProviderMock.uploadFileResponse = { _, _, _ in
			Promise(CloudProviderError.noInternetConnection)
		}

		let uploadTaskExecutor = UploadTaskExecutor(domainIdentifier: .test, provider: errorCloudProviderMock, cachedFileManager: cachedFileManagerMock, itemMetadataManager: metadataManagerMock, uploadTaskManager: uploadTaskManagerMock)

		let uploadTaskRecord = UploadTaskRecord(correspondingItem: itemMetadata.id!, lastFailedUploadDate: nil, uploadErrorCode: nil, uploadErrorDomain: nil)
		let uploadTask = UploadTask(taskRecord: uploadTaskRecord, itemMetadata: itemMetadata, onURLSessionTaskCreation: nil)

		let promise = uploadTaskExecutor.execute(task: uploadTask)
		wait(for: promise)
		let updatedItem = try XCTUnwrap(promise.value)
		let expectedError = NSFileProviderError(.serverUnreachable)._nsError
		XCTAssertEqual(expectedError, updatedItem.uploadingError as NSError?)
		XCTAssertEqual(ItemStatus.uploadError, updatedItem.metadata.statusCode)
		XCTAssertFalse(uploadTaskManagerMock.removeTaskRecordForCalled, "Unexpected removal of the upload task")

		let updatedTaskRecordReceivedArguments = uploadTaskManagerMock.updateTaskRecordWithLastFailedUploadDateUploadErrorCodeUploadErrorDomainReceivedArguments

		XCTAssertEqual(2, updatedTaskRecordReceivedArguments?.id)
		XCTAssertEqual(expectedError.code, updatedTaskRecordReceivedArguments?.uploadErrorCode)
		XCTAssertEqual(expectedError.domain, updatedTaskRecordReceivedArguments?.uploadErrorDomain)
		XCTAssertEqual([itemMetadata], metadataManagerMock.updatedMetadata)
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
