//
//  FileProviderDecoratorGetFileProviderItemTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 15.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import XCTest
@testable import CryptomatorFileProvider
class FileProviderDecoratorGetFileProviderItemTests: FileProviderDecoratorTestCase {
	func testGetFileProviderItemThrowsForNonExistentItem() throws {
		XCTAssertThrowsError(try decorator.getFileProviderItem(for: NSFileProviderItemIdentifier("2")), "Did not throw for non existent Item") { error in
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
		let itemMetadata = ItemMetadata(name: "TestItem", type: .file, size: 100, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/TestItem"), isPlaceholderItem: false)
		try decorator.itemMetadataManager.cacheMetadata(itemMetadata)
		guard let id = itemMetadata.id else {
			XCTFail("Metadata has no ID")
			return
		}
		let item = try decorator.getFileProviderItem(for: NSFileProviderItemIdentifier(String(id)))
		XCTAssertEqual(itemMetadata, item.metadata)
	}

	func testGetFileProviderItemWithUploadError() throws {
		let itemMetadata = ItemMetadata(name: "TestItem", type: .file, size: 100, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .uploadError, cloudPath: CloudPath("/TestItem"), isPlaceholderItem: true)
		try decorator.itemMetadataManager.cacheMetadata(itemMetadata)
		guard let id = itemMetadata.id else {
			XCTFail("Metadata has no ID")
			return
		}
		var task = try decorator.uploadTaskManager.createNewTask(for: id)
		try decorator.uploadTaskManager.updateTask(&task, error: NSFileProviderError(.insufficientQuota)._nsError)
		let item = try decorator.getFileProviderItem(for: NSFileProviderItemIdentifier(String(id)))
		XCTAssertEqual(itemMetadata, item.metadata)
		XCTAssertNotNil(item.uploadingError)
	}
}
