//
//  CloudProviderMock.swift
//  CloudAccessPrivateCoreTests
//
//  Created by Philipp Schmid on 02.11.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import Foundation
import Promises
class CloudProviderMock: CloudProvider {
	var createdFolders: [String] = []
	var createdFiles: [String: Data] = [:]

	var filesToDownload = [String: Data]()

	func fetchItemMetadata(at cloudPath: CloudPath) -> Promise<CloudItemMetadata> {
		return Promise(CloudProviderError.noInternetConnection)
	}

	func fetchItemList(forFolderAt cloudPath: CloudPath, withPageToken pageToken: String?) -> Promise<CloudItemList> {
		return Promise(CloudProviderError.noInternetConnection)
	}

	func downloadFile(from cloudPath: CloudPath, to localURL: URL) -> Promise<Void> {
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

	func uploadFile(from localURL: URL, to cloudPath: CloudPath, replaceExisting: Bool) -> Promise<CloudItemMetadata> {
		precondition(localURL.isFileURL)
		precondition(!localURL.hasDirectoryPath)
		do {
			let data = try Data(contentsOf: localURL)
			createdFiles[cloudPath.path] = data
			return Promise(CloudItemMetadata(name: cloudPath.lastPathComponent, cloudPath: cloudPath, itemType: .file, lastModifiedDate: nil, size: data.count))
		} catch {
			return Promise(error)
		}
	}

	func createFolder(at cloudPath: CloudPath) -> Promise<Void> {
		createdFolders.append(cloudPath.path)
		return Promise(())
	}

	func deleteFile(at cloudPath: CloudPath) -> Promise<Void> {
		return Promise(CloudProviderError.noInternetConnection)
	}

	func deleteFolder(at cloudPath: CloudPath) -> Promise<Void> {
		return Promise(CloudProviderError.noInternetConnection)
	}

	func moveFile(from sourceCloudPath: CloudPath, to targetCloudPath: CloudPath) -> Promise<Void> {
		return Promise(CloudProviderError.noInternetConnection)
	}

	func moveFolder(from sourceCloudPath: CloudPath, to targetCloudPath: CloudPath) -> Promise<Void> {
		return Promise(CloudProviderError.noInternetConnection)
	}
}
