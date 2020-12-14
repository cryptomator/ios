//
//  CachedFileManagerTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 20.10.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import GRDB
import XCTest
@testable import CryptomatorFileProvider
class CachedFileManagerTests: XCTestCase {
	var manager: CachedFileManager!
	var tmpDirURL: URL!
	var dbPool: DatabasePool!

	override func setUpWithError() throws {
		tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: tmpDirURL, withIntermediateDirectories: true)
		let dbURL = tmpDirURL.appendingPathComponent("db.sqlite", isDirectory: false)
		dbPool = try DatabaseHelper.getMigratedDB(at: dbURL)
		manager = CachedFileManager(with: dbPool)
	}

	override func tearDownWithError() throws {
		dbPool = nil
		manager = nil
		try FileManager.default.removeItem(at: tmpDirURL)
	}

	func testCacheLocalFileInfo() throws {
		let date = Date(timeIntervalSince1970: 0)
		let localURLForItem = URL(fileURLWithPath: "/foo")
		try manager.cacheLocalFileInfo(for: MetadataManager.rootContainerId,localURL: localURLForItem, lastModifiedDate: date)
		guard let localCachedFileInfo = try manager.getLocalCachedFileInfo(for: MetadataManager.rootContainerId) else {
			XCTFail("No localCachedFileInfo found for rootContainerId")
			return
		}
		XCTAssertEqual(date, localCachedFileInfo.lastModifiedDate)
		XCTAssertEqual(MetadataManager.rootContainerId, localCachedFileInfo.correspondingItem)
		XCTAssertEqual(localURLForItem, localCachedFileInfo.localURL)
	}

	func testHasCurrentVersionLocalWithOneSecondAccurcay() throws {
		let calendar = Calendar(identifier: .gregorian)
		let firstDateComp = DateComponents(year: 2020, month: 1, day: 2, hour: 0, minute: 0, second: 0, nanosecond: 0)
		let secondDateComp = DateComponents(year: 2020, month: 1, day: 2, hour: 0, minute: 0, second: 0, nanosecond: 10_000_000)

		let firstDate = calendar.date(from: firstDateComp)!
		let secondDate = calendar.date(from: secondDateComp)!

		let localURLForItem = URL(fileURLWithPath: "/foo")
		try manager.cacheLocalFileInfo(for: MetadataManager.rootContainerId, localURL: localURLForItem, lastModifiedDate: firstDate)
		guard let localCachedFileInfo = try manager.getLocalCachedFileInfo(for: MetadataManager.rootContainerId) else {
			XCTFail("No localCachedFileInfo found for rootContainerId")
			return
		}
		XCTAssertTrue(localCachedFileInfo.isCurrentVersion(lastModifiedDateInCloud: secondDate))

		let thirdDateComp = DateComponents(year: 2020, month: 1, day: 2, hour: 0, minute: 0, second: 1, nanosecond: 0)
		let thirdDate = calendar.date(from: thirdDateComp)!
		XCTAssertFalse(localCachedFileInfo.isCurrentVersion(lastModifiedDateInCloud: thirdDate))
	}
}
