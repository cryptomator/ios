//
//  FileProviderAdapterGetItemTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 04.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import XCTest
@testable import CryptomatorFileProvider

class FileProviderAdapterGetItemTests: FileProviderAdapterTestCase {
	func testGetFileProviderItemThrowsForNonExistentItem() throws {
		XCTAssertThrowsError(try adapter.item(for: NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: 2)), "Did not throw for non existent Item") { error in
			guard let fileProviderError = error as? NSFileProviderError else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
			guard fileProviderError == NSFileProviderError(.noSuchItem) else {
				XCTFail("Throws the wrong FileProviderError: \(fileProviderError)")
				return
			}
		}
	}

	func testGetFileProviderItem() throws {
		let id: Int64 = 2
		let itemMetadata = ItemMetadata(id: id, name: "TestItem", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/TestItem"), isPlaceholderItem: false)
		metadataManagerMock.cachedMetadata[id] = itemMetadata

		let item = try adapter.item(for: NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: id))
		guard let fileProviderItem = item as? FileProviderItem else {
			XCTFail("Item is not a FileProviderItem")
			return
		}
		XCTAssertEqual(itemMetadata, fileProviderItem.metadata)
	}

	func testGetFileProviderItemWithUploadError() throws {
		let id: Int64 = 2
		let itemMetadata = ItemMetadata(id: id, name: "TestItem", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .uploadError, cloudPath: CloudPath("/TestItem"), isPlaceholderItem: true)
		metadataManagerMock.cachedMetadata[id] = itemMetadata

		let uploadTask = UploadTaskRecord(correspondingItem: id, lastFailedUploadDate: Date(), uploadErrorCode: NSFileProviderError(.insufficientQuota).errorCode, uploadErrorDomain: NSFileProviderErrorDomain)
		uploadTaskManagerMock.getTaskRecordForClosure = {
			guard id == $0 else {
				return nil
			}
			return uploadTask
		}
		let item = try adapter.item(for: NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: id))
		guard let fileProviderItem = item as? FileProviderItem else {
			XCTFail("Item is not a FileProviderItem")
			return
		}
		XCTAssertEqual(itemMetadata, fileProviderItem.metadata)
		XCTAssertNotNil(fileProviderItem.uploadingError)
	}
}
