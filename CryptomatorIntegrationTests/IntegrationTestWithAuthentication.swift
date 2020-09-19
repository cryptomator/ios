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
	func deauthenticate() -> Promise<Void> {
		fatalError("Not implemented")
	}

	func testFetchItemMetadataFailWithUnauthorizedWhenNotAuthorized() throws {
		let fileCloudPath = type(of: self).rootCloudPathForIntegrationTest.appendingPathComponent("test 0.txt")
		let expectation = XCTestExpectation(description: "fetchItemMetadataForFile")
		deauthenticate().then {
			self.provider.fetchItemMetadata(at: fileCloudPath)
		}.then { _ in
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
		let folderCloudPath = type(of: self).rootCloudPathForIntegrationTest.appendingPathComponent("testFolder/")
		let expectation = XCTestExpectation(description: "unauthorized fetchItemList fail with CloudProviderError.unauthorized")
		deauthenticate().then {
			self.provider.fetchItemList(forFolderAt: folderCloudPath, withPageToken: nil)
		}.then { _ in
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
		let fileCloudPath = type(of: self).rootCloudPathForIntegrationTest.appendingPathComponent(filename)
		let tempDirectory = FileManager.default.temporaryDirectory
		let uniqueTempFolderURL = tempDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: uniqueTempFolderURL, withIntermediateDirectories: false, attributes: nil)
		let localFileURL = uniqueTempFolderURL.appendingPathComponent(filename, isDirectory: false)
		let expectation = XCTestExpectation(description: "unauthorized downloadFile fail with CloudProviderError.unauthorized")
		deauthenticate().then {
			self.provider.downloadFile(from: fileCloudPath, to: localFileURL)
		}.then { _ in
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
		let fileCloudPath = CryptomatorIntegrationTestInterface.testFolderCloudPath.appendingPathComponent("test 5.txt")

		let expectation = XCTestExpectation(description: "unauthorized uploadFile fail with CloudProviderError.unauthorized")
		deauthenticate().then {
			self.provider.uploadFile(from: localFileURL, to: fileCloudPath, replaceExisting: false)
		}.then { _ in
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
		let folderCloudPath = CryptomatorIntegrationTestInterface.emptySubFolderCloudPath.appendingPathComponent("unauthorizedFolder/")
		let expectation = XCTestExpectation(description: "unauthorized createFolder fail with CloudProviderError.unauthorized")
		deauthenticate().then {
			self.provider.createFolder(at: folderCloudPath)
		}.then { _ in
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

	func testDeleteFileFailWithUnauthorizedWhenNotAuthorized() throws {
		let folderCloudPath = CryptomatorIntegrationTestInterface.emptySubFolderCloudPath.appendingPathComponent("unauthorizedFolder/")
		let expectation = XCTestExpectation(description: "unauthorized deleteFile fail with CloudProviderError.unauthorized")
		deauthenticate().then {
			self.provider.deleteFile(at: folderCloudPath)
		}.then { _ in
			XCTFail("deleteFile fulfilled without authentication")
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

	func testDeleteFolderFailWithUnauthorizedWhenNotAuthorized() throws {
		let folderCloudPath = CryptomatorIntegrationTestInterface.emptySubFolderCloudPath.appendingPathComponent("unauthorizedFolder/")
		let expectation = XCTestExpectation(description: "unauthorized deleteFolder fail with CloudProviderError.unauthorized")
		deauthenticate().then {
			self.provider.deleteFolder(at: folderCloudPath)
		}.then { _ in
			XCTFail("deleteFolder fulfilled without authentication")
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

	func testMoveFileFailWithUnauthorizedWhenNotAuthorized() throws {
		let folderCloudPath = CryptomatorIntegrationTestInterface.emptySubFolderCloudPath.appendingPathComponent("unauthorizedFolder/")
		let newFolderCloudPath = CryptomatorIntegrationTestInterface.emptySubFolderCloudPath.appendingPathComponent("unauthorizedFolderAA/")
		let expectation = XCTestExpectation(description: "unauthorized moveFile fail with CloudProviderError.unauthorized")
		deauthenticate().then {
			self.provider.moveFile(from: folderCloudPath, to: newFolderCloudPath)
		}.then { _ in
			XCTFail("moveFile fulfilled without authentication")
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

	func testMoveFolderFailWithUnauthorizedWhenNotAuthorized() throws {
		let folderCloudPath = CryptomatorIntegrationTestInterface.emptySubFolderCloudPath.appendingPathComponent("unauthorizedFolder/")
		let newFolderCloudPath = CryptomatorIntegrationTestInterface.emptySubFolderCloudPath.appendingPathComponent("unauthorizedFolderAA/")
		let expectation = XCTestExpectation(description: "unauthorized moveFolder fail with CloudProviderError.unauthorized")
		deauthenticate().then {
			self.provider.moveFolder(from: folderCloudPath, to: newFolderCloudPath)
		}.then { _ in
			XCTFail("moveFolder fulfilled without authentication")
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
