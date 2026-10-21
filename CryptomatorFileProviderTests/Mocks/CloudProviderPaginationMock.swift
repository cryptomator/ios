//
//  CloudProviderPaginationMock.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 15.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation

/// @unchecked Sendable: adds only immutable state to `CustomCloudProviderMock`
class CloudProviderPaginationMock: CustomCloudProviderMock, @unchecked Sendable {
	let pages = [
		"0": [
			CloudItemMetadata(name: "a", cloudPath: CloudPath("/a"), itemType: .file, lastModifiedDate: nil, size: nil),
			CloudItemMetadata(name: "b", cloudPath: CloudPath("/b"), itemType: .file, lastModifiedDate: nil, size: nil)
		],
		"1": [
			CloudItemMetadata(name: "d", cloudPath: CloudPath("/d"), itemType: .file, lastModifiedDate: nil, size: nil),
			CloudItemMetadata(name: "e", cloudPath: CloudPath("/e"), itemType: .file, lastModifiedDate: nil, size: nil),
			CloudItemMetadata(name: "f", cloudPath: CloudPath("/f"), itemType: .file, lastModifiedDate: nil, size: nil),
			CloudItemMetadata(name: "Folder", cloudPath: CloudPath("/Folder/"), itemType: .folder, lastModifiedDate: nil, size: nil)
		]
	]
	let nextPageToken = [
		"0": "1"
	]

	let folderItems: [CloudItemMetadata] = [
		CloudItemMetadata(name: "a", cloudPath: CloudPath("/Folder/a"), itemType: .file, lastModifiedDate: nil, size: nil),
		CloudItemMetadata(name: "b", cloudPath: CloudPath("/Folder/b/"), itemType: .folder, lastModifiedDate: nil, size: nil)
	]
	@concurrent
	override func fetchItemList(forFolderAt cloudPath: CloudPath, withPageToken pageToken: String?) async throws -> CloudItemList {
		if cloudPath == CloudPath("/Folder/") {
			return CloudItemList(items: folderItems, nextPageToken: nil)
		}
		switch pageToken {
		case nil:
			return CloudItemList(items: pages["0"]!, nextPageToken: nextPageToken["0"])
		case "1":
			return CloudItemList(items: pages["1"]!, nextPageToken: nil)
		default:
			throw CloudProviderError.noInternetConnection
		}
	}
}
