//
//  DropboxCloudProvider.swift
//  CloudAccessPrivate
//
//  Created by Philipp Schmid on 29.05.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import Foundation
import Promises
class DropboxCloudProvider: CloudProvider {
	func fetchItemMetadata(at _: URL) -> Promise<CloudItemMetadata> {
		return Promise(CloudProviderError.noInternetConnection)
	}

	func fetchItemList(forFolderAt _: URL, withPageToken _: String?) -> Promise<CloudItemList> {
		return Promise(CloudProviderError.noInternetConnection)
	}

	func downloadFile(from _: URL, to _: URL, progress _: Progress?) -> Promise<CloudItemMetadata> {
		return Promise(CloudProviderError.noInternetConnection)
	}

	func uploadFile(from _: URL, to _: URL, isUpdate _: Bool, progress _: Progress?) -> Promise<CloudItemMetadata> {
		return Promise(CloudProviderError.noInternetConnection)
	}

	func createFolder(at _: URL) -> Promise<Void> {
		return Promise(CloudProviderError.noInternetConnection)
	}

	func deleteItem(at _: URL) -> Promise<Void> {
		return Promise(CloudProviderError.noInternetConnection)
	}

	func moveItem(from _: URL, to _: URL) -> Promise<Void> {
		return Promise(CloudProviderError.noInternetConnection)
	}
}
