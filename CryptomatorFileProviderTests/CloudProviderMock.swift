//
//  CloudProviderMock.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 01.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
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
class CloudProviderMock: CloudProvider {
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
	var deleted: [String] = []
	var moved: [String: String] = [:]

	public func fetchItemMetadata(at remoteURL: URL) -> Promise<CloudItemMetadata> {
		precondition(remoteURL.isFileURL)
		if folders.contains(remoteURL.relativePath) {
			return Promise(CloudItemMetadata(name: remoteURL.lastPathComponent, remoteURL: remoteURL, itemType: .folder, lastModifiedDate: lastModifiedDate[remoteURL.relativePath] ?? nil, size: 0))
		} else if let data = files[remoteURL.relativePath] {
			return Promise(CloudItemMetadata(name: remoteURL.lastPathComponent, remoteURL: remoteURL, itemType: .file, lastModifiedDate: lastModifiedDate[remoteURL.relativePath] ?? nil, size: data!.count))
		} else {
			return Promise(CloudProviderError.itemNotFound)
		}
	}

	public func fetchItemList(forFolderAt remoteURL: URL, withPageToken _: String?) -> Promise<CloudItemList> {
		precondition(remoteURL.isFileURL)
		precondition(remoteURL.hasDirectoryPath)
		let parentPath = remoteURL.relativePath
		let parentPathLvl = parentPath.components(separatedBy: "/").count - (parentPath.hasSuffix("/") ? 1 : 0)
		let childDirs = folders.filter { $0.hasPrefix(parentPath) && $0.components(separatedBy: "/").count == parentPathLvl + 1 }
		let childFiles = files.keys.filter { $0.hasPrefix(parentPath) && $0.components(separatedBy: "/").count == parentPathLvl + 1 }
		let children = childDirs + childFiles
		let metadataPromises = children.map { self.fetchItemMetadata(at: URL(fileURLWithPath: $0, isDirectory: childDirs.contains($0))) }
		return all(metadataPromises).then { metadata -> CloudItemList in
			let sortedMetadatas = metadata.sorted {
				$0.name < $1.name
			}
			return CloudItemList(items: sortedMetadatas)
		}
	}

	public func downloadFile(from remoteURL: URL, to localURL: URL) -> Promise<Void> {
		precondition(remoteURL.isFileURL)
		precondition(localURL.isFileURL)
		precondition(!remoteURL.hasDirectoryPath)
		precondition(!localURL.hasDirectoryPath)
		if let data = files[remoteURL.relativePath] {
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

	public func uploadFile(from localURL: URL, to remoteURL: URL, replaceExisting: Bool) -> Promise<CloudItemMetadata> {
		precondition(localURL.isFileURL)
		precondition(remoteURL.isFileURL)
		precondition(!localURL.hasDirectoryPath)
		precondition(!remoteURL.hasDirectoryPath)
		switch remoteURL {
		case URL(fileURLWithPath: "/itemNotFound.txt", isDirectory: false):
			return Promise(CloudProviderError.itemNotFound)
		case URL(fileURLWithPath: "/itemAlreadyExists.txt", isDirectory: false):
			return Promise(CloudProviderError.itemAlreadyExists)
		case URL(fileURLWithPath: "/quotaInsufficient.txt", isDirectory: false):
			return Promise(CloudProviderError.quotaInsufficient)
		case URL(fileURLWithPath: "/noInternetConnection.txt", isDirectory: false):
			return Promise(CloudProviderError.noInternetConnection)
		case URL(fileURLWithPath: "/unauthorized.txt", isDirectory: false):
			return Promise(CloudProviderError.unauthorized)
		default:
			return normalUpload(from: localURL, to: remoteURL)
		}
	}

	private func normalUpload(from localURL: URL, to remoteURL: URL) -> Promise<CloudItemMetadata> {
		precondition(localURL.isFileURL)
		precondition(remoteURL.isFileURL)
		precondition(!localURL.hasDirectoryPath)
		precondition(!remoteURL.hasDirectoryPath)
		do {
			let data = try Data(contentsOf: localURL)
			createdFiles[remoteURL.relativePath] = data
			return Promise(CloudItemMetadata(name: remoteURL.lastPathComponent, remoteURL: remoteURL, itemType: .file, lastModifiedDate: lastModifiedDate[remoteURL.relativePath] ?? nil, size: data.count))
		} catch {
			return Promise(error)
		}
	}

	public func createFolder(at remoteURL: URL) -> Promise<Void> {
		precondition(remoteURL.isFileURL)
		precondition(remoteURL.hasDirectoryPath)
		switch remoteURL {
		case URL(fileURLWithPath: "/FolderAlreadyExists/", isDirectory: true):
			return Promise(CloudProviderError.itemAlreadyExists)
		case URL(fileURLWithPath: "/quotaInsufficient/", isDirectory: true):
			return Promise(CloudProviderError.quotaInsufficient)
		default:
			createdFolders.append(remoteURL.relativePath)
			return Promise(())
		}
	}

	public func deleteItem(at remoteURL: URL) -> Promise<Void> {
		precondition(remoteURL.isFileURL)
		deleted.append(remoteURL.relativePath)
		return Promise(())
	}

	public func moveItem(from oldRemoteURL: URL, to newRemoteURL: URL) -> Promise<Void> {
		precondition(oldRemoteURL.isFileURL)
		precondition(newRemoteURL.isFileURL)
		precondition(oldRemoteURL.hasDirectoryPath == newRemoteURL.hasDirectoryPath)
		switch newRemoteURL {
		case URL(fileURLWithPath: "/FileAlreadyExists.txt", isDirectory: false):
			return Promise(CloudProviderError.itemAlreadyExists)
		case URL(fileURLWithPath: "/quotaInsufficient.txt", isDirectory: false):
			return Promise(CloudProviderError.quotaInsufficient)
		default:
			moved[oldRemoteURL.relativePath] = newRemoteURL.relativePath
			return Promise(())
		}
	}

	public func setLastModifiedDate(_ date: Date?, for remoteURL: URL) {
		lastModifiedDate[remoteURL.relativePath] = date
	}
}
