//
//  FileProviderItemTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 01.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import MobileCoreServices
import XCTest
@testable import CryptomatorCommonCore
@testable import CryptomatorFileProvider
@testable import Dependencies

class FileProviderItemTests: XCTestCase {
	func testRootItem() {
		let cloudPath = CloudPath("/")
		let metadata = ItemMetadata(id: NSFileProviderItemIdentifier.rootContainerDatabaseValue, name: "root", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
		let item = FileProviderItem(metadata: metadata, domainIdentifier: .test)
		XCTAssertEqual(NSFileProviderItemIdentifier.rootContainer, item.itemIdentifier)
		XCTAssertEqual(NSFileProviderItemIdentifier.rootContainer, item.parentItemIdentifier)
		XCTAssertEqual("public.folder", item.typeIdentifier)
	}

	func testFileItem() {
		let cloudPath = CloudPath("/test.txt")
		let metadata = ItemMetadata(id: 2, name: "test.txt", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
		let item = FileProviderItem(metadata: metadata, domainIdentifier: .test)
		XCTAssertEqual(NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: 2), item.itemIdentifier)
		XCTAssertEqual(NSFileProviderItemIdentifier.rootContainer, item.parentItemIdentifier)
		XCTAssertEqual("test.txt", item.filename)
		XCTAssertEqual(100, item.documentSize)
		XCTAssertTrue(item.isUploaded)
		XCTAssertFalse(item.isUploading)
		XCTAssertFalse(item.isDownloading)
		XCTAssertFalse(item.isDownloaded)
		XCTAssertEqual("public.plain-text", item.typeIdentifier)
	}

	func testFolderItem() {
		let cloudPath = CloudPath("/test Folder/")
		let metadata = ItemMetadata(id: 2, name: "test Folder", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
		let item = FileProviderItem(metadata: metadata, domainIdentifier: .test)
		XCTAssertEqual(NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: 2), item.itemIdentifier)
		XCTAssertEqual(NSFileProviderItemIdentifier.rootContainer, item.parentItemIdentifier)
		XCTAssertEqual("test Folder", item.filename)
		XCTAssertNil(item.documentSize)
		XCTAssertTrue(item.isUploaded)
		XCTAssertFalse(item.isUploading)
		XCTAssertFalse(item.isDownloading)
		XCTAssertTrue(item.isDownloaded)
		XCTAssertEqual("public.folder", item.typeIdentifier)
	}

	func testUploadError() {
		let cloudPath = CloudPath("/test.txt")
		let metadata = ItemMetadata(id: 2, name: "test.txt", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .uploadError, cloudPath: cloudPath, isPlaceholderItem: false)
		let lastFailedUploadDate = Date(timeIntervalSinceReferenceDate: 0)
		let failedUploadTask = UploadTaskRecord(correspondingItem: 2, lastFailedUploadDate: lastFailedUploadDate, uploadErrorCode: NSFileProviderError.insufficientQuota.rawValue, uploadErrorDomain: NSFileProviderErrorDomain)
		let item = FileProviderItem(metadata: metadata, domainIdentifier: .test, error: failedUploadTask.failedWithError)
		XCTAssertEqual(NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: 2), item.itemIdentifier)
		XCTAssertEqual(NSFileProviderItemIdentifier.rootContainer, item.parentItemIdentifier)
		XCTAssertEqual("test.txt", item.filename)
		XCTAssertEqual(100, item.documentSize)
		XCTAssertFalse(item.isUploaded)
		XCTAssertEqual("public.plain-text", item.typeIdentifier)
		guard let actualError = item.uploadingError as NSError? else {
			XCTFail("Item has no Error")
			return
		}
		let expectedError = NSFileProviderError(.insufficientQuota) as NSError
		XCTAssertTrue(expectedError.isEqual(actualError))
	}

	func testIsDownloadedOnlyForLocallyExistingFile() throws {
		let cloudPath = CloudPath("/test.txt")
		let metadata = ItemMetadata(id: 2, name: "test.txt", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)

		let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: false)
		let localURL = tmpDir.appendingPathComponent("test.txt")

		let item = FileProviderItem(metadata: metadata, domainIdentifier: .test, newestVersionLocallyCached: false, localURL: localURL)
		XCTAssertEqual(NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: 2), item.itemIdentifier)
		XCTAssertEqual(NSFileProviderItemIdentifier.rootContainer, item.parentItemIdentifier)
		XCTAssertEqual("test.txt", item.filename)
		XCTAssertEqual(100, item.documentSize)
		XCTAssertTrue(item.isUploaded)
		XCTAssertFalse(item.isUploading)
		XCTAssertFalse(item.isDownloading)
		XCTAssertFalse(item.isDownloaded)
		XCTAssertEqual("public.plain-text", item.typeIdentifier)

		try "Foo".write(to: localURL, atomically: true, encoding: .utf8)

		let newestItem = FileProviderItem(metadata: metadata, domainIdentifier: .test, newestVersionLocallyCached: false, localURL: localURL)
		XCTAssertEqual(NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: 2), newestItem.itemIdentifier)
		XCTAssertEqual(NSFileProviderItemIdentifier.rootContainer, newestItem.parentItemIdentifier)
		XCTAssertEqual("test.txt", newestItem.filename)
		XCTAssertEqual(100, newestItem.documentSize)
		XCTAssertTrue(newestItem.isUploaded)
		XCTAssertFalse(newestItem.isUploading)
		XCTAssertFalse(newestItem.isDownloading)
		XCTAssertTrue(newestItem.isDownloaded)
		XCTAssertEqual("public.plain-text", item.typeIdentifier)
	}

	// MARK: Capabilities

	func testCapabilitiesArePassedThroughFromPermissionProvider() {
		let permissionProviderMock = PermissionProviderMock()
		DependencyValues.mockDependency(\.permissionProvider, with: permissionProviderMock)

		let cloudPath = CloudPath("/test.txt")
		let metadata = ItemMetadata(id: 2, name: "test.txt", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, cloudPath: cloudPath, isPlaceholderItem: false)
		let item = FileProviderItem(metadata: metadata, domainIdentifier: .test)

		let capabilities: [NSFileProviderItemCapabilities] = [.allowsAddingSubItems, .allowsContentEnumerating, .allowsDeleting, .allowsReading, .allowsReparenting, .allowsWriting]
		for capability in capabilities {
			permissionProviderMock.getPermissionsForAtReturnValue = capability
			XCTAssertEqual(capability, item.capabilities)
		}
	}

	// MARK: Evict File From Cache Action

	func testEvictFileFromCacheActionEnabled() throws {
		let item = try createLocallyCachedFileProviderItem(with: .isUploaded)
		let userInfo = try XCTUnwrap(item.userInfo)
		XCTAssert(userInfo["enableEvictFileFromCacheAction"] as? Bool ?? false)
	}

	func testEvictFileFromCacheActionDisabledForUploadingItem() throws {
		let item = try createLocallyCachedFileProviderItem(with: .isUploading)
		let userInfo = try XCTUnwrap(item.userInfo)
		XCTAssertFalse(userInfo["enableEvictFileFromCacheAction"] as? Bool ?? true)
	}

	func testEvictFileFromCacheActionDisabledForDownloadingItem() throws {
		let item = try createLocallyCachedFileProviderItem(with: .isDownloading)
		let userInfo = try XCTUnwrap(item.userInfo)
		XCTAssertFalse(userInfo["enableEvictFileFromCacheAction"] as? Bool ?? true)
	}

	func testEvictFileFromCacheActionDisabledForNotCachedFile() throws {
		let cloudPath = CloudPath("/test")
		let metadata = ItemMetadata(id: 2, name: "test", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isDownloading, cloudPath: cloudPath, isPlaceholderItem: false)
		let item = FileProviderItem(metadata: metadata, domainIdentifier: .test)
		let userInfo = try XCTUnwrap(item.userInfo)
		XCTAssertFalse(userInfo["enableEvictFileFromCacheAction"] as? Bool ?? true)
	}

	func testEvictFileFromCacheActionDisabledForFolder() throws {
		let cloudPath = CloudPath("/test")
		let metadata = ItemMetadata(id: 2, name: "test", type: .folder, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isDownloading, cloudPath: cloudPath, isPlaceholderItem: false)
		let item = FileProviderItem(metadata: metadata, domainIdentifier: .test)
		let userInfo = try XCTUnwrap(item.userInfo)
		XCTAssertFalse(userInfo["enableEvictFileFromCacheAction"] as? Bool ?? true)
	}

	// - MARK: Retry Failed Upload Action

	func testRetryFailedUploadActionEnabled() throws {
		let cloudPath = CloudPath("/test")
		let metadata = ItemMetadata(id: 2, name: "test", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .uploadError, cloudPath: cloudPath, isPlaceholderItem: false)
		let item = FileProviderItem(metadata: metadata, domainIdentifier: .test, error: NSFileProviderError(.insufficientQuota)._nsError)
		let userInfo = try XCTUnwrap(item.userInfo)
		XCTAssertTrue(userInfo["enableRetryFailedUploadAction"] as? Bool ?? false)
	}

	func testRetryFailedUploadActionDisabled() throws {
		let cloudPath = CloudPath("/test")
		let metadata = ItemMetadata(id: 2, name: "test", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
		let item = FileProviderItem(metadata: metadata, domainIdentifier: .test)
		let userInfo = try XCTUnwrap(item.userInfo)
		XCTAssertFalse(userInfo["enableRetryFailedUploadAction"] as? Bool ?? true)
	}

	// - MARK: Retry Waiting Upload Action

	func testRetryWaitingUploadActionEnabled() throws {
		let cloudPath = CloudPath("/test")
		let metadata = ItemMetadata(id: 2, name: "test", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, cloudPath: cloudPath, isPlaceholderItem: false)
		let item = FileProviderItem(metadata: metadata, domainIdentifier: .test)
		let userInfo = try XCTUnwrap(item.userInfo)
		XCTAssert(userInfo["enableRetryWaitingUploadAction"] as? Bool ?? false)
	}

	func testRetryWaitingUploadActionDisabledForFolder() throws {
		let cloudPath = CloudPath("/test")
		let metadata = ItemMetadata(id: 2, name: "test", type: .folder, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, cloudPath: cloudPath, isPlaceholderItem: false)
		let item = FileProviderItem(metadata: metadata, domainIdentifier: .test)
		let userInfo = try XCTUnwrap(item.userInfo)
		XCTAssertFalse(userInfo["enableRetryWaitingUploadAction"] as? Bool ?? true)
	}

	func testRetryWaitingUploadActionDisabledForUploadError() throws {
		let cloudPath = CloudPath("/test")
		let metadata = ItemMetadata(id: 2, name: "test", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .uploadError, cloudPath: cloudPath, isPlaceholderItem: false)
		let item = FileProviderItem(metadata: metadata, domainIdentifier: .test, error: NSFileProviderError(.insufficientQuota)._nsError)
		let userInfo = try XCTUnwrap(item.userInfo)
		XCTAssertFalse(userInfo["enableRetryWaitingUploadAction"] as? Bool ?? true)
	}

	private func createLocallyCachedFileProviderItem(with statusCode: ItemStatus) throws -> FileProviderItem {
		let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: false)
		let localURL = tmpDir.appendingPathComponent("test.txt")
		try "Foo".write(to: localURL, atomically: true, encoding: .utf8)

		let cloudPath = CloudPath("/test")
		let metadata = ItemMetadata(id: 2, name: "test", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: statusCode, cloudPath: cloudPath, isPlaceholderItem: false)
		return FileProviderItem(metadata: metadata, domainIdentifier: .test, localURL: localURL)
	}
}
