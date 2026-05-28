//
//  FileProviderAdapterStartProvidingCoalescingTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Tobias Hagemann on 28.05.26.
//  Copyright © 2026 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Promises
import XCTest
@testable import CryptomatorFileProvider

class FileProviderAdapterStartProvidingCoalescingTests: FileProviderAdapterTestCase {
	private let itemID: Int64 = 2
	private let cloudPath = CloudPath("/File 1")
	private lazy var itemMetadata = ItemMetadata(id: itemID, name: "File 1", type: .file, size: 14, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false)
	private lazy var itemDirectory = tmpDirectory.appendingPathComponent("/\(itemID)")
	private lazy var url = itemDirectory.appendingPathComponent("File 1")

	private let otherItemID: Int64 = 3
	private let otherCloudPath = CloudPath("/File 2")
	private lazy var otherItemMetadata = ItemMetadata(id: otherItemID, name: "File 2", type: .file, size: 14, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: otherCloudPath, isPlaceholderItem: false)
	private lazy var otherItemDirectory = tmpDirectory.appendingPathComponent("/\(otherItemID)")
	private lazy var otherURL = otherItemDirectory.appendingPathComponent("File 2")

	override func setUpWithError() throws {
		try super.setUpWithError()
		try metadataManagerMock.cacheMetadata(itemMetadata)
		try FileManager.default.createDirectory(at: itemDirectory, withIntermediateDirectories: false)
		try metadataManagerMock.cacheMetadata(otherItemMetadata)
		try FileManager.default.createDirectory(at: otherItemDirectory, withIntermediateDirectories: false)
	}

	// MARK: - Same-identifier coalescing

	func testConcurrentCallsForSameIdentifierAreCoalesced() {
		cloudProviderMock.pendingDownloadPromise = Promise<Void>.pending()

		let expectation1 = XCTestExpectation(description: "first completion handler fires")
		let expectation2 = XCTestExpectation(description: "second completion handler fires")

		adapter.startProvidingItem(at: url) { error in
			XCTAssertNil(error)
			expectation1.fulfill()
		}
		adapter.startProvidingItem(at: url) { error in
			XCTAssertNil(error)
			expectation2.fulfill()
		}

		cloudProviderMock.pendingDownloadPromise?.fulfill(())

		wait(for: [expectation1, expectation2], timeout: 5.0)

		XCTAssertEqual(1, cloudProviderMock.downloadFileCallsCount)
	}

	func testConcurrentCallsForSameIdentifierFanOutSharedRejection() {
		cloudProviderMock.pendingDownloadPromise = Promise<Void>.pending()

		let expectation1 = XCTestExpectation(description: "first completion handler fires")
		let expectation2 = XCTestExpectation(description: "second completion handler fires")

		var error1: Error?
		var error2: Error?
		adapter.startProvidingItem(at: url) { error in
			error1 = error
			expectation1.fulfill()
		}
		adapter.startProvidingItem(at: url) { error in
			error2 = error
			expectation2.fulfill()
		}

		cloudProviderMock.pendingDownloadPromise?.reject(CloudProviderError.unauthorized)

		wait(for: [expectation1, expectation2], timeout: 5.0)

		XCTAssertEqual(1, cloudProviderMock.downloadFileCallsCount)
		XCTAssertNotNil(error1)
		XCTAssertNotNil(error2)
		XCTAssertEqual((error1 as NSError?)?.domain, (error2 as NSError?)?.domain)
		XCTAssertEqual((error1 as NSError?)?.code, (error2 as NSError?)?.code)
	}

	// MARK: - Cache cleanup after settlement

	func testRejectedCallClearsCacheSoSubsequentCallTriggersFreshDownload() {
		cloudProviderMock.pendingDownloadPromise = Promise<Void>.pending()

		let expectation1 = XCTestExpectation(description: "first completion handler fires")
		adapter.startProvidingItem(at: url) { _ in
			expectation1.fulfill()
		}

		cloudProviderMock.pendingDownloadPromise?.reject(CloudProviderError.unauthorized)
		wait(for: [expectation1], timeout: 5.0)

		cloudProviderMock.pendingDownloadPromise = nil

		let expectation2 = XCTestExpectation(description: "second completion handler fires")
		adapter.startProvidingItem(at: url) { _ in
			expectation2.fulfill()
		}
		wait(for: [expectation2], timeout: 5.0)

		XCTAssertEqual(2, cloudProviderMock.downloadFileCallsCount)
	}

	func testResolvedCallClearsCacheSoSubsequentCallIssuesNewRequest() throws {
		cloudProviderMock.pendingDownloadPromise = Promise<Void>.pending()

		let expectation1 = XCTestExpectation(description: "first completion handler fires")
		adapter.startProvidingItem(at: url) { _ in
			expectation1.fulfill()
		}

		cloudProviderMock.pendingDownloadPromise?.fulfill(())
		wait(for: [expectation1], timeout: 5.0)

		cloudProviderMock.pendingDownloadPromise = nil
		try FileManager.default.removeItem(at: url)

		let expectation2 = XCTestExpectation(description: "second completion handler fires")
		adapter.startProvidingItem(at: url) { _ in
			expectation2.fulfill()
		}
		wait(for: [expectation2], timeout: 5.0)

		XCTAssertEqual(2, cloudProviderMock.downloadFileCallsCount)
	}

	// MARK: - Cross-identifier independence

	func testConcurrentCallsForDifferentIdentifiersExecuteIndependently() {
		let expectation1 = XCTestExpectation(description: "first item's completion handler fires")
		let expectation2 = XCTestExpectation(description: "second item's completion handler fires")

		adapter.startProvidingItem(at: url) { error in
			XCTAssertNil(error)
			expectation1.fulfill()
		}
		adapter.startProvidingItem(at: otherURL) { error in
			XCTAssertNil(error)
			expectation2.fulfill()
		}

		wait(for: [expectation1, expectation2], timeout: 5.0)

		XCTAssertEqual(2, cloudProviderMock.downloadFileCallsCount)
	}
}
