//
//  FileProviderAdapterSetFavoriteRankTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 24.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import XCTest
@testable import CryptomatorFileProvider

class FileProviderAdapterSetFavoriteRankTests: FileProviderAdapterTestCase {
	func testSetFavoriteRank() throws {
		let expectation = XCTestExpectation()
		metadataManagerMock.cachedMetadata[2] = ItemMetadata(id: 2, name: "Test", type: .folder, size: nil, parentID: 1, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/Test"), isPlaceholderItem: false, isCandidateForCacheCleanup: false, favoriteRank: nil, tagData: nil)
		let favoriteRank: NSNumber = 100
		let itemIdentifier = NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: 2)
		adapter.setFavoriteRank(favoriteRank, forItemIdentifier: itemIdentifier) { item, error in
			XCTAssertNil(error)
			XCTAssertEqual(favoriteRank, item?.favoriteRank)
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
		XCTAssertEqual(favoriteRank.int64Value, metadataManagerMock.setFavoriteRank[2])
	}
}
