//
//  FileProviderAdapterGetItemIdentifierTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 23.05.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import XCTest
@testable import CryptomatorFileProvider

class FileProviderAdapterGetItemIdentifierTests: FileProviderAdapterTestCase {
	override func setUp() async throws {
		try await super.setUp()
		uploadTaskManagerMock.getCorrespondingTaskRecordsIdsClosure = {
			$0.map { _ in return nil }
		}
		metadataManagerMock.cachedMetadata[NSFileProviderItemIdentifier.rootContainerDatabaseValue] = ItemMetadata(id: NSFileProviderItemIdentifier.rootContainerDatabaseValue,
		                                                                                                           name: "Home",
		                                                                                                           type: .folder,
		                                                                                                           size: nil,
		                                                                                                           parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue,
		                                                                                                           lastModifiedDate: nil,
		                                                                                                           statusCode: .isUploaded,
		                                                                                                           isPlaceholderItem: false)
	}

	func testGetItemIdentifierForRoot() async throws {
		let cloudPath = CloudPath("/")
		let itemIdentifier = try await adapter.getItemIdentifier(for: cloudPath)
		XCTAssertEqual(.rootContainer, itemIdentifier)
	}

	func testGetItemIdentifierForSubFolder() async throws {
		let cloudPath = CloudPath("/Directory 1/Directory 2")
		let folderMetadata = ItemMetadata(id: 2,
		                                  name: "Directory 1",
		                                  type: .folder,
		                                  size: nil,
		                                  parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue,
		                                  lastModifiedDate: nil,
		                                  statusCode: .isUploaded,
		                                  isPlaceholderItem: false)

		let folderMetadataID = try XCTUnwrap(folderMetadata.id)
		metadataManagerMock.cachedMetadata[folderMetadataID] = folderMetadata

		let subFolderMetadata = try ItemMetadata(id: 3,
		                                         name: "Directory 2",
		                                         type: .folder,
		                                         size: nil,
		                                         parentID: XCTUnwrap(folderMetadata.id),
		                                         lastModifiedDate: nil,
		                                         statusCode: .isUploaded,
		                                         isPlaceholderItem: false)
		let subFolderMetadataID = try XCTUnwrap(subFolderMetadata.id)
		metadataManagerMock.cachedMetadata[subFolderMetadataID] = subFolderMetadata

		let itemIdentifier = try await adapter.getItemIdentifier(for: cloudPath)
		let expectedItemIdentifier = NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: subFolderMetadataID)
		XCTAssertEqual(expectedItemIdentifier, itemIdentifier)
	}

	func testGetItemIdentifierFallsBackToEnumerationForColdPath() async throws {
		// Not cached, but exists in mock cloud; enumeration populates the cache, then lookup succeeds.
		let cloudPath = CloudPath("/Directory 1/Directory 2")
		let itemIdentifier = try await adapter.getItemIdentifier(for: cloudPath)
		let resolvedMetadata = try XCTUnwrap(metadataManagerMock.getCachedMetadata(for: cloudPath))
		XCTAssertEqual(try NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: XCTUnwrap(resolvedMetadata.id)), itemIdentifier)
	}

	func testGetItemIdentifierForNonexistentItem() async {
		// Neither cached nor in mock cloud; enumeration finds nothing, lookup throws.
		let cloudPath = CloudPath("/Directory 1/Does Not Exist")
		await XCTAssertThrowsAsyncError(try await adapter.getItemIdentifier(for: cloudPath)) { error in
			XCTAssertEqual(NSFileProviderError(.noSuchItem)._nsError, error as NSError)
		}
	}
}
