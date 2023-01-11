//
//  CloudProviderMock.swift
//  CryptomatorCommonCoreTests
//
//  Created by Philipp Schmid on 28.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

#if DEBUG
import CryptomatorCloudAccessCore
import Foundation
import Promises

// swiftlint:disable all

final class CloudProviderMock: CloudProvider {
	let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

	var createdFolders: [String] {
		return createFolderAtReceivedInvocations.map { $0.path }
	}

	var uploadFileLastModifiedDate: [String: Date] = [:]
	var filesToDownload = [String: Data]()
	var cloudMetadata: [String: CloudItemMetadata] = [:]

	init() {
		try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
		self.downloadFileFromToClosure = defaultDownloadFile(from:to:)
		self.uploadFileFromToReplaceExistingClosure = defaultUploadFile(from:to:replaceExisting:)
		self.fetchItemMetadataAtClosure = defaultFetchItemMetadata(at:)
	}

	deinit {
		try? FileManager.default.removeItem(at: tmpDir)
	}

	// MARK: - fetchItemMetadata

	var fetchItemMetadataAtThrowableError: Error?
	var fetchItemMetadataAtCallsCount = 0
	var fetchItemMetadataAtCalled: Bool {
		fetchItemMetadataAtCallsCount > 0
	}

	var fetchItemMetadataAtReceivedCloudPath: CloudPath?
	var fetchItemMetadataAtReceivedInvocations: [CloudPath] = []
	var fetchItemMetadataAtReturnValue: Promise<CloudItemMetadata>!
	var fetchItemMetadataAtClosure: ((CloudPath) -> Promise<CloudItemMetadata>)?

	func fetchItemMetadata(at cloudPath: CloudPath) -> Promise<CloudItemMetadata> {
		if let error = fetchItemMetadataAtThrowableError {
			return Promise(error)
		}
		fetchItemMetadataAtCallsCount += 1
		fetchItemMetadataAtReceivedCloudPath = cloudPath
		fetchItemMetadataAtReceivedInvocations.append(cloudPath)
		return fetchItemMetadataAtClosure.map({ $0(cloudPath) }) ?? fetchItemMetadataAtReturnValue
	}

	private func defaultFetchItemMetadata(at cloudPath: CloudPath) -> Promise<CloudItemMetadata> {
		guard let metadata = cloudMetadata[cloudPath.path] else {
			return Promise(CloudProviderError.itemNotFound)
		}
		return Promise(metadata)
	}

	// MARK: - fetchItemList

	var fetchItemListForFolderAtWithPageTokenThrowableError: Error?
	var fetchItemListForFolderAtWithPageTokenCallsCount = 0
	var fetchItemListForFolderAtWithPageTokenCalled: Bool {
		fetchItemListForFolderAtWithPageTokenCallsCount > 0
	}

	var fetchItemListForFolderAtWithPageTokenReceivedArguments: (cloudPath: CloudPath, pageToken: String?)?
	var fetchItemListForFolderAtWithPageTokenReceivedInvocations: [(cloudPath: CloudPath, pageToken: String?)] = []
	var fetchItemListForFolderAtWithPageTokenReturnValue: Promise<CloudItemList>!
	var fetchItemListForFolderAtWithPageTokenClosure: ((CloudPath, String?) -> Promise<CloudItemList>)?

	func fetchItemList(forFolderAt cloudPath: CloudPath, withPageToken pageToken: String?) -> Promise<CloudItemList> {
		if let error = fetchItemListForFolderAtWithPageTokenThrowableError {
			return Promise(error)
		}
		fetchItemListForFolderAtWithPageTokenCallsCount += 1
		fetchItemListForFolderAtWithPageTokenReceivedArguments = (cloudPath: cloudPath, pageToken: pageToken)
		fetchItemListForFolderAtWithPageTokenReceivedInvocations.append((cloudPath: cloudPath, pageToken: pageToken))
		return fetchItemListForFolderAtWithPageTokenClosure.map({ $0(cloudPath, pageToken) }) ?? fetchItemListForFolderAtWithPageTokenReturnValue
	}

	// MARK: - downloadFile

	var downloadFileFromToThrowableError: Error?
	var downloadFileFromToCallsCount = 0
	var downloadFileFromToCalled: Bool {
		downloadFileFromToCallsCount > 0
	}

	var downloadFileFromToReceivedArguments: (cloudPath: CloudPath, localURL: URL)?
	var downloadFileFromToReceivedInvocations: [(cloudPath: CloudPath, localURL: URL)] = []
	var downloadFileFromToReturnValue: Promise<Void>!
	var downloadFileFromToClosure: ((CloudPath, URL) -> Promise<Void>)?

	private func defaultDownloadFile(from cloudPath: CloudPath, to localURL: URL) -> Promise<Void> {
		guard let data = filesToDownload[cloudPath.path] else {
			return Promise(CloudProviderError.itemNotFound)
		}
		do {
			try data.write(to: localURL)
			return Promise(())
		} catch {
			return Promise(error)
		}
	}

	func downloadFile(from cloudPath: CloudPath, to localURL: URL, onTaskCreation: ((URLSessionDownloadTask?) -> Void)?) -> Promise<Void> {
		if let error = downloadFileFromToThrowableError {
			return Promise(error)
		}
		downloadFileFromToCallsCount += 1
		downloadFileFromToReceivedArguments = (cloudPath: cloudPath, localURL: localURL)
		downloadFileFromToReceivedInvocations.append((cloudPath: cloudPath, localURL: localURL))
		return downloadFileFromToClosure.map({ $0(cloudPath, localURL) }) ?? downloadFileFromToReturnValue
	}

	// MARK: - uploadFile

	var uploadFileFromToReplaceExistingThrowableError: Error?
	var uploadFileFromToReplaceExistingCallsCount = 0
	var uploadFileFromToReplaceExistingCalled: Bool {
		uploadFileFromToReplaceExistingCallsCount > 0
	}

	var uploadFileFromToReplaceExistingReceivedArguments: (localURL: URL, cloudPath: CloudPath, replaceExisting: Bool)?
	var uploadFileFromToReplaceExistingReceivedInvocations: [(localURL: URL, cloudPath: CloudPath, replaceExisting: Bool)] = []
	var uploadFileFromToReplaceExistingReturnValue: Promise<CloudItemMetadata>!
	var uploadFileFromToReplaceExistingClosure: ((URL, CloudPath, Bool) -> Promise<CloudItemMetadata>)?

	func uploadFile(from localURL: URL, to cloudPath: CloudPath, replaceExisting: Bool, onTaskCreation: ((URLSessionUploadTask?) -> Void)?) -> Promise<CloudItemMetadata> {
		if let error = uploadFileFromToReplaceExistingThrowableError {
			return Promise(error)
		}
		uploadFileFromToReplaceExistingCallsCount += 1
		uploadFileFromToReplaceExistingReceivedArguments = (localURL: localURL, cloudPath: cloudPath, replaceExisting: replaceExisting)
		uploadFileFromToReplaceExistingReceivedInvocations.append((localURL: localURL, cloudPath: cloudPath, replaceExisting: replaceExisting))
		return uploadFileFromToReplaceExistingClosure.map({ $0(localURL, cloudPath, replaceExisting) }) ?? uploadFileFromToReplaceExistingReturnValue
	}

	private func defaultUploadFile(from localURL: URL, to cloudPath: CloudPath, replaceExisting: Bool) -> Promise<CloudItemMetadata> {
		do {
			let destinationURL = tmpDir.appendingPathComponent(cloudPath)
			try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
			try FileManager.default.copyItem(at: localURL, to: destinationURL)
			let data = try Data(contentsOf: destinationURL)
			return Promise(CloudItemMetadata(name: cloudPath.lastPathComponent, cloudPath: cloudPath, itemType: .file, lastModifiedDate: uploadFileLastModifiedDate[cloudPath.path], size: data.count))
		} catch CocoaError.fileWriteFileExists {
			return Promise(CloudProviderError.itemAlreadyExists)
		} catch {
			return Promise(error)
		}
	}

	// MARK: - createFolder

	var createFolderAtThrowableError: Error?
	var createFolderAtCallsCount = 0
	var createFolderAtCalled: Bool {
		createFolderAtCallsCount > 0
	}

	var createFolderAtReceivedCloudPath: CloudPath?
	var createFolderAtReceivedInvocations: [CloudPath] = []
	var createFolderAtReturnValue: Promise<Void>!
	var createFolderAtClosure: ((CloudPath) -> Promise<Void>)?

	func createFolder(at cloudPath: CloudPath) -> Promise<Void> {
		if let error = createFolderAtThrowableError {
			return Promise(error)
		}
		createFolderAtCallsCount += 1
		createFolderAtReceivedCloudPath = cloudPath
		createFolderAtReceivedInvocations.append(cloudPath)
		return createFolderAtClosure.map({ $0(cloudPath) }) ?? createFolderAtReturnValue
	}

	// MARK: - deleteFile

	var deleteFileAtThrowableError: Error?
	var deleteFileAtCallsCount = 0
	var deleteFileAtCalled: Bool {
		deleteFileAtCallsCount > 0
	}

	var deleteFileAtReceivedCloudPath: CloudPath?
	var deleteFileAtReceivedInvocations: [CloudPath] = []
	var deleteFileAtReturnValue: Promise<Void>!
	var deleteFileAtClosure: ((CloudPath) -> Promise<Void>)?

	func deleteFile(at cloudPath: CloudPath) -> Promise<Void> {
		if let error = deleteFileAtThrowableError {
			return Promise(error)
		}
		deleteFileAtCallsCount += 1
		deleteFileAtReceivedCloudPath = cloudPath
		deleteFileAtReceivedInvocations.append(cloudPath)
		return deleteFileAtClosure.map({ $0(cloudPath) }) ?? deleteFileAtReturnValue
	}

	// MARK: - deleteFolder

	var deleteFolderAtThrowableError: Error?
	var deleteFolderAtCallsCount = 0
	var deleteFolderAtCalled: Bool {
		deleteFolderAtCallsCount > 0
	}

	var deleteFolderAtReceivedCloudPath: CloudPath?
	var deleteFolderAtReceivedInvocations: [CloudPath] = []
	var deleteFolderAtReturnValue: Promise<Void>!
	var deleteFolderAtClosure: ((CloudPath) -> Promise<Void>)?

	func deleteFolder(at cloudPath: CloudPath) -> Promise<Void> {
		if let error = deleteFolderAtThrowableError {
			return Promise(error)
		}
		deleteFolderAtCallsCount += 1
		deleteFolderAtReceivedCloudPath = cloudPath
		deleteFolderAtReceivedInvocations.append(cloudPath)
		return deleteFolderAtClosure.map({ $0(cloudPath) }) ?? deleteFolderAtReturnValue
	}

	// MARK: - moveFile

	var moveFileFromToThrowableError: Error?
	var moveFileFromToCallsCount = 0
	var moveFileFromToCalled: Bool {
		moveFileFromToCallsCount > 0
	}

	var moveFileFromToReceivedArguments: (sourceCloudPath: CloudPath, targetCloudPath: CloudPath)?
	var moveFileFromToReceivedInvocations: [(sourceCloudPath: CloudPath, targetCloudPath: CloudPath)] = []
	var moveFileFromToReturnValue: Promise<Void>!
	var moveFileFromToClosure: ((CloudPath, CloudPath) -> Promise<Void>)?

	public func moveFile(from sourceCloudPath: CloudPath, to targetCloudPath: CloudPath) -> Promise<Void> {
		if let error = moveFileFromToThrowableError {
			return Promise(error)
		}
		moveFileFromToCallsCount += 1
		moveFileFromToReceivedArguments = (sourceCloudPath: sourceCloudPath, targetCloudPath: targetCloudPath)
		moveFileFromToReceivedInvocations.append((sourceCloudPath: sourceCloudPath, targetCloudPath: targetCloudPath))
		return moveFileFromToClosure.map({ $0(sourceCloudPath, targetCloudPath) }) ?? moveFileFromToReturnValue
	}

	// MARK: - moveFolder

	var moveFolderFromToThrowableError: Error?
	var moveFolderFromToCallsCount = 0
	var moveFolderFromToCalled: Bool {
		moveFolderFromToCallsCount > 0
	}

	var moveFolderFromToReceivedArguments: (sourceCloudPath: CloudPath, targetCloudPath: CloudPath)?
	var moveFolderFromToReceivedInvocations: [(sourceCloudPath: CloudPath, targetCloudPath: CloudPath)] = []
	var moveFolderFromToReturnValue: Promise<Void>!
	var moveFolderFromToClosure: ((CloudPath, CloudPath) -> Promise<Void>)?

	func moveFolder(from sourceCloudPath: CloudPath, to targetCloudPath: CloudPath) -> Promise<Void> {
		if let error = moveFolderFromToThrowableError {
			return Promise(error)
		}
		moveFolderFromToCallsCount += 1
		moveFolderFromToReceivedArguments = (sourceCloudPath: sourceCloudPath, targetCloudPath: targetCloudPath)
		moveFolderFromToReceivedInvocations.append((sourceCloudPath: sourceCloudPath, targetCloudPath: targetCloudPath))
		return moveFolderFromToClosure.map({ $0(sourceCloudPath, targetCloudPath) }) ?? moveFolderFromToReturnValue
	}
}

// swiftlint:enable all
#endif
