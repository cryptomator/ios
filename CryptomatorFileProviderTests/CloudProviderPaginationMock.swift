//
//  CloudProviderPaginationMock.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 15.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import Foundation
import Promises

class CloudProviderPaginationMock: CloudProviderMock {
	var pages = [
		"0": [
			CloudItemMetadata(name: "a", remoteURL: URL(fileURLWithPath: "/a", isDirectory: false), itemType: .file, lastModifiedDate: nil, size: nil),
			CloudItemMetadata(name: "b", remoteURL: URL(fileURLWithPath: "/b", isDirectory: false), itemType: .file, lastModifiedDate: nil, size: nil)
		],
		"1": [
			CloudItemMetadata(name: "d", remoteURL: URL(fileURLWithPath: "/d", isDirectory: false), itemType: .file, lastModifiedDate: nil, size: nil),
			CloudItemMetadata(name: "e", remoteURL: URL(fileURLWithPath: "/e", isDirectory: false), itemType: .file, lastModifiedDate: nil, size: nil),
			CloudItemMetadata(name: "f", remoteURL: URL(fileURLWithPath: "/f", isDirectory: false), itemType: .file, lastModifiedDate: nil, size: nil)
		]
	]
	var nextPageToken = [
		"0": "1"
	]
	override func fetchItemList(forFolderAt remoteURL: URL, withPageToken pageToken: String?) -> Promise<CloudItemList> {
		switch pageToken {
		case nil:
			return Promise(CloudItemList(items: pages["0"]!, nextPageToken: nextPageToken["0"]))
		case "1":
			return Promise(CloudItemList(items: pages["1"]!, nextPageToken: nil))
		default:
			return Promise(CloudProviderError.noInternetConnection)
		}
	}
}
