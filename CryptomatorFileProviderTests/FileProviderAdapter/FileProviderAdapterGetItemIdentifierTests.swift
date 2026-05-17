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
@testable import Promises

class FileProviderAdapterGetItemIdentifierTests: FileProviderAdapterTestCase {
	override func setUpWithError() throws {
		try super.setUpWithError()
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

	func testGetItemIdentifierForRoot() throws {
		let cloudPath = CloudPath("/")
		let getItemIdentifierPromise = adapter.getItemIdentifier(for: cloudPath)
		wait(for: getItemIdentifierPromise, timeout: 5.0)
		let itemIdentifier = try XCTUnwrap(getItemIdentifierPromise.value)
		XCTAssertEqual(.rootContainer, itemIdentifier)
	}

	func testGetItemIdentifierForSubFolder() throws {
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

		let getItemIdentifierPromise = adapter.getItemIdentifier(for: cloudPath)
		wait(for: getItemIdentifierPromise, timeout: 5.0)
		let itemIdentifier = try XCTUnwrap(getItemIdentifierPromise.value)
		let expectedItemIdentifier = NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: subFolderMetadataID)
		XCTAssertEqual(expectedItemIdentifier, itemIdentifier)
	}

	func testGetItemIdentifierFallsBackToEnumerationForColdPath() throws {
		// Not cached, but exists in mock cloud; enumeration populates the cache, then lookup succeeds.
		let cloudPath = CloudPath("/Directory 1/Directory 2")
		let getItemIdentifierPromise = adapter.getItemIdentifier(for: cloudPath)
		wait(for: getItemIdentifierPromise, timeout: 5.0)
		let itemIdentifier = try XCTUnwrap(getItemIdentifierPromise.value)
		let resolvedMetadata = try XCTUnwrap(metadataManagerMock.getCachedMetadata(for: cloudPath))
		XCTAssertEqual(try NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: XCTUnwrap(resolvedMetadata.id)), itemIdentifier)
	}

	func testGetItemIdentifierForNonexistentItem() {
		// Neither cached nor in mock cloud; enumeration finds nothing, lookup rejects.
		let cloudPath = CloudPath("/Directory 1/Does Not Exist")
		let getItemIdentifierPromise = adapter.getItemIdentifier(for: cloudPath)
		XCTAssertRejects(getItemIdentifierPromise, with: NSFileProviderError(.noSuchItem)._nsError)
	}
}
