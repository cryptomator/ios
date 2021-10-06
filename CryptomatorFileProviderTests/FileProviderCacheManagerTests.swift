//
//  FileProviderCacheManagerTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 05.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import FileProvider
import GRDB
import XCTest
@testable import CryptomatorFileProvider

class FileProviderCacheManagerTests: CacheTestCase {
	func testGetLocalCacheSizeInBytes() throws {
		let domains = getTestDomains(amount: 2)
		try prepareTestDomains(domains)
		try createCachedFile(in: domains[0], sizeInBytes: 256)

		let fileProviderCacheManager = FileProviderCacheManager(documentStorageURLProvider: DocumentStorageURLProviderMock(tmpDirURL: tmpDirURL))
		let actualTotalCacheSizeInBytes = try fileProviderCacheManager.getLocalCacheSizeInBytes(for: domains)

		XCTAssertEqual(256, actualTotalCacheSizeInBytes)

		// Create a cached file in the second domain
		try createCachedFile(in: domains[1], sizeInBytes: 512)

		let updatedActualTotalCacheSizeInBytes = try fileProviderCacheManager.getLocalCacheSizeInBytes(for: domains)
		XCTAssertEqual(768, updatedActualTotalCacheSizeInBytes)
	}

	func testGetLocalCacheSizeInBytesWithEmptyCache() throws {
		let domains = getTestDomains(amount: 2)
		try prepareTestDomains(domains)
		let fileProviderCacheManager = FileProviderCacheManager(documentStorageURLProvider: DocumentStorageURLProviderMock(tmpDirURL: tmpDirURL))
		let actualTotalCacheSizeInBytes = try fileProviderCacheManager.getLocalCacheSizeInBytes(for: domains)
		XCTAssertEqual(0, actualTotalCacheSizeInBytes)
	}

	func testClearCache() throws {
		let domains = getTestDomains(amount: 2)
		try prepareTestDomains(domains)

		let fileProviderCacheManager = FileProviderCacheManager(documentStorageURLProvider: DocumentStorageURLProviderMock(tmpDirURL: tmpDirURL))

		for domain in domains {
			try createCachedFile(in: domain, sizeInBytes: 256)
		}

		try fileProviderCacheManager.clearCache(for: domains)
		for domain in domains {
			try assertCacheCleared(for: domain)
		}
	}

	func getTestDomains(amount: Int) -> [NSFileProviderDomain] {
		var domains = [NSFileProviderDomain]()
		for i in 0 ..< amount {
			let domain = NSFileProviderDomain(identifier: NSFileProviderDomainIdentifier("\(i)"), displayName: "\(i)", pathRelativeToDocumentStorage: UUID().uuidString)
			domains.append(domain)
		}
		return domains
	}

	func prepareTestDomains(_ domains: [NSFileProviderDomain]) throws {
		try domains.forEach {
			let domainURL = tmpDirURL.appendingPathComponent($0.pathRelativeToDocumentStorage)
			try FileManager.default.createDirectory(at: domainURL, withIntermediateDirectories: false)
		}
	}

	func createCachedFile(in domain: NSFileProviderDomain, sizeInBytes: Int) throws {
		let data = getRandomData(sizeInBytes: sizeInBytes)
		let database = try getDatabase(for: domain)
		let itemMetadata = ItemMetadata(id: 1, name: "Foo", type: .file, size: nil, parentID: ItemMetadataDBManager.getRootContainerID(), lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/foo"), isPlaceholderItem: false)
		let domainURL = tmpDirURL.appendingPathComponent(domain.pathRelativeToDocumentStorage)
		let directoryPerItem = domainURL.appendingPathComponent("\(itemMetadata.id!)")
		try FileManager.default.createDirectory(at: directoryPerItem, withIntermediateDirectories: false)
		let localURL = directoryPerItem.appendingPathComponent("Foo")
		let cacheManager = CachedFileDBManager(database: database)
		let metadataManager = ItemMetadataDBManager(database: database)
		try createTestData(localURL: localURL, data: data, metadata: itemMetadata, cacheManager: cacheManager, metadataManager: metadataManager)
	}

	func getDatabase(for domain: NSFileProviderDomain) throws -> DatabaseWriter {
		let domainURL = tmpDirURL.appendingPathComponent(domain.pathRelativeToDocumentStorage)
		return try DatabaseHelper.getMigratedDB(at: domainURL.appendingPathComponent("db.sqlite"))
	}

	func assertCacheCleared(for domain: NSFileProviderDomain) throws {
		let domainURL = tmpDirURL.appendingPathComponent(domain.pathRelativeToDocumentStorage)
		let domainDirectoryContents = try FileManager.default.contentsOfDirectory(atPath: domainURL.path)

		XCTAssertTrue(domainDirectoryContents.contains { $0 == "1" })
		XCTAssertTrue(domainDirectoryContents.contains { $0 == "db.sqlite" })

		let directoryPerItem = domainURL.appendingPathComponent("1")
		let directoryPerItemContents = try FileManager.default.contentsOfDirectory(atPath: directoryPerItem.path)
		XCTAssert(directoryPerItemContents.isEmpty)

		let database = try getDatabase(for: domain)
		let cacheManager = CachedFileDBManager(database: database)
		XCTAssertNil(try cacheManager.getLocalCachedFileInfo(for: 1))
	}
}

private class DocumentStorageURLProviderMock: DocumentStorageURLProvider {
	private let tmpDirURL: URL

	init(tmpDirURL: URL) {
		self.tmpDirURL = tmpDirURL
	}

	var documentStorageURL: URL {
		return tmpDirURL
	}
}
