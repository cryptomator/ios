//
//  FileProviderAdapterSetTagDataTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 24.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation
import XCTest
@testable import CryptomatorFileProvider

class FileProviderAdapterSetTagDataTests: FileProviderAdapterTestCase {
	let itemIdentifier = NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: 2)
	func testSetTagData() throws {
		let expectation = XCTestExpectation()
		metadataManagerMock.cachedMetadata[2] = ItemMetadata(id: 2, name: "Test", type: .file, size: nil, parentID: 1, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/Test"), isPlaceholderItem: false, isCandidateForCacheCleanup: false, favoriteRank: nil, tagData: nil)
		let tagData = "Foo".data(using: .utf8)!

		adapter.setTagData(tagData, forItemIdentifier: itemIdentifier) { item, error in
			XCTAssertNil(error)
			XCTAssertEqual(tagData, item?.tagData)
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
		XCTAssertEqual(tagData, metadataManagerMock.setTagData[2])
	}

	func testSetEmptyTagData() throws {
		let expectation = XCTestExpectation()
		metadataManagerMock.cachedMetadata[2] = ItemMetadata(id: 2, name: "Test", type: .file, size: nil, parentID: 1, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/Test"), isPlaceholderItem: false, isCandidateForCacheCleanup: false, favoriteRank: nil, tagData: nil)
		let emptyTagData = Data()
		adapter.setTagData(emptyTagData, forItemIdentifier: itemIdentifier) { item, error in
			XCTAssertNil(error)
			guard let item = item else {
				XCTFail("FileProviderItem is nil")
				return
			}
			let tagData: Data? = item.tagData ?? nil
			XCTAssertNil(tagData)
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
		XCTAssertNil(metadataManagerMock.setTagData[2] ?? nil)
	}
}
