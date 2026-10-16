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
import os

// swiftlint:disable all

@dynamicMemberLookup
final class CloudProviderMock: CloudProvider {
	struct State {
		var uploadFileLastModifiedDate: [String: Date] = [:]
		var filesToDownload = [String: Data]()
		var cloudMetadata: [String: CloudItemMetadata] = [:]

		var fetchItemMetadataAtThrowableError: Error?
		var fetchItemMetadataAtCallsCount = 0
		var fetchItemMetadataAtReceivedCloudPath: CloudPath?
		var fetchItemMetadataAtReceivedInvocations: [CloudPath] = []
		var fetchItemMetadataAtReturnValue: CloudItemMetadata!
		var fetchItemMetadataAtClosure: (@Sendable (CloudPath) async throws -> CloudItemMetadata)?

		var fetchItemListForFolderAtWithPageTokenThrowableError: Error?
		var fetchItemListForFolderAtWithPageTokenCallsCount = 0
		var fetchItemListForFolderAtWithPageTokenReceivedArguments: (cloudPath: CloudPath, pageToken: String?)?
		var fetchItemListForFolderAtWithPageTokenReceivedInvocations: [(cloudPath: CloudPath, pageToken: String?)] = []
		var fetchItemListForFolderAtWithPageTokenReturnValue: CloudItemList!
		var fetchItemListForFolderAtWithPageTokenClosure: (@Sendable (CloudPath, String?) async throws -> CloudItemList)?

		var downloadFileFromToThrowableError: Error?
		var downloadFileFromToCallsCount = 0
		var downloadFileFromToReceivedArguments: (cloudPath: CloudPath, localURL: URL)?
		var downloadFileFromToReceivedInvocations: [(cloudPath: CloudPath, localURL: URL)] = []
		var downloadFileFromToReceivedProgress: Progress?
		var downloadFileFromToReceivedOnTaskCreation: (@concurrent @Sendable (URLSessionDownloadTask) async -> Void)?
		var downloadFileFromToReturnValue: CloudItemMetadata!
		var downloadFileFromToClosure: (@Sendable (CloudPath, URL) async throws -> CloudItemMetadata)?

		var uploadFileFromToReplaceExistingThrowableError: Error?
		var uploadFileFromToReplaceExistingCallsCount = 0
		var uploadFileFromToReplaceExistingReceivedArguments: (localURL: URL, cloudPath: CloudPath, replaceExisting: Bool)?
		var uploadFileFromToReplaceExistingReceivedInvocations: [(localURL: URL, cloudPath: CloudPath, replaceExisting: Bool)] = []
		var uploadFileFromToReplaceExistingReceivedProgress: Progress?
		var uploadFileFromToReplaceExistingReceivedOnTaskCreation: (@concurrent @Sendable (URLSessionUploadTask) async -> Void)?
		var uploadFileFromToReplaceExistingReturnValue: CloudItemMetadata!
		var uploadFileFromToReplaceExistingClosure: (@Sendable (URL, CloudPath, Bool) async throws -> CloudItemMetadata)?

		var createFolderAtThrowableError: Error?
		var createFolderAtCallsCount = 0
		var createFolderAtReceivedCloudPath: CloudPath?
		var createFolderAtReceivedInvocations: [CloudPath] = []
		var createFolderAtClosure: (@Sendable (CloudPath) async throws -> Void)?

		var deleteFileAtThrowableError: Error?
		var deleteFileAtCallsCount = 0
		var deleteFileAtReceivedCloudPath: CloudPath?
		var deleteFileAtReceivedInvocations: [CloudPath] = []
		var deleteFileAtClosure: (@Sendable (CloudPath) async throws -> Void)?

		var deleteFolderAtThrowableError: Error?
		var deleteFolderAtCallsCount = 0
		var deleteFolderAtReceivedCloudPath: CloudPath?
		var deleteFolderAtReceivedInvocations: [CloudPath] = []
		var deleteFolderAtClosure: (@Sendable (CloudPath) async throws -> Void)?

		var moveFileFromToThrowableError: Error?
		var moveFileFromToCallsCount = 0
		var moveFileFromToReceivedArguments: (sourceCloudPath: CloudPath, targetCloudPath: CloudPath)?
		var moveFileFromToReceivedInvocations: [(sourceCloudPath: CloudPath, targetCloudPath: CloudPath)] = []
		var moveFileFromToClosure: (@Sendable (CloudPath, CloudPath) async throws -> Void)?

		var moveFolderFromToThrowableError: Error?
		var moveFolderFromToCallsCount = 0
		var moveFolderFromToReceivedArguments: (sourceCloudPath: CloudPath, targetCloudPath: CloudPath)?
		var moveFolderFromToReceivedInvocations: [(sourceCloudPath: CloudPath, targetCloudPath: CloudPath)] = []
		var moveFolderFromToClosure: (@Sendable (CloudPath, CloudPath) async throws -> Void)?
	}

	let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
	private let state = OSAllocatedUnfairLock(initialState: State())

	subscript<T>(dynamicMember keyPath: WritableKeyPath<State, T>) -> T {
		get { state.withLockUnchecked { $0[keyPath: keyPath] } }
		set { state.withLockUnchecked { $0[keyPath: keyPath] = newValue } }
	}

	var createdFolders: [String] {
		return self.createFolderAtReceivedInvocations.map { $0.path }
	}

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

	var fetchItemMetadataAtCalled: Bool {
		self.fetchItemMetadataAtCallsCount > 0
	}

	@concurrent
	func fetchItemMetadata(at cloudPath: CloudPath) async throws -> CloudItemMetadata {
		let closure = try state.withLockUnchecked { state in
			if let error = state.fetchItemMetadataAtThrowableError {
				throw error
			}
			state.fetchItemMetadataAtCallsCount += 1
			state.fetchItemMetadataAtReceivedCloudPath = cloudPath
			state.fetchItemMetadataAtReceivedInvocations.append(cloudPath)
			return state.fetchItemMetadataAtClosure
		}
		if let closure {
			return try await closure(cloudPath)
		}
		return self.fetchItemMetadataAtReturnValue!
	}

	private func defaultFetchItemMetadata(at cloudPath: CloudPath) throws -> CloudItemMetadata {
		guard let metadata = self.cloudMetadata[cloudPath.path] else {
			throw CloudProviderError.itemNotFound
		}
		return metadata
	}

	// MARK: - fetchItemList

	var fetchItemListForFolderAtWithPageTokenCalled: Bool {
		self.fetchItemListForFolderAtWithPageTokenCallsCount > 0
	}

	@concurrent
	func fetchItemList(forFolderAt cloudPath: CloudPath, withPageToken pageToken: String?) async throws -> CloudItemList {
		let closure = try state.withLockUnchecked { state in
			if let error = state.fetchItemListForFolderAtWithPageTokenThrowableError {
				throw error
			}
			state.fetchItemListForFolderAtWithPageTokenCallsCount += 1
			state.fetchItemListForFolderAtWithPageTokenReceivedArguments = (cloudPath: cloudPath, pageToken: pageToken)
			state.fetchItemListForFolderAtWithPageTokenReceivedInvocations.append((cloudPath: cloudPath, pageToken: pageToken))
			return state.fetchItemListForFolderAtWithPageTokenClosure
		}
		if let closure {
			return try await closure(cloudPath, pageToken)
		}
		return self.fetchItemListForFolderAtWithPageTokenReturnValue!
	}

	// MARK: - downloadFile

	var downloadFileFromToCalled: Bool {
		self.downloadFileFromToCallsCount > 0
	}

	private func defaultDownloadFile(from cloudPath: CloudPath, to localURL: URL) throws -> CloudItemMetadata {
		guard let data = self.filesToDownload[cloudPath.path] else {
			throw CloudProviderError.itemNotFound
		}
		try data.write(to: localURL)
		return CloudItemMetadata(name: cloudPath.lastPathComponent, cloudPath: cloudPath, itemType: .file, lastModifiedDate: self.cloudMetadata[cloudPath.path]?.lastModifiedDate, size: data.count)
	}

	@concurrent
	func downloadFile(from cloudPath: CloudPath, to localURL: URL, progress: Progress?, onTaskCreation: (@concurrent @Sendable (URLSessionDownloadTask) async -> Void)?) async throws -> CloudItemMetadata {
		let closure = try state.withLockUnchecked { state in
			if let error = state.downloadFileFromToThrowableError {
				throw error
			}
			state.downloadFileFromToCallsCount += 1
			state.downloadFileFromToReceivedArguments = (cloudPath: cloudPath, localURL: localURL)
			state.downloadFileFromToReceivedInvocations.append((cloudPath: cloudPath, localURL: localURL))
			state.downloadFileFromToReceivedProgress = progress
			state.downloadFileFromToReceivedOnTaskCreation = onTaskCreation
			return state.downloadFileFromToClosure
		}
		if let closure {
			return try await closure(cloudPath, localURL)
		}
		return self.downloadFileFromToReturnValue!
	}

	// MARK: - uploadFile

	var uploadFileFromToReplaceExistingCalled: Bool {
		self.uploadFileFromToReplaceExistingCallsCount > 0
	}

	@concurrent
	func uploadFile(from localURL: URL, to cloudPath: CloudPath, replaceExisting: Bool, progress: Progress?, onTaskCreation: (@concurrent @Sendable (URLSessionUploadTask) async -> Void)?) async throws -> CloudItemMetadata {
		let closure = try state.withLockUnchecked { state in
			if let error = state.uploadFileFromToReplaceExistingThrowableError {
				throw error
			}
			state.uploadFileFromToReplaceExistingCallsCount += 1
			state.uploadFileFromToReplaceExistingReceivedArguments = (localURL: localURL, cloudPath: cloudPath, replaceExisting: replaceExisting)
			state.uploadFileFromToReplaceExistingReceivedInvocations.append((localURL: localURL, cloudPath: cloudPath, replaceExisting: replaceExisting))
			state.uploadFileFromToReplaceExistingReceivedProgress = progress
			state.uploadFileFromToReplaceExistingReceivedOnTaskCreation = onTaskCreation
			return state.uploadFileFromToReplaceExistingClosure
		}
		if let closure {
			return try await closure(localURL, cloudPath, replaceExisting)
		}
		return self.uploadFileFromToReplaceExistingReturnValue!
	}

	private func defaultUploadFile(from localURL: URL, to cloudPath: CloudPath, replaceExisting: Bool) throws -> CloudItemMetadata {
		do {
			let destinationURL = tmpDir.appendingPathComponent(cloudPath)
			try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
			try FileManager.default.copyItem(at: localURL, to: destinationURL)
			let data = try Data(contentsOf: destinationURL)
			return CloudItemMetadata(name: cloudPath.lastPathComponent, cloudPath: cloudPath, itemType: .file, lastModifiedDate: self.uploadFileLastModifiedDate[cloudPath.path], size: data.count)
		} catch CocoaError.fileWriteFileExists {
			throw CloudProviderError.itemAlreadyExists
		}
	}

	// MARK: - createFolder

	var createFolderAtCalled: Bool {
		self.createFolderAtCallsCount > 0
	}

	@concurrent
	func createFolder(at cloudPath: CloudPath) async throws {
		let closure = try state.withLockUnchecked { state in
			if let error = state.createFolderAtThrowableError {
				throw error
			}
			state.createFolderAtCallsCount += 1
			state.createFolderAtReceivedCloudPath = cloudPath
			state.createFolderAtReceivedInvocations.append(cloudPath)
			return state.createFolderAtClosure
		}
		try await closure?(cloudPath)
	}

	// MARK: - deleteFile

	var deleteFileAtCalled: Bool {
		self.deleteFileAtCallsCount > 0
	}

	@concurrent
	func deleteFile(at cloudPath: CloudPath) async throws {
		let closure = try state.withLockUnchecked { state in
			if let error = state.deleteFileAtThrowableError {
				throw error
			}
			state.deleteFileAtCallsCount += 1
			state.deleteFileAtReceivedCloudPath = cloudPath
			state.deleteFileAtReceivedInvocations.append(cloudPath)
			return state.deleteFileAtClosure
		}
		try await closure?(cloudPath)
	}

	// MARK: - deleteFolder

	var deleteFolderAtCalled: Bool {
		self.deleteFolderAtCallsCount > 0
	}

	@concurrent
	func deleteFolder(at cloudPath: CloudPath) async throws {
		let closure = try state.withLockUnchecked { state in
			if let error = state.deleteFolderAtThrowableError {
				throw error
			}
			state.deleteFolderAtCallsCount += 1
			state.deleteFolderAtReceivedCloudPath = cloudPath
			state.deleteFolderAtReceivedInvocations.append(cloudPath)
			return state.deleteFolderAtClosure
		}
		try await closure?(cloudPath)
	}

	// MARK: - moveFile

	var moveFileFromToCalled: Bool {
		self.moveFileFromToCallsCount > 0
	}

	@concurrent
	func moveFile(from sourceCloudPath: CloudPath, to targetCloudPath: CloudPath) async throws {
		let closure = try state.withLockUnchecked { state in
			if let error = state.moveFileFromToThrowableError {
				throw error
			}
			state.moveFileFromToCallsCount += 1
			state.moveFileFromToReceivedArguments = (sourceCloudPath: sourceCloudPath, targetCloudPath: targetCloudPath)
			state.moveFileFromToReceivedInvocations.append((sourceCloudPath: sourceCloudPath, targetCloudPath: targetCloudPath))
			return state.moveFileFromToClosure
		}
		try await closure?(sourceCloudPath, targetCloudPath)
	}

	// MARK: - moveFolder

	var moveFolderFromToCalled: Bool {
		self.moveFolderFromToCallsCount > 0
	}

	@concurrent
	func moveFolder(from sourceCloudPath: CloudPath, to targetCloudPath: CloudPath) async throws {
		let closure = try state.withLockUnchecked { state in
			if let error = state.moveFolderFromToThrowableError {
				throw error
			}
			state.moveFolderFromToCallsCount += 1
			state.moveFolderFromToReceivedArguments = (sourceCloudPath: sourceCloudPath, targetCloudPath: targetCloudPath)
			state.moveFolderFromToReceivedInvocations.append((sourceCloudPath: sourceCloudPath, targetCloudPath: targetCloudPath))
			return state.moveFolderFromToClosure
		}
		try await closure?(sourceCloudPath, targetCloudPath)
	}
}

// swiftlint:enable all
#endif
