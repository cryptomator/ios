//
//  CustomCloudProviderMock.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 01.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation
import Promises

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
class CustomCloudProviderMock: CloudProvider {
	let folders: Set = [
		"/Directory 1",
		"/Directory 1/Directory 2"
	]
	var files: [String: Data?] = [
		"/File 1": "File 1 content".data(using: .utf8),
		"/File 2": "File 2 content".data(using: .utf8),
		"/File 3": "File 3 content".data(using: .utf8),
		"/File 4": "File 4 content".data(using: .utf8),
		"/Directory 1/File 5": "File 5 content".data(using: .utf8)
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

	public func fetchItemMetadata(at cloudPath: CloudPath) -> Promise<CloudItemMetadata> {
		if let error = everyOperationShouldFailWithError {
			return Promise(error)
		}
		if folders.contains(cloudPath.path) {
			return Promise(CloudItemMetadata(name: cloudPath.lastPathComponent, cloudPath: cloudPath, itemType: .folder, lastModifiedDate: lastModifiedDate[cloudPath.path] ?? nil, size: 0))
		} else if let data = files[cloudPath.path] {
			return Promise(CloudItemMetadata(name: cloudPath.lastPathComponent, cloudPath: cloudPath, itemType: .file, lastModifiedDate: lastModifiedDate[cloudPath.path] ?? nil, size: data!.count))
		} else {
			return Promise(CloudProviderError.itemNotFound)
		}
	}

	public func fetchItemList(forFolderAt cloudPath: CloudPath, withPageToken pageToken: String?) -> Promise<CloudItemList> {
		switch cloudPath {
		case CloudPath("/itemNotFound"):
			return Promise(CloudProviderError.itemNotFound)
		case CloudPath("/itemTypeMismatch"):
			return Promise(CloudProviderError.itemTypeMismatch)
		case CloudPath("/pageTokenInvalid"):
			return Promise(CloudProviderError.pageTokenInvalid)
		case CloudPath("/unauthorized"):
			return Promise(CloudProviderError.unauthorized)
		case CloudPath("/noInternetConnection"):
			return Promise(CloudProviderError.noInternetConnection)
		default:
			return normalFetchItemList(forFolderAt: cloudPath, withPageToken: pageToken)
		}
	}

	func normalFetchItemList(forFolderAt cloudPath: CloudPath, withPageToken _: String?) -> Promise<CloudItemList> {
		let parentPath = cloudPath.path
		let parentPathLvl = parentPath.components(separatedBy: "/").count - (parentPath.hasSuffix("/") ? 1 : 0)
		let childDirs = folders.filter { $0.hasPrefix(parentPath) && $0.components(separatedBy: "/").count == parentPathLvl + 1 }
		let childFiles = files.keys.filter { $0.hasPrefix(parentPath) && $0.components(separatedBy: "/").count == parentPathLvl + 1 }
		let children = childDirs + childFiles
		let metadataPromises = children.map { self.fetchItemMetadata(at: CloudPath($0)) }
		return all(metadataPromises).then { metadata -> CloudItemList in
			let sortedMetadata = metadata.sorted {
				$0.name < $1.name
			}
			return CloudItemList(items: sortedMetadata)
		}
	}

	public func downloadFile(from cloudPath: CloudPath, to localURL: URL, onTaskCreation: ((URLSessionDownloadTask?) -> Void)?) -> Promise<Void> {
		precondition(localURL.isFileURL)
		precondition(!localURL.hasDirectoryPath)
		if let data = files[cloudPath.path] {
			do {
				try data!.write(to: localURL, options: .withoutOverwriting)
			} catch {
				return Promise(error)
			}
			return Promise(())
		} else {
			return Promise(CloudProviderError.itemNotFound)
		}
	}

	public func uploadFile(from localURL: URL, to cloudPath: CloudPath, replaceExisting: Bool, onTaskCreation: ((URLSessionUploadTask?) -> Void)?) -> Promise<CloudItemMetadata> {
		precondition(localURL.isFileURL)
		precondition(!localURL.hasDirectoryPath)
		switch cloudPath {
		case CloudPath("/itemNotFound.txt"):
			return Promise(CloudProviderError.itemNotFound)
		case CloudPath("/itemAlreadyExists.txt"):
			return Promise(CloudProviderError.itemAlreadyExists)
		case CloudPath("/quotaInsufficient.txt"):
			return Promise(CloudProviderError.quotaInsufficient)
		case CloudPath("/noInternetConnection.txt"):
			return Promise(CloudProviderError.noInternetConnection)
		case CloudPath("/unauthorized.txt"):
			return Promise(CloudProviderError.unauthorized)
		default:
			return normalUpload(from: localURL, to: cloudPath)
		}
	}

	private func normalUpload(from localURL: URL, to cloudPath: CloudPath) -> Promise<CloudItemMetadata> {
		precondition(localURL.isFileURL)
		precondition(!localURL.hasDirectoryPath)
		do {
			let data = try Data(contentsOf: localURL)
			createdFiles[cloudPath.path] = data
			return Promise(CloudItemMetadata(name: cloudPath.lastPathComponent, cloudPath: cloudPath, itemType: .file, lastModifiedDate: lastModifiedDate[cloudPath.path] ?? nil, size: data.count))
		} catch {
			return Promise(error)
		}
	}

	public func createFolder(at cloudPath: CloudPath) -> Promise<Void> {
		switch cloudPath {
		case CloudPath("/FolderAlreadyExists/"):
			return Promise(CloudProviderError.itemAlreadyExists)
		case CloudPath("/quotaInsufficient/"):
			return Promise(CloudProviderError.quotaInsufficient)
		default:
			createdFolders.append(cloudPath.path)
			return Promise(())
		}
	}

	public func deleteFile(at cloudPath: CloudPath) -> Promise<Void> {
		deletedFiles.append(cloudPath.path)
		return Promise(())
	}

	public func deleteFolder(at cloudPath: CloudPath) -> Promise<Void> {
		deletedFolders.append(cloudPath.path)
		return Promise(())
	}

	public func moveFile(from sourceCloudPath: CloudPath, to targetCloudPath: CloudPath) -> Promise<Void> {
		switch targetCloudPath {
		case CloudPath("/FileAlreadyExists.txt"):
			return Promise(CloudProviderError.itemAlreadyExists)
		case CloudPath("/quotaInsufficient.txt"):
			return Promise(CloudProviderError.quotaInsufficient)
		default:
			movedFiles[sourceCloudPath.path] = targetCloudPath.path
			return Promise(())
		}
	}

	public func moveFolder(from sourceCloudPath: CloudPath, to targetCloudPath: CloudPath) -> Promise<Void> {
		switch targetCloudPath {
		case CloudPath("/FolderAlreadyExists/"):
			return Promise(CloudProviderError.itemAlreadyExists)
		case CloudPath("/quotaInsufficient/"):
			return Promise(CloudProviderError.quotaInsufficient)
		default:
			movedFolders[sourceCloudPath.path] = targetCloudPath.path
			return Promise(())
		}
	}

	public func setLastModifiedDate(_ date: Date?, for remoteURL: CloudPath) {
		lastModifiedDate[remoteURL.path] = date
	}
}
