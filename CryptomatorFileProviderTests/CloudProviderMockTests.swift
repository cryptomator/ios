//
//  CloudProviderMockTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 01.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//
import Promises
import XCTest
@testable import CryptomatorCloudAccess

class CloudProviderMockTests: XCTestCase {
	var tmpDirURL: URL!

	override func setUpWithError() throws {
		tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: tmpDirURL, withIntermediateDirectories: true)
	}

	override func tearDownWithError() throws {
		try FileManager.default.removeItem(at: tmpDirURL)
	}

	func testRootContainsFiles() {
		let expectation = XCTestExpectation(description: "rootContainsFiles")
		let provider = CloudProviderMock()
		let url = URL(fileURLWithPath: "/", isDirectory: true)
		provider.fetchItemList(forFolderAt: url, withPageToken: nil).then { cloudItemList in
			XCTAssertEqual(5, cloudItemList.items.count)
			XCTAssertEqual("Directory 1", cloudItemList.items[0].name)
			XCTAssertEqual("File 1", cloudItemList.items[1].name)
			XCTAssertEqual("File 2", cloudItemList.items[2].name)
			XCTAssertEqual("File 3", cloudItemList.items[3].name)
			XCTAssertEqual("File 4", cloudItemList.items[4].name)
//			XCTAssertTrue(cloudItemList.items.contains(where: { $0.name == "Directory 1" }))
//			XCTAssertTrue(cloudItemList.items.contains(where: { $0.name == "File 1" }))
//			XCTAssertTrue(cloudItemList.items.contains(where: { $0.name == "File 2" }))
//			XCTAssertTrue(cloudItemList.items.contains(where: { $0.name == "File 3" }))
//			XCTAssertTrue(cloudItemList.items.contains(where: { $0.name == "File 4" }))
		}.catch { error in
			XCTFail("Error in promise: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testFile1LastModifiedDate() {
		let expectation = XCTestExpectation(description: "dir1FileContainsDirId")
		let provider = CloudProviderMock()
		let remoteURL = URL(fileURLWithPath: "/File 1", isDirectory: false)
		provider.fetchItemMetadata(at: remoteURL).then { metadata in
			XCTAssertEqual(.file, metadata.itemType)
			XCTAssertEqual(Date(timeIntervalSince1970: 0), metadata.lastModifiedDate)
		}.catch { error in
			XCTFail("Error in promise: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}
}
