//
//  FileProviderAdapterEnumerateItemTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 08.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Dependencies
import XCTest
@testable import CryptomatorFileProvider

class FileProviderAdapterEnumerateItemTests: FileProviderAdapterTestCase {
	override func setUp() async throws {
		try await super.setUp()
		uploadTaskManagerMock.getCorrespondingTaskRecordsIdsClosure = {
			return $0.map { _ in nil }
		}
	}

	// MARK: Error Handling

	func testEnumerateItemsFailedWithNoInternetConnection() async throws {
		let metadata = ItemMetadata(id: 2, name: "noInternetConnection", type: .folder, size: nil, parentID: 1, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false, isCandidateForCacheCleanup: false, favoriteRank: nil, tagData: Data())
		try metadataManagerMock.cacheMetadata(metadata)
		itemEnumerationTaskManagerMock.stubCloudPath = CloudPath("/noInternetConnection")
		await XCTAssertThrowsAsyncError(try await adapter.enumerateItems(for: NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: 2), withPageToken: nil)) { error in
			XCTAssertEqual(NSFileProviderError(.serverUnreachable) as NSError, error as NSError)
		}
	}

	func testEnumerateItemsOfflineFallbackToCache() async throws {
		let metadata = ItemMetadata(id: 2, name: "noInternetConnection", type: .folder, size: nil, parentID: 1, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false, isCandidateForCacheCleanup: false, favoriteRank: nil, tagData: Data(), lastEnumeratedAt: Date())
		try metadataManagerMock.cacheMetadata(metadata)

		let child = ItemMetadata(id: 3, name: "CachedFile", type: .file, size: 14, parentID: 2, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(child)
		itemEnumerationTaskManagerMock.stubCloudPath = CloudPath("/noInternetConnection")

		let permissionProviderMock = PermissionProviderMock()
		permissionProviderMock.getPermissionsForAtReturnValue = .allowsReading
		let itemList = try await withDependencies {
			$0.permissionProvider = permissionProviderMock
		} operation: {
			try await adapter.enumerateItems(for: NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: 2), withPageToken: nil)
		}
		XCTAssertEqual(1, itemList.items.count)
		XCTAssertEqual("CachedFile", itemList.items[0].metadata.name)
		XCTAssertNil(itemList.nextPageToken)
	}

	// MARK: Enumerate Working Set

	func testWorkingSet() async throws {
		let mockMetadata = [
			ItemMetadata(id: 2, name: "Test", type: .file, size: nil, parentID: 1, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false, isCandidateForCacheCleanup: false, favoriteRank: nil, tagData: Data()),
			ItemMetadata(id: 3, name: "TestFolder", type: .file, size: nil, parentID: 4, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false, isCandidateForCacheCleanup: false, favoriteRank: 1, tagData: nil)
		]
		metadataManagerMock.workingSetMetadata = mockMetadata
		let permissionProviderMock = PermissionProviderMock()
		permissionProviderMock.getPermissionsForAtReturnValue = .allowsReading
		let itemList = try await withDependencies {
			$0.permissionProvider = permissionProviderMock
		} operation: {
			try await adapter.enumerateItems(for: .workingSet, withPageToken: nil)
		}
		XCTAssertEqual(mockMetadata, itemList.items.map(\.metadata))
		XCTAssertNil(itemList.nextPageToken)
	}

	func testEmptyWorkingSet() async throws {
		let itemList = try await adapter.enumerateItems(for: .workingSet, withPageToken: nil)
		XCTAssert(itemList.items.isEmpty)
		XCTAssertNil(itemList.nextPageToken)
	}

	func testWorkingSetReturnsEmptyItemListWithPageTokenSet() async throws {
		let itemList = try await adapter.enumerateItems(for: .workingSet, withPageToken: "PageToken")
		XCTAssert(itemList.items.isEmpty)
		XCTAssertNil(itemList.nextPageToken)
	}
}
