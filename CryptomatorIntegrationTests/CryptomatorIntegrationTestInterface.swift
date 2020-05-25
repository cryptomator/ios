//
//  CryptomatorIntegrationTestInterface.swift
//  CryptomatorIntegrationTests
//
//  Created by Philipp Schmid on 29.04.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import XCTest
@testable import Promises
class CryptomatorIntegrationTestInterface: XCTestCase {
	var authentication: MockCloudAuthentication!
	var provider: CloudProvider!
	var remoteRootURLForIntegrationTest: URL!
	private static var remoteTestFolderURL: URL!
	private static var remoteSubFolderURL: URL!
	private static let testContentForFilesInRoot = "testContent"
	private static let testContentForFilesInTestFolder = "File inside Folder Content"
	class var setUpProvider: CloudProvider {
		fatalError("Not implemented")
	}

	class var setUpAuthentication: MockCloudAuthentication {
		fatalError("Not implemented")
	}

	class var remoteRootURLForIntegrationTest: URL {
		fatalError("Not implemented")
	}

	// MARK: Dirty Hack to notify about error in one time setup

	class var setUpError: Error? {
		get {
			fatalError("Not implemented")
		}
		set {}
	}

	override class func setUp() {
		let setUpPromise = setUpForIntegrationTest(at: setUpProvider, authentication: setUpAuthentication, remoteRootURLForIntegrationTest: remoteRootURLForIntegrationTest)

		// MARK: use waitForPromises as expectations are not available here. Therefore we can't catch the error from the promise above. And we need to check for an error later

		guard waitForPromises(timeout: 60.0) else {
			setUpError = IntegrationTestError.oneTimeSetUpTimeout
			return
		}
		if let error = setUpPromise.error {
			setUpError = error
		}
	}

	/**
	 Initial setup for the integration tests

	  Creates the following integration Test Structure at the cloud provider:
	 ````
	 └─ remoteURLForIntegrationTest
	     ├─ testFolder
	     │	├─ Sub Folder
	     │	├─ test 0.txt
	     │	├─ test 1.txt
	     │	├─ test 2.txt
	     │	├─ test 3.txt
	     │	└─ test 4.txt
	     ├─ test 0.txt
	     ├─ test 1.txt
	     ├─ test 2.txt
	     ├─ test 3.txt
	     └─ test 4.txt
	 ````
	 */
	class func setUpForIntegrationTest(at provider: CloudProvider, authentication: MockCloudAuthentication, remoteRootURLForIntegrationTest: URL) -> Promise<Void> {
		let tempDirectory = FileManager.default.temporaryDirectory
		let currentTestTempDirectory = tempDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)

		// Folders
		remoteTestFolderURL = remoteRootURLForIntegrationTest.appendingPathComponent("testFolder", isDirectory: true)
		remoteSubFolderURL = remoteTestFolderURL.appendingPathComponent("Sub Folder", isDirectory: true)

		let localSubFolderURL = currentTestTempDirectory.appendPathComponents(from: remoteSubFolderURL)

		// FileURLs
		let remoteRootFileURLs = createTestFileURLs(in: remoteRootURLForIntegrationTest)
		let remoteTestFolderFileURLs = createTestFileURLs(in: remoteTestFolderURL)
		do {
			try FileManager.default.createDirectory(at: localSubFolderURL, withIntermediateDirectories: true, attributes: nil)

			for remoteFileURL in remoteRootFileURLs {
				try testContentForFilesInRoot.write(to: currentTestTempDirectory.appendPathComponents(from: remoteFileURL), atomically: true, encoding: .utf8)
			}

			for remoteFileURL in remoteTestFolderFileURLs {
				try testContentForFilesInTestFolder.write(to: currentTestTempDirectory.appendPathComponents(from: remoteFileURL), atomically: true, encoding: .utf8)
			}
		} catch {
			return Promise(error)
		}
		return authentication.authenticate().then {
			provider.deleteIfExists(at: remoteRootURLForIntegrationTest)
		}.then {
			provider.createFolderWithIntermediates(for: remoteSubFolderURL)
		}.then {
			all(remoteRootFileURLs.map { provider.uploadFile(from: currentTestTempDirectory.appendPathComponents(from: $0), to: $0, isUpdate: false, progress: nil) })
		}.then { _ in
			all(remoteTestFolderFileURLs.map { provider.uploadFile(from: currentTestTempDirectory.appendPathComponents(from: $0), to: $0, isUpdate: false, progress: nil) })
		}.then { _ in
			try FileManager.default.removeItem(at: currentTestTempDirectory)
		}
	}

	override class func tearDown() {
		_ = setUpProvider.deleteItem(at: remoteRootURLForIntegrationTest)
		_ = waitForPromises(timeout: 60.0)
	}

	private class func createTestFileURLs(in folderURL: URL, filename: String = "test", fileExtension: String = "txt", amount: Int = 5) -> [URL] {
		precondition(folderURL.hasDirectoryPath)
		precondition(fileExtension.prefix(1) != ".")
		var fileURLs = [URL]()
		for i in 0 ..< amount {
			let fileURL = folderURL.appendingPathComponent("\(filename) \(i).\(fileExtension)", isDirectory: false)
			fileURLs.append(fileURL)
		}
		return fileURLs
	}

	// ensures that the tests of this interface only apply to implementations and not to the interface itself
	override class var defaultTestSuite: XCTestSuite {
		XCTestSuite(name: "InterfaceTests Excluded")
	}

	func testFetchItemMetadataForFile() throws {
		let fileURL = remoteRootURLForIntegrationTest.appendingPathComponent("test 0.txt", isDirectory: false)
		let expectation = XCTestExpectation(description: "fetchItemMetadataForFile")
		authentication.authenticate().then {
			self.provider.fetchItemMetadata(at: fileURL)
		}.then { metadata in
			XCTAssertEqual("test 0.txt", metadata.name)
			XCTAssertEqual(fileURL, metadata.remoteURL)
			XCTAssertEqual(CloudItemType.file, metadata.itemType)
			expectation.fulfill()
		}.catch { error in
			XCTFail(error.localizedDescription)
		}
		wait(for: [expectation], timeout: 60.0)
	}

	func testFetchItemMetadataForFolder() throws {
		let folderURL = remoteRootURLForIntegrationTest.appendingPathComponent("testFolder/", isDirectory: true)
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
		let nonexistentFileURL = remoteRootURLForIntegrationTest.appendingPathComponent("thisFileMustNotExist.pdf", isDirectory: false)
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
		let nonexistentFolderURL = remoteRootURLForIntegrationTest.appendingPathComponent("thisFolderMustNotExist/", isDirectory: true)
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
		let fileURL = remoteRootURLForIntegrationTest.appendingPathComponent("testFolder/test 0.txt", isDirectory: false)
		authentication.authenticate().then {
			self.provider.fetchItemMetadata(at: fileURL)
		}.then { metadata in
			XCTAssertEqual("test 0.txt", metadata.name)
			XCTAssertEqual(fileURL, metadata.remoteURL)
			XCTAssertEqual(CloudItemType.file, metadata.itemType)
			expectation.fulfill()
		}.catch { error in
			XCTFail(error.localizedDescription)
		}
		wait(for: [expectation], timeout: 60.0)
	}

	func testFetchItemMetadataForFolderFromSubFolder() throws {
		let folderURL = remoteRootURLForIntegrationTest.appendingPathComponent("testFolder/Sub Folder", isDirectory: true)
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
		let fileURL = remoteRootURLForIntegrationTest.appendingPathComponent("test 0.txt", isDirectory: false)
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
		let folderURL = remoteRootURLForIntegrationTest.appendingPathComponent("testFolder/", isDirectory: true)
		let expectation = XCTestExpectation(description: "fetchItemList")
		let expectedItems = [
			CloudItemMetadata(name: "Sub Folder", remoteURL: folderURL.appendingPathComponent("Sub Folder", isDirectory: true), itemType: .folder, lastModifiedDate: nil, size: nil),
			CloudItemMetadata(name: "test 0.txt", remoteURL: folderURL.appendingPathComponent("test 0.txt", isDirectory: false), itemType: .file, lastModifiedDate: nil, size: nil),
			CloudItemMetadata(name: "test 1.txt", remoteURL: folderURL.appendingPathComponent("test 1.txt", isDirectory: false), itemType: .file, lastModifiedDate: nil, size: nil),
			CloudItemMetadata(name: "test 2.txt", remoteURL: folderURL.appendingPathComponent("test 2.txt", isDirectory: false), itemType: .file, lastModifiedDate: nil, size: nil),
			CloudItemMetadata(name: "test 3.txt", remoteURL: folderURL.appendingPathComponent("test 3.txt", isDirectory: false), itemType: .file, lastModifiedDate: nil, size: nil),
			CloudItemMetadata(name: "test 4.txt", remoteURL: folderURL.appendingPathComponent("test 4.txt", isDirectory: false), itemType: .file, lastModifiedDate: nil, size: nil)
		]
		authentication.authenticate().then {
			self.provider.fetchItemList(forFolderAt: folderURL, withPageToken: nil)
		}.then { retrievedItemList in
			let retrievedSortedItems = retrievedItemList.items.sorted()
			XCTAssertNil(retrievedItemList.nextPageToken)
			XCTAssertEqual(expectedItems, retrievedSortedItems)
			expectation.fulfill()
		}.catch { error in
			XCTFail(error.localizedDescription)
		}
		wait(for: [expectation], timeout: 60.0)
	}

	func testFetchItemListFailWithItemNotFoundWhenFolderDoesNotExists() throws {
		let expectation = XCTestExpectation(description: "fetchItemList fail with CloudProviderError.itemNotFound when the folder does not exists")
		let nonexistentFolderURL = remoteRootURLForIntegrationTest.appendingPathComponent("thisFolderMustNotExist/", isDirectory: true)
		authentication.authenticate().then {
			self.provider.fetchItemList(forFolderAt: nonexistentFolderURL, withPageToken: nil)
		}.then { _ in
			XCTFail("fetchItemList fulfilled for nonexistent Folder")
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
		let folderURL = remoteRootURLForIntegrationTest.appendingPathComponent("testFolder/", isDirectory: true)
		let expectation = XCTestExpectation(description: "unauthorized fetchItemList fail with CloudProviderError.unauthorized")
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

	func testDownloadFile() throws {
		let filename = "test 0.txt"
		let expectedFileContent = CryptomatorIntegrationTestInterface.testContentForFilesInRoot

		let remoteFileURL = remoteRootURLForIntegrationTest.appendingPathComponent(filename, isDirectory: false)
		let expectedMetadata = CloudItemMetadata(name: filename, remoteURL: remoteFileURL, itemType: .file, lastModifiedDate: nil, size: nil)

		let tempDirectory = FileManager.default.temporaryDirectory
		let uniqueTempFolderURL = tempDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: uniqueTempFolderURL, withIntermediateDirectories: false, attributes: nil)
		let localFileURL = uniqueTempFolderURL.appendingPathComponent(filename, isDirectory: false)
		let expectation = XCTestExpectation(description: "downloadFile")
		authentication.authenticate().then {
			self.provider.downloadFile(from: remoteFileURL, to: localFileURL, progress: nil)
		}.then { actualMetadata in
			XCTAssertEqual(expectedMetadata, actualMetadata)
			let actualFileContent = try String(contentsOf: localFileURL)
			XCTAssertEqual(expectedFileContent, actualFileContent)
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 60.0)
		try FileManager.default.removeItem(at: uniqueTempFolderURL)
	}

	func testDownloadFileInSubFolder() throws {
		let filename = "test 0.txt"
		let expectedFileContent = CryptomatorIntegrationTestInterface.testContentForFilesInTestFolder

		let remoteFileURL = remoteRootURLForIntegrationTest.appendingPathComponent("testFolder/test 0.txt", isDirectory: false)
		let expectedMetadata = CloudItemMetadata(name: filename, remoteURL: remoteFileURL, itemType: .file, lastModifiedDate: nil, size: nil)

		let tempDirectory = FileManager.default.temporaryDirectory
		let uniqueTempFolderURL = tempDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: uniqueTempFolderURL, withIntermediateDirectories: false, attributes: nil)
		let localFileURL = uniqueTempFolderURL.appendingPathComponent(filename, isDirectory: false)
		let expectation = XCTestExpectation(description: "downloadFile")
		authentication.authenticate().then {
			self.provider.downloadFile(from: remoteFileURL, to: localFileURL, progress: nil)
		}.then { actualMetadata in
			XCTAssertEqual(expectedMetadata, actualMetadata)
			let actualFileContent = try String(contentsOf: localFileURL)
			XCTAssertEqual(expectedFileContent, actualFileContent)
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 60.0)
		try FileManager.default.removeItem(at: uniqueTempFolderURL)
	}

	func testDownloadFileFailWithItemNotFoundWhenFileNotExistAtCloudProvider() throws {
		let filename = "thisFileMustNotExist.txt"

		let remoteFileURL = remoteRootURLForIntegrationTest.appendingPathComponent(filename, isDirectory: false)
		let tempDirectory = FileManager.default.temporaryDirectory
		let uniqueTempFolderURL = tempDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: uniqueTempFolderURL, withIntermediateDirectories: false, attributes: nil)
		let localFileURL = uniqueTempFolderURL.appendingPathComponent(filename, isDirectory: false)
		let expectation = XCTestExpectation(description: "downloadFile fail with CloudProviderError.itemNotFound")
		authentication.authenticate().then {
			self.provider.downloadFile(from: remoteFileURL, to: localFileURL, progress: nil)
		}.then { _ in
			XCTFail("downloadFile fulfilled although the file does not exist at the cloud provider")
		}.catch { error in
			if case CloudProviderError.itemNotFound = error {
				expectation.fulfill()
			} else {
				XCTFail(error.localizedDescription)
			}
		}
		wait(for: [expectation], timeout: 60.0)
		try FileManager.default.removeItem(at: uniqueTempFolderURL)
	}

	func testDownloadFileFailWithItemAlreadyExsitsWhenFileExistsLocally() throws {
		let filename = "test 0.txt"
		let remoteFileURL = remoteRootURLForIntegrationTest.appendingPathComponent(filename, isDirectory: false)
		let tempDirectory = FileManager.default.temporaryDirectory
		let uniqueTempFolderURL = tempDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: uniqueTempFolderURL, withIntermediateDirectories: false, attributes: nil)
		let localFileURL = uniqueTempFolderURL.appendingPathComponent(filename, isDirectory: false)
		let emptyFileContent = ""
		try emptyFileContent.write(to: localFileURL, atomically: true, encoding: .utf8)
		let expectation = XCTestExpectation(description: "downloadFile fail with CloudProviderError.itemAlreadyExists")
		authentication.authenticate().then {
			self.provider.downloadFile(from: remoteFileURL, to: localFileURL, progress: nil)
		}.then { _ in
			XCTFail("downloadFile fulfilled although the file does already exists locally")
		}.catch { error in
			if case CloudProviderError.itemAlreadyExists = error {
				expectation.fulfill()
			} else {
				XCTFail(error.localizedDescription)
			}
		}
		wait(for: [expectation], timeout: 60.0)
		try FileManager.default.removeItem(at: uniqueTempFolderURL)
	}

	func testUnauthorizedDownloadFileFailWithCloudProviderErrorUnauthorized() throws {
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
			if case CloudProviderError.unauthorized = error {
				expectation.fulfill()
			} else {
				XCTFail(error.localizedDescription)
			}
		}
		wait(for: [expectation], timeout: 60.0)
		try FileManager.default.removeItem(at: uniqueTempFolderURL)
	}

	func testUploadFileFailWithCloudProviderErrorItemNotFoundWhenLocalFileDoesNotExist() throws {
		let tempDirectory = FileManager.default.temporaryDirectory
		let uniqueTempFolderURL = tempDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		let nonExistentLocalFileURL = uniqueTempFolderURL.appendingPathComponent("nonExistentFile.txt", isDirectory: false)
		let remoteURL = CryptomatorIntegrationTestInterface.remoteSubFolderURL.appendingPathComponent("nonExistentFile.txt", isDirectory: false)
		let expectation = XCTestExpectation(description: "uploadFile fail with CloudProviderError.itemNotFound when localFile does not exists")
		authentication.authenticate().then {
			self.provider.uploadFile(from: nonExistentLocalFileURL, to: remoteURL, isUpdate: false, progress: nil)
		}.then { _ in
			XCTFail("uploadFile fulfilled although the file to be uploaded does not exist locally")
		}.catch { error in
			if case CloudProviderError.itemNotFound = error {
				expectation.fulfill()
			} else {
				XCTFail(error.localizedDescription)
			}
		}
		wait(for: [expectation], timeout: 60.0)
	}

	func testUploadFileFailWithCloudProviderErrorItemAlreadyExistsWhenRemoteFileAlreadyExistAndNoUpdate() throws {
		let tempDirectory = FileManager.default.temporaryDirectory
		let uniqueTempFolderURL = tempDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		let localFileURL = uniqueTempFolderURL.appendingPathComponent("test 0.txt", isDirectory: false)
		let testContent = CryptomatorIntegrationTestInterface.testContentForFilesInTestFolder
		try FileManager.default.createDirectory(at: uniqueTempFolderURL, withIntermediateDirectories: true, attributes: nil)
		try testContent.write(to: localFileURL, atomically: true, encoding: .utf8)
		let remoteURL = CryptomatorIntegrationTestInterface.remoteTestFolderURL.appendingPathComponent("test 0.txt", isDirectory: false)

		let expectation = XCTestExpectation(description: "uploadFile fail with CloudProviderError.itemNotFound when remoteFile already exists and !isUpdate")

		authentication.authenticate().then {
			self.provider.uploadFile(from: localFileURL, to: remoteURL, isUpdate: false, progress: nil)
		}.then { _ in
			XCTFail("uploadFile fulfilled although the remote file already exists and !isUpdate")
		}.catch { error in
			if case CloudProviderError.itemAlreadyExists = error {
				expectation.fulfill()
			} else {
				XCTFail(error.localizedDescription)
			}
		}
		wait(for: [expectation], timeout: 60.0)
		try FileManager.default.removeItem(at: uniqueTempFolderURL)
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

extension CloudProvider {
	func deleteIfExists(at remoteURL: URL) -> Promise<Void> {
		return Promise(on: .global()) { fulfill, reject in
			do {
				try await(self.deleteItem(at: remoteURL))
			} catch {
				guard case CloudProviderError.itemNotFound = error else {
					reject(error)
					return
				}
			}
			fulfill(())
		}
	}

	func createFolderWithIntermediates(for remoteURL: URL) -> Promise<Void> {
		var urls = remoteURL.getPartialURLs(startIndex: 2)
		urls.append(remoteURL)
		return Promise(on: .global()) { fulfill, reject in
			for url in urls {
				do {
					try (await(self.createFolder(at: url)))
				} catch {
					guard case CloudProviderError.itemAlreadyExists = error else {
						reject(error)
						return
					}
				}
			}
			fulfill(())
		}
	}
}
