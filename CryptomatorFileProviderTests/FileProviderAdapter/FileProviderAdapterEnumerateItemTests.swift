//
//  FileProviderAdapterEnumerateItemTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 08.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import XCTest
@testable import CryptomatorFileProvider

class FileProviderAdapterEnumerateItemTests: FileProviderAdapterTestCase {
	override func setUpWithError() throws {
		try super.setUpWithError()
		uploadTaskManagerMock.getCorrespondingTaskRecordsIdsClosure = {
			return $0.map { _ in nil }
		}
	}

	// MARK: Enumerate Working Set

	func testWorkingSet() {
		let mockMetadata = [
			ItemMetadata(id: 2, name: "Test", type: .file, size: nil, parentID: 1, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/Test"), isPlaceholderItem: false, isCandidateForCacheCleanup: false, favoriteRank: nil, tagData: Data()),
			ItemMetadata(id: 3, name: "TestFolder", type: .file, size: nil, parentID: 4, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/Foo/TestFolder"), isPlaceholderItem: false, isCandidateForCacheCleanup: false, favoriteRank: 1, tagData: nil)
		]
		metadataManagerMock.workingSetMetadata = mockMetadata
		let expectation = XCTestExpectation()
		adapter.enumerateItems(for: .workingSet, withPageToken: nil).then { itemList in
			XCTAssertEqual(mockMetadata.map { FileProviderItem(metadata: $0) }, itemList.items)
			XCTAssertNil(itemList.nextPageToken)
		}.catch { error in
			XCTFail("Error in promise: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testEmptyWorkingSet() {
		let expectation = XCTestExpectation()
		adapter.enumerateItems(for: .workingSet, withPageToken: nil).then { itemList in
			XCTAssert(itemList.items.isEmpty)
			XCTAssertNil(itemList.nextPageToken)
		}.catch { error in
			XCTFail("Error in promise: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testWorkingSetReturnsEmptyItemListWithPageTokenSet() {
		let expectation = XCTestExpectation()
		adapter.enumerateItems(for: .workingSet, withPageToken: "PageToken").then { itemList in
			XCTAssert(itemList.items.isEmpty)
			XCTAssertNil(itemList.nextPageToken)
		}.catch { error in
			XCTFail("Error in promise: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}
}
