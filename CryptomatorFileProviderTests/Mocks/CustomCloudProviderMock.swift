//
//  CustomCloudProviderMock.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 01.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation
import os

/**
 ```
 root
 ├─ Directory 1
 │  ├─ Directory 2
 │  └─ File 5
 ├─ File 1
 ├─ File 2
 ├─ File 3
 └─ File 4
 ```
 */
/// @unchecked Sendable: mutable state guarded by `state`; not final because test doubles subclass it
@dynamicMemberLookup
class CustomCloudProviderMock: CloudProvider, @unchecked Sendable {
	struct State {
		var files: [String: Data?] = [
			"/File 1": Data("File 1 content".utf8),
			"/File 2": Data("File 2 content".utf8),
			"/File 3": Data("File 3 content".utf8),
			"/File 4": Data("File 4 content".utf8),
			"/Directory 1/File 5": Data("File 5 content".utf8)
		]
		var lastModifiedDate: [String: Date?] = ["/Directory 1": nil,
		                                         "/Directory 1/Directory 2": nil,
		                                         "/File 1": Date(timeIntervalSince1970: 0),
		                                         "/File 2": Date(timeIntervalSince1970: 0),
		                                         "/File 3": Date(timeIntervalSince1970: 0),
		                                         "/File 4": Date(timeIntervalSince1970: 0),
		                                         "/Directory 1/File 5": Date(timeIntervalSince1970: 0)]

		var createdFolders: [String] = []
		var createdFiles: [String: Data] = [:]
		var deletedFiles: [String] = []
		var deletedFolders: [String] = []
		var movedFiles: [String: String] = [:]
		var movedFolders: [String: String] = [:]

		var everyOperationShouldFailWithError: Error?
	}

	let folders: Set = [
		"/Directory 1",
		"/Directory 1/Directory 2"
	]
	private let state = OSAllocatedUnfairLock(initialState: State())

	subscript<T>(dynamicMember keyPath: WritableKeyPath<State, T>) -> T {
		get { state.withLockUnchecked { $0[keyPath: keyPath] } }
		set { state.withLockUnchecked { $0[keyPath: keyPath] = newValue } }
	}

	@concurrent
	func fetchItemMetadata(at cloudPath: CloudPath) async throws -> CloudItemMetadata {
		return try metadata(at: cloudPath)
	}

	private func metadata(at cloudPath: CloudPath) throws -> CloudItemMetadata {
		if let error = self.everyOperationShouldFailWithError {
			throw error
		}
		let lastModifiedDate = self.lastModifiedDate[cloudPath.path] ?? nil
		if folders.contains(cloudPath.path) {
			return CloudItemMetadata(name: cloudPath.lastPathComponent, cloudPath: cloudPath, itemType: .folder, lastModifiedDate: lastModifiedDate, size: 0)
		} else if let data = self.files[cloudPath.path] {
			return CloudItemMetadata(name: cloudPath.lastPathComponent, cloudPath: cloudPath, itemType: .file, lastModifiedDate: lastModifiedDate, size: data!.count)
		} else {
			throw CloudProviderError.itemNotFound
		}
	}

	@concurrent
	func fetchItemList(forFolderAt cloudPath: CloudPath, withPageToken pageToken: String?) async throws -> CloudItemList {
		switch cloudPath {
		case CloudPath("/itemNotFound"):
			throw CloudProviderError.itemNotFound
		case CloudPath("/itemTypeMismatch"):
			throw CloudProviderError.itemTypeMismatch
		case CloudPath("/pageTokenInvalid"):
			throw CloudProviderError.pageTokenInvalid
		case CloudPath("/unauthorized"):
			throw CloudProviderError.unauthorized
		case CloudPath("/noInternetConnection"):
			throw CloudProviderError.noInternetConnection
		default:
			return try normalFetchItemList(forFolderAt: cloudPath, withPageToken: pageToken)
		}
	}

	func normalFetchItemList(forFolderAt cloudPath: CloudPath, withPageToken _: String?) throws -> CloudItemList {
		let parentPath = cloudPath.path
		let parentPathLvl = parentPath.components(separatedBy: "/").count - (parentPath.hasSuffix("/") ? 1 : 0)
		let childDirs = folders.filter { $0.hasPrefix(parentPath) && $0.components(separatedBy: "/").count == parentPathLvl + 1 }
		let childFiles = self.files.keys.filter { $0.hasPrefix(parentPath) && $0.components(separatedBy: "/").count == parentPathLvl + 1 }
		let children = childDirs + childFiles
		let metadata = try children.map { try self.metadata(at: CloudPath($0)) }
		let sortedMetadata = metadata.sorted {
			$0.name < $1.name
		}
		return CloudItemList(items: sortedMetadata)
	}

	@concurrent
	func downloadFile(from cloudPath: CloudPath, to localURL: URL, progress: Progress?, onTaskCreation: (@concurrent @Sendable (URLSessionDownloadTask) async -> Void)?) async throws -> CloudItemMetadata {
		precondition(localURL.isFileURL)
		precondition(!localURL.hasDirectoryPath)
		guard let data = self.files[cloudPath.path] else {
			throw CloudProviderError.itemNotFound
		}
		try data!.write(to: localURL, options: .withoutOverwriting)
		return CloudItemMetadata(name: cloudPath.lastPathComponent, cloudPath: cloudPath, itemType: .file, lastModifiedDate: self.lastModifiedDate[cloudPath.path] ?? nil, size: data!.count)
	}

	@concurrent
	func uploadFile(from localURL: URL, to cloudPath: CloudPath, replaceExisting: Bool, progress: Progress?, onTaskCreation: (@concurrent @Sendable (URLSessionUploadTask) async -> Void)?) async throws -> CloudItemMetadata {
		precondition(localURL.isFileURL)
		precondition(!localURL.hasDirectoryPath)
		switch cloudPath {
		case CloudPath("/itemNotFound.txt"):
			throw CloudProviderError.itemNotFound
		case CloudPath("/itemAlreadyExists.txt"):
			throw CloudProviderError.itemAlreadyExists
		case CloudPath("/quotaInsufficient.txt"):
			throw CloudProviderError.quotaInsufficient
		case CloudPath("/noInternetConnection.txt"):
			throw CloudProviderError.noInternetConnection
		case CloudPath("/unauthorized.txt"):
			throw CloudProviderError.unauthorized
		default:
			return try normalUpload(from: localURL, to: cloudPath)
		}
	}

	private func normalUpload(from localURL: URL, to cloudPath: CloudPath) throws -> CloudItemMetadata {
		precondition(localURL.isFileURL)
		precondition(!localURL.hasDirectoryPath)
		let data = try Data(contentsOf: localURL)
		self.createdFiles[cloudPath.path] = data
		return CloudItemMetadata(name: cloudPath.lastPathComponent, cloudPath: cloudPath, itemType: .file, lastModifiedDate: self.lastModifiedDate[cloudPath.path] ?? nil, size: data.count)
	}

	@concurrent
	func createFolder(at cloudPath: CloudPath) async throws {
		switch cloudPath {
		case CloudPath("/FolderAlreadyExists/"):
			throw CloudProviderError.itemAlreadyExists
		case CloudPath("/quotaInsufficient/"):
			throw CloudProviderError.quotaInsufficient
		default:
			self.createdFolders.append(cloudPath.path)
		}
	}

	@concurrent
	func deleteFile(at cloudPath: CloudPath) async throws {
		self.deletedFiles.append(cloudPath.path)
	}

	@concurrent
	func deleteFolder(at cloudPath: CloudPath) async throws {
		self.deletedFolders.append(cloudPath.path)
	}

	@concurrent
	func moveFile(from sourceCloudPath: CloudPath, to targetCloudPath: CloudPath) async throws {
		switch targetCloudPath {
		case CloudPath("/FileAlreadyExists.txt"):
			throw CloudProviderError.itemAlreadyExists
		case CloudPath("/quotaInsufficient.txt"):
			throw CloudProviderError.quotaInsufficient
		default:
			self.movedFiles[sourceCloudPath.path] = targetCloudPath.path
		}
	}

	@concurrent
	func moveFolder(from sourceCloudPath: CloudPath, to targetCloudPath: CloudPath) async throws {
		switch targetCloudPath {
		case CloudPath("/FolderAlreadyExists/"):
			throw CloudProviderError.itemAlreadyExists
		case CloudPath("/quotaInsufficient/"):
			throw CloudProviderError.quotaInsufficient
		default:
			self.movedFolders[sourceCloudPath.path] = targetCloudPath.path
		}
	}

	func setLastModifiedDate(_ date: Date?, for remoteURL: CloudPath) {
		self.lastModifiedDate[remoteURL.path] = date
	}
}
