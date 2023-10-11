//
//  CustomCloudProviderMockTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 01.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Promises
import XCTest
@testable import CryptomatorCloudAccessCore

class CustomCloudProviderMockTests: XCTestCase {
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
		let provider = CustomCloudProviderMock()
		let rootCloudPath = CloudPath("/")
		provider.fetchItemList(forFolderAt: rootCloudPath, withPageToken: nil).then { cloudItemList in
			XCTAssertEqual(5, cloudItemList.items.count)
			XCTAssertEqual("Directory 1", cloudItemList.items[0].name)
			XCTAssertEqual("File 1", cloudItemList.items[1].name)
			XCTAssertEqual("File 2", cloudItemList.items[2].name)
			XCTAssertEqual("File 3", cloudItemList.items[3].name)
			XCTAssertEqual("File 4", cloudItemList.items[4].name)
		}.catch { error in
			XCTFail("Error in promise: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testFile1LastModifiedDate() {
		let expectation = XCTestExpectation(description: "dir1FileContainsDirId")
		let provider = CustomCloudProviderMock()
		let cloudPath = CloudPath("/File 1")
		provider.fetchItemMetadata(at: cloudPath).then { metadata in
			XCTAssertEqual(.file, metadata.itemType)
			XCTAssertEqual(Date(timeIntervalSince1970: 0), metadata.lastModifiedDate)
		}.catch { error in
			XCTFail("Error in promise: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testUploadFileSimulatedItemNotFoundError() {
		let itemNotFoundExpectation = XCTestExpectation(description: "provider throw CloudProviderError.itemNotFound")
		let provider = CustomCloudProviderMock()
		let localURL = tmpDirURL.appendingPathComponent("nonExistentFile", isDirectory: false)
		let cloudPathForItemNotFound = CloudPath("/itemNotFound.txt")

		provider.uploadFile(from: localURL, to: cloudPathForItemNotFound, replaceExisting: false).then { _ in
			XCTFail("Promise fulfilled")
		}.catch { error in
			guard case CloudProviderError.itemNotFound = error else {
				XCTFail("Promise rejected with wrong error: \(error)")
				return
			}
		}.always {
			itemNotFoundExpectation.fulfill()
		}
		wait(for: [itemNotFoundExpectation], timeout: 1.0)
	}

	func testUploadFileSimulatedItemAlreadyExistsError() {
		let itemAlreadyExistsExpectation = XCTestExpectation(description: "provider throw CloudProviderError.itemAlreadyExists")
		let provider = CustomCloudProviderMock()
		let localURL = tmpDirURL.appendingPathComponent("nonExistentFile", isDirectory: false)
		let cloudPathForItemAlreadyExists = CloudPath("/itemAlreadyExists.txt")

		provider.uploadFile(from: localURL, to: cloudPathForItemAlreadyExists, replaceExisting: false).then { _ in
			XCTFail("Promise fulfilled")
		}.catch { error in
			guard case CloudProviderError.itemAlreadyExists = error else {
				XCTFail("Promise rejected with wrong error: \(error)")
				return
			}
		}.always {
			itemAlreadyExistsExpectation.fulfill()
		}
		wait(for: [itemAlreadyExistsExpectation], timeout: 1.0)
	}

	func testUploadFileSimulatedQutoaInsufficientError() {
		let quotaInsufficientExpectation = XCTestExpectation(description: "provider throw CloudProviderError.quotaInsufficient")
		let provider = CustomCloudProviderMock()
		let localURL = tmpDirURL.appendingPathComponent("nonExistentFile", isDirectory: false)
		let cloudPathForQuotaInsufficient = CloudPath("/quotaInsufficient.txt")

		provider.uploadFile(from: localURL, to: cloudPathForQuotaInsufficient, replaceExisting: false).then { _ in
			XCTFail("Promise fulfilled")
		}.catch { error in
			guard case CloudProviderError.quotaInsufficient = error else {
				XCTFail("Promise rejected with wrong error: \(error)")
				return
			}
		}.always {
			quotaInsufficientExpectation.fulfill()
		}
		wait(for: [quotaInsufficientExpectation], timeout: 1.0)
	}

	func testUploadFileNoInternetConnectionError() {
		let noInternetConnectionExpectation = XCTestExpectation(description: "provider throw CloudProviderError.noInternetConnection")
		let provider = CustomCloudProviderMock()
		let localURL = tmpDirURL.appendingPathComponent("nonExistentFile", isDirectory: false)
		let cloudPathForNoInternetConnection = CloudPath("/noInternetConnection.txt")

		provider.uploadFile(from: localURL, to: cloudPathForNoInternetConnection, replaceExisting: false).then { _ in
			XCTFail("Promise fulfilled")
		}.catch { error in
			guard case CloudProviderError.noInternetConnection = error else {
				XCTFail("Promise rejected with wrong error: \(error)")
				return
			}
		}.always {
			noInternetConnectionExpectation.fulfill()
		}
		wait(for: [noInternetConnectionExpectation], timeout: 1.0)
	}

	func testUploadFileUnauthorizedError() {
		let unauthorizedExpectation = XCTestExpectation(description: "provider throw CloudProviderError.unauthorized")
		let provider = CustomCloudProviderMock()
		let localURL = tmpDirURL.appendingPathComponent("nonExistentFile", isDirectory: false)
		let cloudPathForUnauthorized = CloudPath("/unauthorized.txt")

		provider.uploadFile(from: localURL, to: cloudPathForUnauthorized, replaceExisting: false).then { _ in
			XCTFail("Promise fulfilled")
		}.catch { error in
			guard case CloudProviderError.unauthorized = error else {
				XCTFail("Promise rejected with wrong error: \(error)")
				return
			}
		}.always {
			unauthorizedExpectation.fulfill()
		}
		wait(for: [unauthorizedExpectation], timeout: 1.0)
	}
}
