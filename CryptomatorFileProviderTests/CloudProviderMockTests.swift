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

	func testUploadFileSimulatedErrors() {
		let itemNotFoundExpectation = XCTestExpectation(description: "provider throw CloudProviderError.itemNotFound")
		let provider = CloudProviderMock()
		let localURL = tmpDirURL.appendingPathComponent("nonExistentFile", isDirectory: false)
		let remoteURLForItemNotFound = URL(fileURLWithPath: "/itemNotFound.txt", isDirectory: false)

		provider.uploadFile(from: localURL, to: remoteURLForItemNotFound, replaceExisting: false).then { _ in
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
		let itemAlreadyExistsExpectation = XCTestExpectation(description: "provider throw CloudProviderError.itemAlreadyExists")
		let remoteURLForItemAlreadyExists = URL(fileURLWithPath: "/itemAlreadyExists.txt", isDirectory: false)
		provider.uploadFile(from: localURL, to: remoteURLForItemAlreadyExists, replaceExisting: false).then { _ in
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

		let quotaInsufficientExpectation = XCTestExpectation(description: "provider throw CloudProviderError.quotaInsufficient")
		let remoteURLForQuotaInsufficient = URL(fileURLWithPath: "/quotaInsufficient.txt", isDirectory: false)
		provider.uploadFile(from: localURL, to: remoteURLForQuotaInsufficient, replaceExisting: false).then { _ in
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

		let noInternetConnectionExpectation = XCTestExpectation(description: "provider throw CloudProviderError.noInternetConnection")
		let remoteURLForNoInternetConnection = URL(fileURLWithPath: "/noInternetConnection.txt", isDirectory: false)
		provider.uploadFile(from: localURL, to: remoteURLForNoInternetConnection, replaceExisting: false).then { _ in
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

		let unauthorizedExpectation = XCTestExpectation(description: "provider throw CloudProviderError.unauthorized")
		let remoteURLForUnauthorized = URL(fileURLWithPath: "/unauthorized.txt", isDirectory: false)
		provider.uploadFile(from: localURL, to: remoteURLForUnauthorized, replaceExisting: false).then { _ in
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
