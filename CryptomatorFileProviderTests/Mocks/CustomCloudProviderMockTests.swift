//
//  CustomCloudProviderMockTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 01.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import XCTest
@testable import CryptomatorCloudAccessCore

@MainActor
class CustomCloudProviderMockTests: XCTestCase {
	var tmpDirURL: URL!

	override func setUp() async throws {
		try await super.setUp()
		tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: tmpDirURL, withIntermediateDirectories: true)
	}

	override func tearDown() async throws {
		try FileManager.default.removeItem(at: tmpDirURL)
		try await super.tearDown()
	}

	func testRootContainsFiles() async throws {
		let provider = CustomCloudProviderMock()
		let rootCloudPath = CloudPath("/")
		let cloudItemList = try await provider.fetchItemList(forFolderAt: rootCloudPath, withPageToken: nil)
		XCTAssertEqual(5, cloudItemList.items.count)
		XCTAssertEqual("Directory 1", cloudItemList.items[0].name)
		XCTAssertEqual("File 1", cloudItemList.items[1].name)
		XCTAssertEqual("File 2", cloudItemList.items[2].name)
		XCTAssertEqual("File 3", cloudItemList.items[3].name)
		XCTAssertEqual("File 4", cloudItemList.items[4].name)
	}

	func testFile1LastModifiedDate() async throws {
		let provider = CustomCloudProviderMock()
		let cloudPath = CloudPath("/File 1")
		let metadata = try await provider.fetchItemMetadata(at: cloudPath)
		XCTAssertEqual(.file, metadata.itemType)
		XCTAssertEqual(Date(timeIntervalSince1970: 0), metadata.lastModifiedDate)
	}

	func testUploadFileSimulatedItemNotFoundError() async {
		await assertUploadFileFails(to: CloudPath("/itemNotFound.txt"), with: .itemNotFound)
	}

	func testUploadFileSimulatedItemAlreadyExistsError() async {
		await assertUploadFileFails(to: CloudPath("/itemAlreadyExists.txt"), with: .itemAlreadyExists)
	}

	func testUploadFileSimulatedQutoaInsufficientError() async {
		await assertUploadFileFails(to: CloudPath("/quotaInsufficient.txt"), with: .quotaInsufficient)
	}

	func testUploadFileNoInternetConnectionError() async {
		await assertUploadFileFails(to: CloudPath("/noInternetConnection.txt"), with: .noInternetConnection)
	}

	func testUploadFileUnauthorizedError() async {
		await assertUploadFileFails(to: CloudPath("/unauthorized.txt"), with: .unauthorized)
	}

	private func assertUploadFileFails(to cloudPath: CloudPath, with expectedError: CloudProviderError, file: StaticString = #filePath, line: UInt = #line) async {
		let provider = CustomCloudProviderMock()
		let localURL = tmpDirURL.appendingPathComponent("nonExistentFile", isDirectory: false)
		await XCTAssertThrowsAsyncError(try await provider.uploadFile(from: localURL, to: cloudPath, replaceExisting: false), file: file, line: line) { error in
			XCTAssertEqual(expectedError, error as? CloudProviderError, file: file, line: line)
		}
	}
}
