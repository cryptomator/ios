//
//  FileProviderDecoratorErrorReportingForUserDrivenActions.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 16.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import XCTest
@testable import CryptomatorFileProvider

class FileProviderDecoratorErrorReportingForUserDrivenActions: FileProviderDecoratorTestCase {
	func testReportErrorWithFileProviderItemWithoutCorrespondingUploadTask() throws {
		let lastModifiedDate = Date(timeIntervalSinceReferenceDate: 0)
		let cloudPath = CloudPath("/TestItem")
		let itemMetadata = ItemMetadata(name: "TestItem", type: .file, size: 100, parentId: MetadataManager.rootContainerId, lastModifiedDate: lastModifiedDate, statusCode: .isUploading, cloudPath: cloudPath, isPlaceholderItem: true)
		try decorator.itemMetadataManager.cacheMetadata(itemMetadata)
		let testError = NSError(domain: "TestDomain", code: -100, userInfo: nil)
		let item = decorator.reportErrorWithFileProviderItem(error: testError, itemMetadata: itemMetadata)
		XCTAssertEqual(ItemStatus.uploadError, item.metadata.statusCode)
		XCTAssertNotNil(item.error)
		guard let itemError = item.error as NSError? else {
			XCTFail("Item has no Error")
			return
		}
		XCTAssertEqual("TestDomain", itemError.domain)
		XCTAssertEqual(-100, itemError.code)
		XCTAssertEqual("TestItem", item.metadata.name)
		XCTAssertEqual(100, item.metadata.size)
		XCTAssertEqual(MetadataManager.rootContainerId, item.metadata.parentId)
		XCTAssertEqual(lastModifiedDate, item.metadata.lastModifiedDate)
		XCTAssertEqual(cloudPath, item.metadata.cloudPath)
		XCTAssert(item.metadata.isPlaceholderItem)
		XCTAssertFalse(item.metadata.isMaybeOutdated)
	}

	func testReportErrorWithFileProviderItemWithCorrespondingUploadTask() throws {
		let lastModifiedDate = Date(timeIntervalSinceReferenceDate: 0)
		let cloudPath = CloudPath("/TestItem")
		let itemMetadata = ItemMetadata(name: "TestItem", type: .file, size: 100, parentId: MetadataManager.rootContainerId, lastModifiedDate: lastModifiedDate, statusCode: .isUploading, cloudPath: cloudPath, isPlaceholderItem: true)
		try decorator.itemMetadataManager.cacheMetadata(itemMetadata)
		guard let id = itemMetadata.id else {
			XCTFail("Metadata has no id")
			return
		}
		_ = try decorator.uploadTaskManager.createNewTask(for: id)
		let testError = NSError(domain: "TestDomain", code: -100, userInfo: nil)
		let item = decorator.reportErrorWithFileProviderItem(error: testError, itemMetadata: itemMetadata)
		XCTAssertEqual(ItemStatus.uploadError, item.metadata.statusCode)
		XCTAssertNotNil(item.error)
		guard let itemError = item.error as NSError? else {
			XCTFail("Item has no Error")
			return
		}
		XCTAssertEqual("TestDomain", itemError.domain)
		XCTAssertEqual(-100, itemError.code)
		XCTAssertEqual("TestItem", item.metadata.name)
		XCTAssertEqual(100, item.metadata.size)
		XCTAssertEqual(MetadataManager.rootContainerId, item.metadata.parentId)
		XCTAssertEqual(lastModifiedDate, item.metadata.lastModifiedDate)
		XCTAssertEqual(cloudPath, item.metadata.cloudPath)
		XCTAssert(item.metadata.isPlaceholderItem)
		XCTAssertFalse(item.metadata.isMaybeOutdated)

		guard let uploadTask = try decorator.uploadTaskManager.getTask(for: id) else {
			XCTFail("No corresponding UploadTask found")
			return
		}
		XCTAssertEqual("TestDomain", uploadTask.uploadErrorDomain)
		XCTAssertEqual(-100, uploadTask.uploadErrorCode)
		XCTAssertNotNil(uploadTask.lastFailedUploadDate)
	}

	func testItemAlreadyExistRejects() throws {
		let cloudPath = CloudPath("/TestItem")
		let itemMetadata = ItemMetadata(name: "TestItem", type: .file, size: 100, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploading, cloudPath: cloudPath, isPlaceholderItem: true)
		try decorator.itemMetadataManager.cacheMetadata(itemMetadata)
		XCTAssertThrowsError(try decorator.errorHandlingForUserDrivenActions(error: CloudProviderError.itemAlreadyExists, itemMetadata: itemMetadata)) { error in
			guard case CloudProviderError.itemAlreadyExists = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}
	}
}
