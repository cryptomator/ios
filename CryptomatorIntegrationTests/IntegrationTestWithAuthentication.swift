//
//  IntegrationTestWithAuthentication.swift
//  CryptomatorIntegrationTests
//
//  Created by Philipp Schmid on 16.06.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import XCTest
@testable import Promises
class IntegrationTestWithAuthentication: CryptomatorIntegrationTestInterface {
	
	func testFetchItemMetadataFailWithUnauthorizedWhenNotAuthorized() throws {
		let fileURL = remoteRootURLForIntegrationTest.appendingPathComponent("test 0.txt", isDirectory: false)
		let expectation = XCTestExpectation(description: "fetchItemMetadataForFile")
		provider.fetchItemMetadata(at: fileURL).then { _ in
			XCTFail("fetchItemMetadata fulfilled without authentication")
		}.catch { error in
			guard case CloudProviderError.unauthorized = error else {
				XCTFail(error.localizedDescription)
				return
			}
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 60.0)
	}

	func testFetchItemListFailWithUnauthorizedWhenNotAuthorized() throws {
		let folderURL = remoteRootURLForIntegrationTest.appendingPathComponent("testFolder/", isDirectory: true)
		let expectation = XCTestExpectation(description: "unauthorized fetchItemList fail with CloudProviderError.unauthorized")
		provider.fetchItemList(forFolderAt: folderURL, withPageToken: nil).then { _ in
			XCTFail("fetchItemList fulfilled without authentication")
		}.catch { error in
			guard case CloudProviderError.unauthorized = error else {
				XCTFail(error.localizedDescription)
				return
			}
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 60.0)
	}
	
	func testDownloadFileFailWithUnauthorizedWhenNotAuthorized() throws {
		let filename = "test 0.txt"
		let remoteFileURL = remoteRootURLForIntegrationTest.appendingPathComponent(filename, isDirectory: false)
		let tempDirectory = FileManager.default.temporaryDirectory
		let uniqueTempFolderURL = tempDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: uniqueTempFolderURL, withIntermediateDirectories: false, attributes: nil)
		let localFileURL = uniqueTempFolderURL.appendingPathComponent(filename, isDirectory: false)
		let expectation = XCTestExpectation(description: "unauthorized downloadFile fail with CloudProviderError.unauthorized")
		provider.downloadFile(from: remoteFileURL, to: localFileURL, progress: nil).then { _ in
			XCTFail("downloadFile fulfilled without authentication")
		}.catch { error in
			guard case CloudProviderError.unauthorized = error else {
				XCTFail(error.localizedDescription)
				return
			}
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 60.0)
		try FileManager.default.removeItem(at: uniqueTempFolderURL)
	}

	func testUploadFileFailWithUnauthorizedWhenNotAuthorized() throws {
		let tempDirectory = FileManager.default.temporaryDirectory
		let uniqueTempFolderURL = tempDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		let localFileURL = uniqueTempFolderURL.appendingPathComponent("test 5.txt", isDirectory: false)
		let testContent = CryptomatorIntegrationTestInterface.testContentForFilesInTestFolder
		try FileManager.default.createDirectory(at: uniqueTempFolderURL, withIntermediateDirectories: true, attributes: nil)
		try testContent.write(to: localFileURL, atomically: true, encoding: .utf8)
		let remoteURL = CryptomatorIntegrationTestInterface.remoteTestFolderURL.appendingPathComponent("test 5.txt", isDirectory: false)

		let expectation = XCTestExpectation(description: "unauthorized uploadFile fail with CloudProviderError.unauthorized")
		provider.uploadFile(from: localFileURL, to: remoteURL, replaceExisting: false, progress: nil).then { _ in
			XCTFail("uploadFile fulfilled without authentication")
		}.catch { error in
			guard case CloudProviderError.unauthorized = error else {
				XCTFail(error.localizedDescription)
				return
			}
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 60.0)
		try FileManager.default.removeItem(at: uniqueTempFolderURL)
	}

	func testCreateFolderFailWithUnauthorizedWhenNotAuthorized() throws {
		let remoteURL = CryptomatorIntegrationTestInterface.remoteEmptySubFolderURL.appendingPathComponent("unauthorizedFolder/", isDirectory: true)
		let expectation = XCTestExpectation(description: "unauthorized createFolder fail with CloudProviderError.unauthorized")
		provider.createFolder(at: remoteURL).then { _ in
			XCTFail("createFolder fulfilled without authentication")
		}.catch { error in
			guard case CloudProviderError.unauthorized = error else {
				XCTFail(error.localizedDescription)
				return
			}
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 60.0)
	}
	
    func testDeleteItemFailWithUnauthorizedWhenNotAuthorized() throws {
		let remoteURL = CryptomatorIntegrationTestInterface.remoteEmptySubFolderURL.appendingPathComponent("unauthorizedFolder/", isDirectory: true)
		let expectation = XCTestExpectation(description: "unauthorized deleteItem fail with CloudProviderError.unauthorized")
		provider.deleteItem(at: remoteURL).then { _ in
			XCTFail("deleteItem fulfilled without authentication")
		}.catch { error in
			guard case CloudProviderError.unauthorized = error else {
				XCTFail(error.localizedDescription)
				return
			}
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 60.0)
	}

	func testMoveItemFailWithUnauthorizedWhenNotAuthorized() throws {
		let remoteURL = CryptomatorIntegrationTestInterface.remoteEmptySubFolderURL.appendingPathComponent("unauthorizedFolder/", isDirectory: true)
		let newRemoteURL = CryptomatorIntegrationTestInterface.remoteEmptySubFolderURL.appendingPathComponent("unauthorizedFolderAA/", isDirectory: true)
		let expectation = XCTestExpectation(description: "unauthorized moveItem fail with CloudProviderError.unauthorized")
		provider.moveItem(from: remoteURL, to: newRemoteURL).then { _ in
			XCTFail("moveItem fulfilled without authentication")
		}.catch { error in
			guard case CloudProviderError.unauthorized = error else {
				XCTFail(error.localizedDescription)
				return
			}
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 60.0)
	}

}
