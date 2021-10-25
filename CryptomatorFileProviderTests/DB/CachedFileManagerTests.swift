//
//  CachedFileManagerTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 20.10.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import GRDB
import XCTest
@testable import CryptomatorFileProvider

class CachedFileManagerTests: CacheTestCase {
	var manager: CachedFileDBManager!
	var metadataManager: ItemMetadataDBManager!

	var inMemoryDB: DatabaseQueue!

	override func setUpWithError() throws {
		try super.setUpWithError()
		inMemoryDB = DatabaseQueue()
		try DatabaseHelper.migrate(inMemoryDB)
		manager = CachedFileDBManager(database: inMemoryDB)
		metadataManager = ItemMetadataDBManager(database: inMemoryDB)
	}

	func testCacheLocalFileInfo() throws {
		let date = Date(timeIntervalSince1970: 0)
		let localURLForItem = URL(fileURLWithPath: "/foo")
		try manager.cacheLocalFileInfo(for: ItemMetadataDBManager.rootContainerId, localURL: localURLForItem, lastModifiedDate: date)
		guard let localCachedFileInfo = try manager.getLocalCachedFileInfo(for: ItemMetadataDBManager.rootContainerId) else {
			XCTFail("No localCachedFileInfo found for rootContainerId")
			return
		}
		XCTAssertEqual(date, localCachedFileInfo.lastModifiedDate)
		XCTAssertEqual(ItemMetadataDBManager.rootContainerId, localCachedFileInfo.correspondingItem)
		XCTAssertEqual(localURLForItem, localCachedFileInfo.localURL)
	}

	func testHasCurrentVersionLocalWithOneSecondAccurcay() throws {
		let calendar = Calendar(identifier: .gregorian)
		let firstDateComp = DateComponents(year: 2020, month: 1, day: 2, hour: 0, minute: 0, second: 0, nanosecond: 0)
		let secondDateComp = DateComponents(year: 2020, month: 1, day: 2, hour: 0, minute: 0, second: 0, nanosecond: 10_000_000)

		let firstDate = calendar.date(from: firstDateComp)!
		let secondDate = calendar.date(from: secondDateComp)!

		let localURLForItem = URL(fileURLWithPath: "/foo")
		try manager.cacheLocalFileInfo(for: ItemMetadataDBManager.rootContainerId, localURL: localURLForItem, lastModifiedDate: firstDate)
		guard let localCachedFileInfo = try manager.getLocalCachedFileInfo(for: ItemMetadataDBManager.rootContainerId) else {
			XCTFail("No localCachedFileInfo found for rootContainerId")
			return
		}
		XCTAssertTrue(localCachedFileInfo.isCurrentVersion(lastModifiedDateInCloud: secondDate))

		let thirdDateComp = DateComponents(year: 2020, month: 1, day: 2, hour: 0, minute: 0, second: 1, nanosecond: 0)
		let thirdDate = calendar.date(from: thirdDateComp)!
		XCTAssertFalse(localCachedFileInfo.isCurrentVersion(lastModifiedDateInCloud: thirdDate))
	}

	func testRemoveCachedFile() throws {
		let url = tmpDirURL.appendingPathComponent("foo")
		let metadata = ItemMetadata(id: 1, name: "Foo", type: .file, size: nil, parentID: ItemMetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath(url.path), isPlaceholderItem: false)
		let data = getRandomData(sizeInBytes: 256)
		try createTestData(localURL: url, data: data, metadata: metadata)

		XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

		try manager.removeCachedFile(for: metadata.id!)
		XCTAssertNil(try manager.getLocalCachedFileInfo(for: metadata.id!))
		XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
	}

	func testRemoveCachedFileForPendingUpload() throws {
		let url = tmpDirURL.appendingPathComponent("foo")
		let metadata = ItemMetadata(id: 1, name: "Foo", type: .file, size: nil, parentID: ItemMetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath(url.path), isPlaceholderItem: false)
		let data = getRandomData(sizeInBytes: 256)
		try createTestData(localURL: url, data: data, metadata: metadata)

		XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

		// Simulate Pending Upload of file foo
		let uploadManager = UploadTaskDBManager(database: inMemoryDB)
		_ = try uploadManager.createNewTaskRecord(for: metadata)

		XCTAssertThrowsError(try manager.removeCachedFile(for: metadata.id!)) { error in
			guard case CachedFileManagerError.fileHasUnsyncedEdits = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}

		XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
		XCTAssertNotNil(try manager.getLocalCachedFileInfo(for: metadata.id!))
	}

	func testRemoveCachedFileForMissingFile() throws {
		let url = tmpDirURL.appendingPathComponent("foo")
		let metadata = ItemMetadata(id: 1, name: "Foo", type: .file, size: nil, parentID: ItemMetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath(url.path), isPlaceholderItem: false)
		let data = getRandomData(sizeInBytes: 256)
		try createTestData(localURL: url, data: data, metadata: metadata)
		try FileManager.default.removeItem(at: url)

		try manager.removeCachedFile(for: metadata.id!)
		XCTAssertNil(try manager.getLocalCachedFileInfo(for: metadata.id!))
	}

	func testRemoveCachedFileForFailingFileRemoval() throws {
		let url = tmpDirURL.appendingPathComponent("foo")
		let metadata = ItemMetadata(id: 1, name: "Foo", type: .file, size: nil, parentID: ItemMetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath(url.path), isPlaceholderItem: false)
		let data = getRandomData(sizeInBytes: 256)
		try createTestData(localURL: url, data: data, metadata: metadata)

		// Set local file foo to read-only to provoke an error when deleting inside the clearCache function
		try FileManager.default.setAttributes([.immutable: 1], ofItemAtPath: url.path)

		XCTAssertThrowsError(try manager.removeCachedFile(for: metadata.id!)) { error in
			guard case CocoaError.fileWriteNoPermission = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}
		XCTAssertNotNil(try manager.getLocalCachedFileInfo(for: metadata.id!))

		// Remove read-only flag so the file can be deleted in the tear down
		try FileManager.default.setAttributes([.immutable: 0], ofItemAtPath: url.path)
	}

	func testGetLocalCacheSizeInBytes() throws {
		let urls = [tmpDirURL.appendingPathComponent("foo"),
		            tmpDirURL.appendingPathComponent("bar")]
		let metadata = urls.enumerated().map { ItemMetadata(id: Int64($0), name: "Item", type: .file, size: nil, parentID: ItemMetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath($1.path), isPlaceholderItem: false) }
		let data = getRandomData(sizeInBytes: 256)

		for (index, url) in urls.enumerated() {
			try createTestData(localURL: url, data: data, metadata: metadata[index])
		}

		XCTAssertEqual(512, try manager.getLocalCacheSizeInBytes())
	}

	func testGetLocalCacheSizeInBytesFiltersOutPendingUploads() throws {
		let urls = [tmpDirURL.appendingPathComponent("foo"),
		            tmpDirURL.appendingPathComponent("bar")]
		let metadata = urls.enumerated().map { ItemMetadata(id: Int64($0), name: "Item", type: .file, size: nil, parentID: ItemMetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath($1.path), isPlaceholderItem: false) }
		let data = getRandomData(sizeInBytes: 256)

		for (index, url) in urls.enumerated() {
			try createTestData(localURL: url, data: data, metadata: metadata[index])
		}

		// Simulate Pending Upload of file foo
		let uploadManager = UploadTaskDBManager(database: inMemoryDB)
		_ = try uploadManager.createNewTaskRecord(for: metadata[0])

		XCTAssertEqual(256, try manager.getLocalCacheSizeInBytes())
	}

	func testClearCache() throws {
		let urls = [tmpDirURL.appendingPathComponent("foo"),
		            tmpDirURL.appendingPathComponent("bar")]
		let metadata = urls.enumerated().map { ItemMetadata(id: Int64($0), name: "Item", type: .file, size: nil, parentID: ItemMetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath($1.path), isPlaceholderItem: false) }
		let data = getRandomData(sizeInBytes: 256)

		for (index, url) in urls.enumerated() {
			try createTestData(localURL: url, data: data, metadata: metadata[index])
		}

		try manager.clearCache()

		for (index, url) in urls.enumerated() {
			XCTAssertNil(try manager.getLocalCachedFileInfo(for: metadata[index].id!))
			XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
		}
	}

	func testClearCacheRollback() throws {
		let urls = [tmpDirURL.appendingPathComponent("foo"),
		            tmpDirURL.appendingPathComponent("bar"),
		            tmpDirURL.appendingPathComponent("baz")]
		let metadata = urls.enumerated().map { ItemMetadata(id: Int64($0), name: "Item", type: .file, size: nil, parentID: ItemMetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath($1.path), isPlaceholderItem: false) }
		let data = getRandomData(sizeInBytes: 256)

		for (index, url) in urls.enumerated() {
			try createTestData(localURL: url, data: data, metadata: metadata[index])
		}

		// Set local file bar to read-only to provoke an error when deleting inside the clearCache function
		try FileManager.default.setAttributes([.immutable: 1], ofItemAtPath: urls[1].path)

		try manager.clearCache()

		XCTAssertNil(try manager.getLocalCachedFileInfo(for: metadata[0].id!))
		XCTAssertFalse(FileManager.default.fileExists(atPath: urls[0].path))
		XCTAssertNil(try manager.getLocalCachedFileInfo(for: metadata[2].id!))
		XCTAssertFalse(FileManager.default.fileExists(atPath: urls[2].path))

		XCTAssertNotNil(try manager.getLocalCachedFileInfo(for: metadata[1].id!))

		// Remove read-only flag so the file can be deleted in the tear down
		try FileManager.default.setAttributes([.immutable: 0], ofItemAtPath: urls[1].path)
	}

	private func createTestData(localURL: URL, data: Data, metadata: ItemMetadata) throws {
		try createTestData(localURL: localURL, data: data, metadata: metadata, cacheManager: manager, metadataManager: metadataManager)
	}
}

class CacheTestCase: XCTestCase {
	var tmpDirURL: URL!

	override func setUpWithError() throws {
		tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: tmpDirURL, withIntermediateDirectories: true)
	}

	override func tearDownWithError() throws {
		try FileManager.default.removeItem(at: tmpDirURL)
	}

	func createTestData(localURL: URL, data: Data, metadata: ItemMetadata, cacheManager: CachedFileManager, metadataManager: ItemMetadataManager) throws {
		let date = Date(timeIntervalSince1970: 0)
		try data.write(to: localURL)
		try metadataManager.cacheMetadata(metadata)
		try cacheManager.cacheLocalFileInfo(for: metadata.id!, localURL: localURL, lastModifiedDate: date)
	}

	func getRandomData(sizeInBytes: Int) -> Data {
		let bytes = [UInt32](repeating: 0, count: sizeInBytes).map { _ in arc4random() }
		let data = Data(bytes: bytes, count: sizeInBytes)
		return data
	}
}
