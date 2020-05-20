//
//  CryptomatorIntegrationTestInterface.swift
//  CryptomatorIntegrationTests
//
//  Created by Philipp Schmid on 29.04.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import XCTest
class CryptomatorIntegrationTestInterface: XCTestCase {
	var authentication: MockCloudAuthentication!
	var provider: CloudProvider!
	var rootURLForIntegrationTest: URL!
	override func setUpWithError() throws {}

	// MARK: ensures that the tests of this interface only apply to implementations and not to the interface itself

	override class var defaultTestSuite: XCTestSuite {
		XCTestSuite(name: "InterfaceTests Excluded")
	}

	override func tearDownWithError() throws {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
	}

	func testFetchItemMetadataForFile() throws {
		let fileURL = rootURLForIntegrationTest.appendingPathComponent("test.txt", isDirectory: false)
		let expectation = XCTestExpectation(description: "fetchItemMetadataForFile")
		authentication.authenticate().then {
			self.provider.fetchItemMetadata(at: fileURL)
		}.then { metadata in
			XCTAssertEqual("test.txt", metadata.name)
			XCTAssertEqual(fileURL, metadata.remoteURL)
			XCTAssertEqual(CloudItemType.file, metadata.itemType)
			expectation.fulfill()
		}.catch { error in
			XCTFail(error.localizedDescription)
		}
		wait(for: [expectation], timeout: 60.0)
	}

	func testFetchItemMetadataForFolder() throws {
		let folderURL = rootURLForIntegrationTest.appendingPathComponent("testFolder/", isDirectory: true)
		let expectation = XCTestExpectation(description: "fetchItemMetadataForFolder")
		authentication.authenticate().then {
			self.provider.fetchItemMetadata(at: folderURL)
		}.then { metadata in
			XCTAssertEqual("testFolder", metadata.name)
			XCTAssertEqual(folderURL, metadata.remoteURL)
			XCTAssertEqual(CloudItemType.folder, metadata.itemType)
			expectation.fulfill()
		}.catch { error in
			XCTFail(error.localizedDescription)
		}
		wait(for: [expectation], timeout: 60.0)
	}

	func testFetchItemFailWithItemNotFoundWhenFileDoesNotExists() throws {
		let expectation = XCTestExpectation(description: "fetchItemMetadataForNonexistentFile")
		let nonexistentFileURL = rootURLForIntegrationTest.appendingPathComponent("thisFileMustNotExist.pdf", isDirectory: false)
		authentication.authenticate().then {
			self.provider.fetchItemMetadata(at: nonexistentFileURL)
		}.then { _ in
			XCTFail("Promise should not fulfill for nonexistent File")
		}.catch { error in
			if case CloudProviderError.itemNotFound = error {
				expectation.fulfill()
			} else {
				XCTFail("Promise rejected but with the wrong error: \(error)")
			}
		}
		wait(for: [expectation], timeout: 60.0)
	}

	func testFetchItemFailWithItemNotFoundWhenFolderDoesNotExists() throws {
		let expectation = XCTestExpectation(description: "fetchItemMetadataForNonexistentFolder")
		let nonexistentFolderURL = rootURLForIntegrationTest.appendingPathComponent("thisFolderMustNotExist/", isDirectory: true)
		authentication.authenticate().then {
			self.provider.fetchItemMetadata(at: nonexistentFolderURL)
		}.then { _ in
			XCTFail("Promise should not fulfill for nonexistent File")
		}.catch { error in
			if case CloudProviderError.itemNotFound = error {
				expectation.fulfill()
			} else {
				XCTFail("Promise rejected but with the wrong error: \(error)")
			}
		}
		wait(for: [expectation], timeout: 60.0)
	}

	func testFetchItemMetadataForFileFromSubFolder() throws {
		let expectation = XCTestExpectation(description: "fetchItemMetadataForFileFromSubFolder")
		let fileURL = rootURLForIntegrationTest.appendingPathComponent("testFolder/test.txt", isDirectory: false)
		authentication.authenticate().then {
			self.provider.fetchItemMetadata(at: fileURL)
		}.then { metadata in
			XCTAssertEqual("test.txt", metadata.name)
			XCTAssertEqual(fileURL, metadata.remoteURL)
			XCTAssertEqual(CloudItemType.file, metadata.itemType)
			expectation.fulfill()
		}.catch { error in
			XCTFail(error.localizedDescription)
		}
		wait(for: [expectation], timeout: 60.0)
	}

	func testFetchItemMetadataForFolderFromSubFolder() throws {
		let folderURL = rootURLForIntegrationTest.appendingPathComponent("testFolder/Sub Folder", isDirectory: true)
		let expectation = XCTestExpectation(description: "fetchItemMetadataForFolderFromSubFolder")
		authentication.authenticate().then {
			self.provider.fetchItemMetadata(at: folderURL)
		}.then { metadata in
			XCTAssertEqual("Sub Folder", metadata.name)
			XCTAssertEqual(folderURL, metadata.remoteURL)
			XCTAssertEqual(CloudItemType.folder, metadata.itemType)
			expectation.fulfill()
		}.catch { error in
			XCTFail(error.localizedDescription)
		}
		wait(for: [expectation], timeout: 60.0)
	}

	func testUnauthorizedFetchItemMetadataFailWithCloudProviderErrorUnauthorized() throws {
		let fileURL = rootURLForIntegrationTest.appendingPathComponent("test.txt", isDirectory: false)
		let expectation = XCTestExpectation(description: "fetchItemMetadataForFile")
		provider.fetchItemMetadata(at: fileURL).then { _ in
			XCTFail("fetchItemMetadata fulfilled without authentication")
		}.catch { error in
			if case CloudProviderError.unauthorized = error {
				expectation.fulfill()
			} else {
				XCTFail(error.localizedDescription)
			}
		}
		wait(for: [expectation], timeout: 60.0)
	}

	func testFetchItemList() throws {
		let folderURL = rootURLForIntegrationTest.appendingPathComponent("testFolder/", isDirectory: true)
		let expectation = XCTestExpectation(description: "fetchItemList")
		let expectedItems = [
			CloudItemMetadata(name: "Sub Folder", remoteURL: folderURL.appendingPathComponent("Sub Folder", isDirectory: true), itemType: .folder, lastModifiedDate: nil, size: nil),
			CloudItemMetadata(name: "test.txt", remoteURL: folderURL.appendingPathComponent("test.txt", isDirectory: false), itemType: .file, lastModifiedDate: nil, size: nil),
			CloudItemMetadata(name: "test1.txt", remoteURL: folderURL.appendingPathComponent("test1.txt", isDirectory: false), itemType: .file, lastModifiedDate: nil, size: nil),
			CloudItemMetadata(name: "test2.txt", remoteURL: folderURL.appendingPathComponent("test2.txt", isDirectory: false), itemType: .file, lastModifiedDate: nil, size: nil),
			CloudItemMetadata(name: "test3.txt", remoteURL: folderURL.appendingPathComponent("test3.txt", isDirectory: false), itemType: .file, lastModifiedDate: nil, size: nil),
			CloudItemMetadata(name: "test4.txt", remoteURL: folderURL.appendingPathComponent("test4.txt", isDirectory: false), itemType: .file, lastModifiedDate: nil, size: nil)
		]
		authentication.authenticate().then {
			self.provider.fetchItemList(forFolderAt: folderURL, withPageToken: nil)
		}.then { retrievedItemList in
			let retrievedSortedItems = retrievedItemList.items.sorted()
			XCTAssertEqual(expectedItems, retrievedSortedItems)
			expectation.fulfill()
		}.catch { error in
			XCTFail(error.localizedDescription)
		}
		wait(for: [expectation], timeout: 60.0)
	}

	func testFetchItemListFailWithItemNotFoundWhenFolderDoesNotExists() throws {
		let expectation = XCTestExpectation(description: "fetchItemListFailWithItemNotFoundWhenFolderDoesNotExists")
		let nonexistentFolderURL = rootURLForIntegrationTest.appendingPathComponent("thisFolderMustNotExist/", isDirectory: true)
		authentication.authenticate().then {
			self.provider.fetchItemList(forFolderAt: nonexistentFolderURL, withPageToken: nil)
		}.then { _ in
			XCTFail("Promise should not fulfill for nonexistent Folder")
		}.catch { error in
			if case CloudProviderError.itemNotFound = error {
				expectation.fulfill()
			} else {
				XCTFail("Promise rejected but with the wrong error: \(error)")
			}
		}
		wait(for: [expectation], timeout: 60.0)
	}

	func testUnauthorizedFetchItemListFailWithCloudProviderErrorUnauthorized() throws {
		let folderURL = rootURLForIntegrationTest.appendingPathComponent("testFolder/", isDirectory: true)
		let expectation = XCTestExpectation(description: "unauthorizedFetchItemListFailWithCloudProviderErrorUnauthorized")
		provider.fetchItemList(forFolderAt: folderURL, withPageToken: nil).then { _ in
			XCTFail("fetchItemList fulfilled without authentication")
		}.catch { error in
			if case CloudProviderError.unauthorized = error {
				expectation.fulfill()
			} else {
				XCTFail(error.localizedDescription)
			}
		}
		wait(for: [expectation], timeout: 60.0)
	}
}

extension CloudItemMetadata: Comparable {
	public static func < (lhs: CloudItemMetadata, rhs: CloudItemMetadata) -> Bool {
		return lhs.name < rhs.name
	}

	public static func == (lhs: CloudItemMetadata, rhs: CloudItemMetadata) -> Bool {
		return lhs.name == rhs.name && lhs.remoteURL == rhs.remoteURL
	}
}
