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
	// MARK: Enumerate Working Set

	func testWorkingSetReturnsEmptyItemList() {
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
