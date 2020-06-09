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
	private static var remoteEmptySubFolderURL: URL!
	private static var remoteFolderForMoveItemsURL: URL!
	private static var remoteFolderForDeleteItemsURL: URL!
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

	class var classSetUpError: Error? {
		get {
			fatalError("Not implemented")
		}
		set {}
	}

	override func setUpWithError() throws {
		if let error = type(of: self).classSetUpError {
			throw error
		}
	}

	override class func setUp() {
		let setUpPromise = setUpForIntegrationTest(at: setUpProvider, authentication: setUpAuthentication, remoteRootURLForIntegrationTest: remoteRootURLForIntegrationTest)

		// MARK: use waitForPromises as expectations are not available here. Therefore we can't catch the error from the promise above. And we need to check for an error later

		guard waitForPromises(timeout: 60.0) else {
			classSetUpError = IntegrationTestError.oneTimeSetUpTimeout
			return
		}
		if let error = setUpPromise.error {
			classSetUpError = error
		}
	}

	/**
	 Initial setup for the integration tests

	  Creates the following integration Test Structure at the cloud provider:
	 ````
	 └─ remoteURLForIntegrationTest
	 ├─ testFolder
	 │	├─ Empty Sub Folder
	 │	├─ FolderForDeleteItems
	 │	│  ├─ FolderToDelete
	 │	│  ├─ FileForItemTypeMismatch
	 │	│  ├─ FolderForItemTypeMismatch
	 │	│  └─ FileToDelete
	 │	├─ FolderForMoveItems
	 │	│  ├─ MoveItemsInThisFolder
	 │	│  ├─ FolderToRename
	 │	│  ├─ FileToRename
	 │	│  ├─ FileForItemTypeMismatch
	 │	│  ├─ FolderForItemTypeMismatch
	 │	│  ├─ FileForItemAlreadyExists
	 │	│  ├─ FolderForItemAlreadyExists
	 │	│  ├─ FileForParentFolderDoesNotExist
	 │	│  ├─ FolderForParentFolderDoesNotExist
	 │	│  ├─ FolderToMove
	 │	│  └─ FileToMove
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
	class func setUpForIntegrationTest(at _: CloudProvider, authentication: MockCloudAuthentication, remoteRootURLForIntegrationTest: URL) -> Promise<Void> {
		let tempDirectory = FileManager.default.temporaryDirectory
		let currentTestTempDirectory = tempDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)

		remoteTestFolderURL = remoteRootURLForIntegrationTest.appendingPathComponent("testFolder", isDirectory: true)
		remoteEmptySubFolderURL = remoteTestFolderURL.appendingPathComponent("Empty Sub Folder", isDirectory: true)
		remoteFolderForDeleteItemsURL = remoteTestFolderURL.appendingPathComponent("FolderForDeleteItems", isDirectory: true)
		remoteFolderForMoveItemsURL = remoteTestFolderURL.appendingPathComponent("FolderForMoveItems", isDirectory: true)
		let remoteFolderToDeleteURL = remoteFolderForDeleteItemsURL.appendingPathComponent("FolderToDelete", isDirectory: true)
		let remoteFolderToMoveURL = remoteFolderForMoveItemsURL.appendingPathComponent("FolderToMove", isDirectory: true)

		return authentication.authenticate().then {
			setUpProvider.deleteItemIfExists(at: remoteRootURLForIntegrationTest)
		}.then {
			setUpProvider.createFolderWithIntermediates(for: remoteRootURLForIntegrationTest)
		}.then {
			createRootFolderContent(localCurrentTestTempDirectory: currentTestTempDirectory)
		}.then {
			createTestFolderContent(localCurrentTestTempDirectory: currentTestTempDirectory)
		}.then {
			createFolderForDeleteItemsContent(localCurrentTestTempDirectory: currentTestTempDirectory, remoteFolderToDeleteURL: remoteFolderToDeleteURL)
		}.then {
			createFolderForMoveItemsContent(localCurrentTestTempDirectory: currentTestTempDirectory, remoteFolderToMoveURL: remoteFolderToMoveURL)
		}.then { _ in
			try FileManager.default.removeItem(at: currentTestTempDirectory)
		}
	}

	private class func createRootFolderContent(localCurrentTestTempDirectory: URL) -> Promise<Void> {
		let remoteRootFileURLs = createTestFileURLs(in: remoteRootURLForIntegrationTest)
		let localTestFolderURL = localCurrentTestTempDirectory.appendPathComponents(from: remoteTestFolderURL)
		do {
			try FileManager.default.createDirectory(at: localTestFolderURL, withIntermediateDirectories: true, attributes: nil)
			for remoteFileURL in remoteRootFileURLs {
				try testContentForFilesInRoot.write(to: localCurrentTestTempDirectory.appendPathComponents(from: remoteFileURL), atomically: true, encoding: .utf8)
			}
		} catch {
			return Promise(error)
		}
		return all(remoteRootFileURLs.map { setUpProvider.uploadFile(from: localCurrentTestTempDirectory.appendPathComponents(from: $0), to: $0, isUpdate: false, progress: nil) }).then { _ in
			setUpProvider.createFolder(at: remoteTestFolderURL)
		}
	}

	private class func createTestFolderContent(localCurrentTestTempDirectory: URL) -> Promise<Void> {
		let remoteTestFolderFileURLs = createTestFileURLs(in: remoteTestFolderURL)

		let localFolderToDeleteURL = localCurrentTestTempDirectory.appendPathComponents(from: remoteFolderForDeleteItemsURL)
		let localFolderToMoveURL = localCurrentTestTempDirectory.appendPathComponents(from: remoteFolderForMoveItemsURL)
		do {
			try FileManager.default.createDirectory(at: localFolderToDeleteURL, withIntermediateDirectories: false, attributes: nil)
			try FileManager.default.createDirectory(at: localFolderToMoveURL, withIntermediateDirectories: false, attributes: nil)
			for remoteFileURL in remoteTestFolderFileURLs {
				try testContentForFilesInTestFolder.write(to: localCurrentTestTempDirectory.appendPathComponents(from: remoteFileURL), atomically: true, encoding: .utf8)
			}
		} catch {
			return Promise(error)
		}
		return all(remoteTestFolderFileURLs.map { setUpProvider.uploadFile(from: localCurrentTestTempDirectory.appendPathComponents(from: $0), to: $0, isUpdate: false, progress: nil) }).then { _ in
			setUpProvider.createFolder(at: remoteEmptySubFolderURL)
		}.then {
			setUpProvider.createFolder(at: remoteFolderForDeleteItemsURL)
		}.then {
			setUpProvider.createFolder(at: remoteFolderForMoveItemsURL)
		}
	}

	private class func createFolderForDeleteItemsContent(localCurrentTestTempDirectory: URL, remoteFolderToDeleteURL: URL) -> Promise<Void> {
		let remoteFileToDeleteURL = remoteFolderForDeleteItemsURL.appendingPathComponent("FileToDelete", isDirectory: false)
		let remoteFileForItemTypeMismatchURL = remoteFolderForDeleteItemsURL.appendingPathComponent("FileForItemTypeMismatch", isDirectory: false)
		let remoteFolderForItemTypeMismatchURL = remoteFolderForDeleteItemsURL.appendingPathComponent("FolderForItemTypeMismatch", isDirectory: true)

		let localFileToDeleteURL = localCurrentTestTempDirectory.appendPathComponents(from: remoteFileToDeleteURL)
		let localFileForItemTypeMismatchURL = localCurrentTestTempDirectory.appendPathComponents(from: remoteFileForItemTypeMismatchURL)
		let emptyTestContent = "AAAAAAAAAAAAAAAAAAAAAAAAAABBBBBBABABABABABBABABABBABABABABABAB"

		do {
			try emptyTestContent.write(to: localFileToDeleteURL, atomically: true, encoding: .utf8)
			try emptyTestContent.write(to: localFileForItemTypeMismatchURL, atomically: true, encoding: .utf8)
		} catch {
			return Promise(error)
		}
		return setUpProvider.uploadFile(from: localFileToDeleteURL, to: remoteFileToDeleteURL, isUpdate: false, progress: nil).then { _ in
			setUpProvider.uploadFile(from: localFileForItemTypeMismatchURL, to: remoteFileForItemTypeMismatchURL, isUpdate: false, progress: nil)
		}.then { _ in
			setUpProvider.createFolder(at: remoteFolderToDeleteURL)
		}.then {
			setUpProvider.createFolder(at: remoteFolderForItemTypeMismatchURL)
		}
	}

	private class func createFolderForMoveItemsContent(localCurrentTestTempDirectory: URL, remoteFolderToMoveURL: URL) -> Promise<Void> {
		let remoteMoveItemsInThisFolderURL = remoteFolderForMoveItemsURL.appendingPathComponent("MoveItemsInThisFolder", isDirectory: true)
		let remoteFileToMoveURL = remoteFolderForMoveItemsURL.appendingPathComponent("FileToMove", isDirectory: false)
		let remoteFileToRenameURL = remoteFolderForMoveItemsURL.appendingPathComponent("FileToRename", isDirectory: false)
		let remoteFolderToRenameURL = remoteFolderForMoveItemsURL.appendingPathComponent("FolderToRename", isDirectory: true)
		let remoteFileForItemTypeMismatchURL = remoteFolderForMoveItemsURL.appendingPathComponent("FileForItemTypeMismatch", isDirectory: false)
		let remoteFolderForItemTypeMismatchURL = remoteFolderForMoveItemsURL.appendingPathComponent("FolderForItemTypeMismatch", isDirectory: true)
		let remoteFileForItemItemAlreadyExistsURL = remoteFolderForMoveItemsURL.appendingPathComponent("FileForItemAlreadyExists", isDirectory: false)
		let remoteFolderForItemAlreadyExistsURL = remoteFolderForMoveItemsURL.appendingPathComponent("FolderForItemAlreadyExists", isDirectory: true)
		let remoteFileForParentFolderDoesNotExist = remoteFolderForMoveItemsURL.appendingPathComponent("FileForParentFolderDoesNotExist", isDirectory: false)
		let remoteFolderForParentFolderDoesNotExist = remoteFolderForMoveItemsURL.appendingPathComponent("FolderForParentFolderDoesNotExist", isDirectory: true)
		let remoteFolders = [remoteFolderToRenameURL, remoteFolderToMoveURL, remoteMoveItemsInThisFolderURL, remoteFolderForItemTypeMismatchURL, remoteFolderForItemAlreadyExistsURL, remoteFolderForParentFolderDoesNotExist]
		let remoteFiles = [remoteFileToMoveURL, remoteFileToRenameURL, remoteFileForItemTypeMismatchURL, remoteFileForItemItemAlreadyExistsURL, remoteFileForParentFolderDoesNotExist]

		let emptyTestContent = "AAAAAAAAAAAAAAAAAAAAAAAAAABBBBBBABABABABABBABABABBABABABABABAB"

		do {
			for remoteFile in remoteFiles {
				let localFileURL = localCurrentTestTempDirectory.appendPathComponents(from: remoteFile)
				try emptyTestContent.write(to: localFileURL, atomically: true, encoding: .utf8)
			}
		} catch {
			return Promise(error)
		}
		return all(remoteFiles.map { setUpProvider.uploadFile(from: localCurrentTestTempDirectory.appendPathComponents(from: $0), to: $0, isUpdate: false, progress: nil) }).then { _ in
			all(remoteFolders.map { setUpProvider.createFolder(at: $0) })
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

	// MARK: fetchItemMetadata Tests

	func testFetchItemMetadataForFile() throws {
		let fileURL = remoteRootURLForIntegrationTest.appendingPathComponent("test 0.txt", isDirectory: false)
		let expectation = XCTestExpectation(description: "fetchItemMetadataForFile")
		authentication.authenticate().then {
			self.provider.fetchItemMetadata(at: fileURL)
		}.then { metadata in
			XCTAssertEqual("test 0.txt", metadata.name)
			XCTAssertEqual(fileURL, metadata.remoteURL)
			XCTAssertEqual(CloudItemType.file, metadata.itemType)
		}.catch { error in
			XCTFail(error.localizedDescription)
		}.always {
			expectation.fulfill()
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
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 60.0)
	}

	func testFetchItemMetadataFailWithItemNotFoundWhenFileDoesNotExists() throws {
		let expectation = XCTestExpectation(description: "fetchItemMetadataForNonexistentFile")
		let nonexistentFileURL = remoteRootURLForIntegrationTest.appendingPathComponent("thisFileMustNotExist.pdf", isDirectory: false)
		authentication.authenticate().then {
			self.provider.fetchItemMetadata(at: nonexistentFileURL)
		}.then { _ in
			XCTFail("Promise should not fulfill for nonexistent File")
		}.catch { error in
			guard case CloudProviderError.itemNotFound = error else {
				XCTFail("Promise rejected but with the wrong error: \(error)")
				return
			}
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 60.0)
	}

	func testFetchItemMetadataFailWithItemNotFoundWhenFolderDoesNotExists() throws {
		let expectation = XCTestExpectation(description: "fetchItemMetadataForNonexistentFolder")
		let nonexistentFolderURL = remoteRootURLForIntegrationTest.appendingPathComponent("thisFolderMustNotExist/", isDirectory: true)
		authentication.authenticate().then {
			self.provider.fetchItemMetadata(at: nonexistentFolderURL)
		}.then { _ in
			XCTFail("Promise should not fulfill for nonexistent File")
		}.catch { error in
			guard case CloudProviderError.itemNotFound = error else {
				XCTFail("Promise rejected but with the wrong error: \(error)")
				return
			}
		}.always {
			expectation.fulfill()
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
		}.catch { error in
			XCTFail(error.localizedDescription)
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 60.0)
	}

	func testFetchItemMetadataForFolderFromSubFolder() throws {
		let folderURL = CryptomatorIntegrationTestInterface.remoteEmptySubFolderURL!
		let expectation = XCTestExpectation(description: "fetchItemMetadataForFolderFromSubFolder")
		authentication.authenticate().then {
			self.provider.fetchItemMetadata(at: folderURL)
		}.then { metadata in
			XCTAssertEqual("Empty Sub Folder", metadata.name)
			XCTAssertEqual(folderURL, metadata.remoteURL)
			XCTAssertEqual(CloudItemType.folder, metadata.itemType)
			expectation.fulfill()
		}.catch { error in
			XCTFail(error.localizedDescription)
		}
		wait(for: [expectation], timeout: 60.0)
	}

	func testFetchItemMetadataFailWithItemTypeMismatchIfFileWithThisNameDoesNotExistsButAFolder() throws {
		let fileURL = remoteRootURLForIntegrationTest.appendingPathComponent("testFolder", isDirectory: false)
		let expectation = XCTestExpectation(description: "fetchItemMetadataForFile")
		authentication.authenticate().then {
			self.provider.fetchItemMetadata(at: fileURL)
		}.then { _ in
			XCTFail("fetchItemMetadata fulfilled although the file does not exist")
		}.catch { error in
			guard case CloudProviderError.itemTypeMismatch = error else {
				XCTFail(error.localizedDescription)
				return
			}
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 60.0)
	}

	func testFetchItemMetadataFailWithItemTypeMismatchIfFolderWithThisNameDoesNotExistsButAFile() throws {
		let folderURL = remoteRootURLForIntegrationTest.appendingPathComponent("test 0.txt", isDirectory: true)
		let expectation = XCTestExpectation(description: "fetchItemMetadataForFile")
		authentication.authenticate().then {
			self.provider.fetchItemMetadata(at: folderURL)
		}.then { _ in
			XCTFail("fetchItemMetadata fulfilled although the folder does not exist")
		}.catch { error in
			guard case CloudProviderError.itemTypeMismatch = error else {
				XCTFail(error.localizedDescription)
				return
			}
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 60.0)
	}

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

	// MARK: fetchItemList Tests

	func testFetchItemListFromRootFolder() throws {
		let folderURL = remoteRootURLForIntegrationTest!
		let expectation = XCTestExpectation(description: "fetchItemList")
		let expectedItems = [
			CloudItemMetadata(name: "test 0.txt", remoteURL: folderURL.appendingPathComponent("test 0.txt", isDirectory: false), itemType: .file, lastModifiedDate: nil, size: nil),
			CloudItemMetadata(name: "test 1.txt", remoteURL: folderURL.appendingPathComponent("test 1.txt", isDirectory: false), itemType: .file, lastModifiedDate: nil, size: nil),
			CloudItemMetadata(name: "test 2.txt", remoteURL: folderURL.appendingPathComponent("test 2.txt", isDirectory: false), itemType: .file, lastModifiedDate: nil, size: nil),
			CloudItemMetadata(name: "test 3.txt", remoteURL: folderURL.appendingPathComponent("test 3.txt", isDirectory: false), itemType: .file, lastModifiedDate: nil, size: nil),
			CloudItemMetadata(name: "test 4.txt", remoteURL: folderURL.appendingPathComponent("test 4.txt", isDirectory: false), itemType: .file, lastModifiedDate: nil, size: nil),
			CloudItemMetadata(name: "testFolder", remoteURL: CryptomatorIntegrationTestInterface.remoteTestFolderURL, itemType: .folder, lastModifiedDate: nil, size: nil)
		]
		authentication.authenticate().then {
			self.provider.fetchItemList(forFolderAt: folderURL, withPageToken: nil)
		}.then { retrievedItemList in
			let retrievedSortedItems = retrievedItemList.items.sorted()
			XCTAssertNil(retrievedItemList.nextPageToken)
			XCTAssertEqual(expectedItems, retrievedSortedItems)
		}.catch { error in
			XCTFail(error.localizedDescription)
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 60.0)
	}

	func testFetchItemListFromSubFolder() throws {
		let folderURL = remoteRootURLForIntegrationTest.appendingPathComponent("testFolder/", isDirectory: true)
		let expectation = XCTestExpectation(description: "fetchItemList")
		let expectedItems = [
			CloudItemMetadata(name: "Empty Sub Folder", remoteURL: CryptomatorIntegrationTestInterface.remoteEmptySubFolderURL, itemType: .folder, lastModifiedDate: nil, size: nil),
			CloudItemMetadata(name: "FolderForDeleteItems", remoteURL: CryptomatorIntegrationTestInterface.remoteFolderForDeleteItemsURL, itemType: .folder, lastModifiedDate: nil, size: nil),
			CloudItemMetadata(name: "FolderForMoveItems", remoteURL: CryptomatorIntegrationTestInterface.remoteFolderForMoveItemsURL, itemType: .folder, lastModifiedDate: nil, size: nil),
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
		}.catch { error in
			XCTFail(error.localizedDescription)
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 60.0)
	}

	func testFetchItemListInEmptyFolder() throws {
		let folderURL = CryptomatorIntegrationTestInterface.remoteEmptySubFolderURL!
		let expectation = XCTestExpectation(description: "fetchItemList in empty folder")
		let expectedItems = [CloudItemMetadata]()
		authentication.authenticate().then {
			self.provider.fetchItemList(forFolderAt: folderURL, withPageToken: nil)
		}.then { retrievedItemList in
			let retrievedSortedItems = retrievedItemList.items.sorted()
			XCTAssertNil(retrievedItemList.nextPageToken)
			XCTAssertEqual(expectedItems, retrievedSortedItems)
		}.catch { error in
			XCTFail(error.localizedDescription)
		}.always {
			expectation.fulfill()
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
			guard case CloudProviderError.itemNotFound = error else {
				XCTFail("Promise rejected but with the wrong error: \(error)")
				return
			}
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 60.0)
	}

	func testFetchItemListFailWithItemTypeMismatchIfFolderWithThisNameDoesNotExistsButAFile() throws {
		let folderURL = remoteRootURLForIntegrationTest.appendingPathComponent("test 0.txt", isDirectory: true)
		let expectation = XCTestExpectation(description: "fetchItemList fails with CloudProviderError.itemTypeMismatch")
		authentication.authenticate().then {
			self.provider.fetchItemList(forFolderAt: folderURL, withPageToken: nil)
		}.then { _ in
			XCTFail("fetchItemList fulfilled although the folder does not exist")
		}.catch { error in
			guard case CloudProviderError.itemTypeMismatch = error else {
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

	// MARK: downloadFile Tests

	func testDownloadFileFromRootFolder() throws {
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
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 60.0)
		try FileManager.default.removeItem(at: uniqueTempFolderURL)
	}

	func testDownloadFileFromSubFolder() throws {
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
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
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
			guard case CloudProviderError.itemNotFound = error else {
				XCTFail(error.localizedDescription)
				return
			}
		}.always {
			expectation.fulfill()
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
			guard case CloudProviderError.itemAlreadyExists = error else {
				XCTFail(error.localizedDescription)
				return
			}
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 60.0)
		try FileManager.default.removeItem(at: uniqueTempFolderURL)
	}

	func testDownloadFileFailWithItemTypeMismatchIfFileWithThisNameDoesNotExistsButAFolder() throws {
		let fileURL = remoteRootURLForIntegrationTest.appendingPathComponent("testFolder", isDirectory: false)
		let tempDirectory = FileManager.default.temporaryDirectory
		let uniqueTempFolderURL = tempDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: uniqueTempFolderURL, withIntermediateDirectories: false, attributes: nil)
		let localFileURL = uniqueTempFolderURL.appendingPathComponent("testFolder", isDirectory: false)
		let expectation = XCTestExpectation(description: "downloadFile fails with CloudProviderError.itemTypeMismatch")
		authentication.authenticate().then {
			self.provider.downloadFile(from: fileURL, to: localFileURL, progress: nil)
		}.then { _ in
			XCTFail("downloadFile fulfilled although the file does not exist")
		}.catch { error in
			guard case CloudProviderError.itemTypeMismatch = error else {
				XCTFail(error.localizedDescription)
				return
			}
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 60.0)
		try FileManager.default.removeItem(at: uniqueTempFolderURL)
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

	// MARK: uploadFile Tests

	func testUploadFileFailWithItemNotFoundWhenLocalFileDoesNotExist() throws {
		let tempDirectory = FileManager.default.temporaryDirectory
		let uniqueTempFolderURL = tempDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		let nonExistentLocalFileURL = uniqueTempFolderURL.appendingPathComponent("nonExistentFile.txt", isDirectory: false)
		let remoteURL = CryptomatorIntegrationTestInterface.remoteEmptySubFolderURL.appendingPathComponent("nonExistentFile.txt", isDirectory: false)
		let expectation = XCTestExpectation(description: "uploadFile fail with CloudProviderError.itemNotFound when localFile does not exists")
		authentication.authenticate().then {
			self.provider.uploadFile(from: nonExistentLocalFileURL, to: remoteURL, isUpdate: false, progress: nil)
		}.then { _ in
			XCTFail("uploadFile fulfilled although the file to be uploaded does not exist locally")
		}.catch { error in
			guard case CloudProviderError.itemNotFound = error else {
				XCTFail(error.localizedDescription)
				return
			}
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 60.0)
	}

	func testUploadFileFailWithItemAlreadyExistsWhenRemoteFileAlreadyExistAndNoUpdate() throws {
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
			guard case CloudProviderError.itemAlreadyExists = error else {
				XCTFail(error.localizedDescription)
				return
			}
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 60.0)
		try FileManager.default.removeItem(at: uniqueTempFolderURL)
	}

	func testUploadFileFailWithParentFolderDoesNotExistWhenParentFolderDoesNotExist() throws {
		let tempDirectory = FileManager.default.temporaryDirectory
		let uniqueTempFolderURL = tempDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		let localFileURL = uniqueTempFolderURL.appendingPathComponent("test 0.txt", isDirectory: false)
		let testContent = CryptomatorIntegrationTestInterface.testContentForFilesInTestFolder
		try FileManager.default.createDirectory(at: uniqueTempFolderURL, withIntermediateDirectories: true, attributes: nil)
		try testContent.write(to: localFileURL, atomically: true, encoding: .utf8)
		let remoteNonExistenFolderURL = CryptomatorIntegrationTestInterface.remoteTestFolderURL.appendingPathComponent("thisFolderMustNotExist/", isDirectory: true)
		let remoteURL = remoteNonExistenFolderURL.appendingPathComponent("test 0.txt", isDirectory: false)
		let expectation = XCTestExpectation(description: "uploadFile fail with CloudProviderError.parentFolderDoesNotExist when the parent folder in the remote URL does not exist")
		authentication.authenticate().then {
			self.provider.uploadFile(from: localFileURL, to: remoteURL, isUpdate: false, progress: nil)
		}.then { _ in
			XCTFail("uploadFile fulfilled although the parent folder of the remoteURL does not exist")
		}.catch { error in
			guard case CloudProviderError.parentFolderDoesNotExist = error else {
				XCTFail(error.localizedDescription)
				return
			}
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 60.0)
		try FileManager.default.removeItem(at: uniqueTempFolderURL)
	}

	func testUploadFileFailWithItemTypeMismatchIfFileWithThisNameDoesNotExistsButAFolder() throws {
		let remoteFileURL = remoteRootURLForIntegrationTest.appendingPathComponent("itemTypeMismatchFolder", isDirectory: false)
		let tempDirectory = FileManager.default.temporaryDirectory
		let uniqueTempFolderURL = tempDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		let localFileURL = uniqueTempFolderURL.appendingPathComponent("itemTypeMismatchFolder", isDirectory: false)
		try FileManager.default.createDirectory(at: localFileURL, withIntermediateDirectories: true, attributes: nil)

		let expectation = XCTestExpectation(description: "downloadFile fails with CloudProviderError.itemTypeMismatch")
		authentication.authenticate().then {
			self.provider.uploadFile(from: localFileURL, to: remoteFileURL, isUpdate: false, progress: nil)
		}.then { _ in
			XCTFail("uploadFile fulfilled although the file does not exist")
		}.catch { error in
			guard case CloudProviderError.itemTypeMismatch = error else {
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
		provider.uploadFile(from: localFileURL, to: remoteURL, isUpdate: false, progress: nil).then { _ in
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

	// MARK: createFolder Tests

	func testCreateFolderFailWithItemAlreadyExistsWhenAFolderAlreadyExists() throws {
		let remoteURL = CryptomatorIntegrationTestInterface.remoteEmptySubFolderURL!
		let expectation = XCTestExpectation(description: "createFolder fail with CloudProviderError.itemAlreadyExists when a folder already exists at the remoteURL")
		authentication.authenticate().then {
			self.provider.createFolder(at: remoteURL)
		}.then { _ in
			XCTFail("createFolder fulfilled although the folder of the remoteURL does already exist")
		}.catch { error in
			if case CloudProviderError.itemAlreadyExists = error {
				expectation.fulfill()
			} else {
				XCTFail(error.localizedDescription)
			}
		}
		wait(for: [expectation], timeout: 60.0)
	}

	func testCreateFolderFailWithItemAlreadyExistsWhenAFileAlreadyExists() throws {
		let remoteURL = remoteRootURLForIntegrationTest.appendingPathComponent("test 0.txt", isDirectory: true)
		let expectation = XCTestExpectation(description: "createFolder fail with CloudProviderError.itemAlreadyExists when a folder already exists at the remoteURL")
		authentication.authenticate().then {
			self.provider.createFolder(at: remoteURL)
		}.then { _ in
			XCTFail("createFolder fulfilled although the file of the remoteURL does already exist")
		}.catch { error in
			guard case CloudProviderError.itemAlreadyExists = error else {
				XCTFail(error.localizedDescription)
				return
			}
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 60.0)
	}

	func testCreateFolderFailWithParentFolderDoesNotExistWhenParentFolderDoesNotExist() throws {
		let nonexistentFolderURL = remoteRootURLForIntegrationTest.appendingPathComponent("thisFolderMustNotExist-AAA/", isDirectory: true)
		let remoteURL = nonexistentFolderURL.appendingPathComponent("folderToCreate/", isDirectory: true)
		let expectation = XCTestExpectation(description: "createFolder fail with CloudProviderError.itemAlreadyExists when a folder already exists at the remoteURL")
		authentication.authenticate().then {
			self.provider.createFolder(at: remoteURL)
		}.then { _ in
			XCTFail("createFolder fulfilled although the parent Folder of the remoteURL does not exist")
		}.catch { error in
			guard case CloudProviderError.parentFolderDoesNotExist = error else {
				XCTFail(error.localizedDescription)
				return
			}
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 60.0)
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

	// MARK: deleteItem Tests

	func testDeleteItemCanDeleteExistingFile() throws {
		let itemToDeleteURL = CryptomatorIntegrationTestInterface.remoteFolderForDeleteItemsURL.appendingPathComponent("FileToDelete", isDirectory: false)
		let expectation = XCTestExpectation(description: "deleteItem can delete existing file")
		authentication.authenticate().then {
			self.provider.deleteItem(at: itemToDeleteURL)
		}.then {
			self.provider.checkForItemExistence(at: itemToDeleteURL)
		}.then { fileExists in
			guard !fileExists else {
				XCTFail("File still exists in the cloud")
				return
			}
		}.catch { error in
			XCTFail(error.localizedDescription)
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 60.0)
	}

	func testDeleteItemCanDeleteExistingFolder() throws {
		let itemToDeleteURL = CryptomatorIntegrationTestInterface.remoteFolderForDeleteItemsURL.appendingPathComponent("FolderToDelete", isDirectory: true)
		let expectation = XCTestExpectation(description: "deleteItem can delete existing folder")
		authentication.authenticate().then {
			self.provider.deleteItem(at: itemToDeleteURL)
		}.then {
			self.provider.checkForItemExistence(at: itemToDeleteURL)
		}.then { folderExists in
			guard !folderExists else {
				XCTFail("Folder still exists in the cloud")
				return
			}
		}.catch { error in
			XCTFail(error.localizedDescription)
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 60.0)
	}

	func testDeleteItemFailWithItemNotFoundIfFileDoesNotExist() throws {
		let remoteNonExistentFileURL = CryptomatorIntegrationTestInterface.remoteFolderForDeleteItemsURL.appendingPathComponent("thisFileMustNotExist", isDirectory: false)
		let expectation = XCTestExpectation(description: "deleteItem fail with CloudProviderError.itemNotFound if the file to be deleted does not exist")
		authentication.authenticate().then {
			self.provider.deleteItem(at: remoteNonExistentFileURL)
		}.then {
			XCTFail("deleteItem fulfilled although the file to be deleted does not exist")
		}.catch { error in
			guard case CloudProviderError.itemNotFound = error else {
				XCTFail(error.localizedDescription)
				return
			}
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 60.0)
	}

	func testDeleteItemFailWithItemNotFoundIfFolderDoesNotExist() throws {
		let remoteNonExistentFolderURL = CryptomatorIntegrationTestInterface.remoteFolderForDeleteItemsURL.appendingPathComponent("thisFolderMustNotExist/", isDirectory: true)
		let expectation = XCTestExpectation(description: "deleteItem fail with CloudProviderError.itemNotFound if the folder to be deleted does not exist")
		authentication.authenticate().then {
			self.provider.deleteItem(at: remoteNonExistentFolderURL)
		}.then {
			XCTFail("deleteItem fulfilled although the folder to be deleted does not exist")
		}.catch { error in
			guard case CloudProviderError.itemNotFound = error else {
				XCTFail(error.localizedDescription)
				return
			}
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 60.0)
	}

	func testDeleteItemFailWithItemTypeMismatchIfFileWithThisNameDoesNotExistsButAFolder() throws {
		let remoteNonExistentFileURL = CryptomatorIntegrationTestInterface.remoteFolderForDeleteItemsURL.appendingPathComponent("FolderForItemTypeMismatch", isDirectory: false)
		let expectation = XCTestExpectation(description: "deleteItem fail with CloudProviderError.itemTypeMismatch ff the file to be deleted does not exist, but there is a folder in that location with the same name.")
		authentication.authenticate().then {
			self.provider.deleteItem(at: remoteNonExistentFileURL)
		}.then {
			XCTFail("deleteItem fulfilled although the file to be deleted does not exist")
		}.catch { error in
			guard case CloudProviderError.itemTypeMismatch = error else {
				XCTFail(error.localizedDescription)
				return
			}
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 60.0)
		let checkExpectation = XCTestExpectation(description: "deleteItem did not delete the folder with the same name because we wanted to delete a file")
		let remoteFolderURL = CryptomatorIntegrationTestInterface.remoteFolderForDeleteItemsURL.appendingPathComponent("FolderForItemTypeMismatch", isDirectory: true)
		provider.checkForItemExistence(at: remoteFolderURL).then { folderExists in
			guard folderExists else {
				XCTFail("deleteItem deleted the folder with the same name, although we wanted to delete a file")
				return
			}
		}.always {
			checkExpectation.fulfill()
		}
		wait(for: [checkExpectation], timeout: 60.0)
	}

	func testDeleteItemFailWithItemTypeMismatchIfFolderWithThisNameDoesNotExistsButAFile() throws {
		let remoteNonExistentFolderURL = CryptomatorIntegrationTestInterface.remoteFolderForDeleteItemsURL.appendingPathComponent("FileForItemTypeMismatch", isDirectory: true)
		let expectation = XCTestExpectation(description: "deleteItem fail with CloudProviderError.itemTypeMismatch if the folder to be deleted does not exist, but there is a file in that location with the same name.")
		authentication.authenticate().then {
			self.provider.deleteItem(at: remoteNonExistentFolderURL)
		}.then {
			XCTFail("deleteItem fulfilled although the folder to be deleted does not exist")
		}.catch { error in
			guard case CloudProviderError.itemTypeMismatch = error else {
				XCTFail(error.localizedDescription)
				return
			}
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 30.0)
		let checkExpectation = XCTestExpectation(description: "deleteItem did not delete the file with the same name because we wanted to delete a folder")
		let remoteFileURL = CryptomatorIntegrationTestInterface.remoteFolderForDeleteItemsURL.appendingPathComponent("FileForItemTypeMismatch", isDirectory: false)
		provider.checkForItemExistence(at: remoteFileURL).then { fileExists in
			guard fileExists else {
				XCTFail("deleteItem deleted the file with the same name, although we wanted to delete a folder")
				return
			}
		}.catch { error in
			XCTFail(error.localizedDescription)
		}.always {
			checkExpectation.fulfill()
		}
		wait(for: [checkExpectation], timeout: 30.0)
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

	// MARK: moveItem Tests

	func testMoveItemAsRenameWorksForFile() throws {
		let remoteFileToRenameURL = CryptomatorIntegrationTestInterface.remoteFolderForMoveItemsURL.appendingPathComponent("FileToRename", isDirectory: false)
		let newRemoteFileToRenameURL = CryptomatorIntegrationTestInterface.remoteFolderForMoveItemsURL.appendingPathComponent("RenamedFile", isDirectory: false)
		let expectation = XCTestExpectation(description: "moveItem works as rename for file")
		let remoteURLs = [remoteFileToRenameURL, newRemoteFileToRenameURL]
		authentication.authenticate().then {
			self.provider.moveItem(from: remoteFileToRenameURL, to: newRemoteFileToRenameURL)
		}.then {
			all(remoteURLs.map { self.provider.checkForItemExistence(at: $0) })
		}.then { itemsExist in
			let oldItemExist = itemsExist[0]
			let newItemExist = itemsExist[1]
			guard !oldItemExist, newItemExist else {
				XCTFail("moveItem did not move the file correctly")
				return
			}
		}.catch { error in
			XCTFail(error.localizedDescription)
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 20.0)
	}

	func testMoveItemAsRenameWorksForFolder() throws {
		let remoteFolderToRenameURL = CryptomatorIntegrationTestInterface.remoteFolderForMoveItemsURL.appendingPathComponent("FolderToRename", isDirectory: true)
		let newRemoteFolderToRenameURL = CryptomatorIntegrationTestInterface.remoteFolderForMoveItemsURL.appendingPathComponent("RenamedFolder", isDirectory: true)
		let expectation = XCTestExpectation(description: "moveItem works as rename for folder")
		let remoteURLs = [remoteFolderToRenameURL, newRemoteFolderToRenameURL]
		authentication.authenticate().then {
			self.provider.moveItem(from: remoteFolderToRenameURL, to: newRemoteFolderToRenameURL)
		}.then {
			all(remoteURLs.map { self.provider.checkForItemExistence(at: $0) })
		}.then { itemsExist in
			let oldItemExist = itemsExist[0]
			let newItemExist = itemsExist[1]
			guard !oldItemExist, newItemExist else {
				XCTFail("moveItem did not move the folder correctly")
				return
			}
		}.catch { error in
			XCTFail(error.localizedDescription)
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 60.0)
	}

	func testMoveItemWorksForFile() throws {
		let remoteFileToMoveURL = CryptomatorIntegrationTestInterface.remoteFolderForMoveItemsURL.appendingPathComponent("FileToMove", isDirectory: false)
		let newRemoteFileToMoveURL = CryptomatorIntegrationTestInterface.remoteFolderForMoveItemsURL.appendingPathComponent("MoveItemsInThisFolder/renamedAndMovedFile", isDirectory: false)
		let expectation = XCTestExpectation(description: "moveItem works for file")
		let remoteURLs = [remoteFileToMoveURL, newRemoteFileToMoveURL]
		authentication.authenticate().then {
			self.provider.moveItem(from: remoteFileToMoveURL, to: newRemoteFileToMoveURL)
		}.then {
			all(remoteURLs.map { self.provider.checkForItemExistence(at: $0) })
		}.then { itemsExist in
			let oldItemExist = itemsExist[0]
			let newItemExist = itemsExist[1]
			guard !oldItemExist, newItemExist else {
				XCTFail("moveItem did not move the file correctly")
				return
			}
		}.catch { error in
			XCTFail(error.localizedDescription)
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 60.0)
	}

	func testMoveItemWorksForFolder() throws {
		let remoteFileToMoveURL = CryptomatorIntegrationTestInterface.remoteFolderForMoveItemsURL.appendingPathComponent("FolderToMove", isDirectory: true)
		let newRemoteFileToMoveURL = CryptomatorIntegrationTestInterface.remoteFolderForMoveItemsURL.appendingPathComponent("MoveItemsInThisFolder/renamedAndMovedFolder/", isDirectory: true)
		let expectation = XCTestExpectation(description: "moveItem works for folder")
		let remoteURLs = [remoteFileToMoveURL, newRemoteFileToMoveURL]
		authentication.authenticate().then {
			self.provider.moveItem(from: remoteFileToMoveURL, to: newRemoteFileToMoveURL)
		}.then {
			all(remoteURLs.map { self.provider.checkForItemExistence(at: $0) })
		}.then { itemsExist in
			let oldItemExist = itemsExist[0]
			let newItemExist = itemsExist[1]
			guard !oldItemExist, newItemExist else {
				XCTFail("moveItem did not move the folder correctly")
				return
			}
		}.catch { error in
			XCTFail(error.localizedDescription)
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 60.0)
	}

	func testMoveItemFailWithItemNotFoundIfTheFileToMoveDoesNotExist() throws {
		let nonExistentFileToMoveURL = CryptomatorIntegrationTestInterface.remoteFolderForMoveItemsURL.appendingPathComponent("thisFileMustNotExist.pdf", isDirectory: false)
		let newRemoteFileToMoveURL = CryptomatorIntegrationTestInterface.remoteFolderForMoveItemsURL.appendingPathComponent("MoveItemsInThisFolder/thisFileMustNotExistRenamed.pdf", isDirectory: false)
		let expectation = XCTestExpectation(description: "moveItem fails with CloudProviderError.itemNotFound if the file to move does not exist")
		authentication.authenticate().then {
			self.provider.moveItem(from: nonExistentFileToMoveURL, to: newRemoteFileToMoveURL)
		}.then {
			XCTFail("moveItem fulfilled although the file to be moved does not exist")
		}.catch { error in
			guard case CloudProviderError.itemNotFound = error else {
				XCTFail(error.localizedDescription)
				return
			}
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 60.0)
	}

	func testMoveItemFailWithItemNotFoundIfTheFolderToMoveDoesNotExist() throws {
		let nonExistentFolderToMoveURL = CryptomatorIntegrationTestInterface.remoteFolderForMoveItemsURL.appendingPathComponent("thisFolderMustNotExist/", isDirectory: true)
		let newRemoteFileToMoveURL = CryptomatorIntegrationTestInterface.remoteFolderForMoveItemsURL.appendingPathComponent("MoveItemsInThisFolder/thisFolderMustNotExistRenamed/", isDirectory: true)
		let expectation = XCTestExpectation(description: "moveItem fails with CloudProviderError.itemNotFound if the file to move does not exist")
		authentication.authenticate().then {
			self.provider.moveItem(from: nonExistentFolderToMoveURL, to: newRemoteFileToMoveURL)
		}.then {
			XCTFail("moveItem fulfilled although the file to be moved does not exist")
		}.catch { error in
			guard case CloudProviderError.itemNotFound = error else {
				XCTFail(error.localizedDescription)
				return
			}
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 60.0)
	}

	func testMoveItemFailWithItemAlreadyExistsIfTheFileExistsAtTheTargetURL() throws {
		let fileToMoveURL = CryptomatorIntegrationTestInterface.remoteFolderForMoveItemsURL.appendingPathComponent("FileForItemAlreadyExists", isDirectory: false)
		let newRemoteFileToMoveURL = CryptomatorIntegrationTestInterface.remoteFolderForMoveItemsURL.appendingPathComponent("FileForItemTypeMismatch", isDirectory: false)
		let expectation = XCTestExpectation(description: "moveItem fails with CloudProviderError.itemAlreadyExists if a file already exists at the target URL")
		authentication.authenticate().then {
			self.provider.moveItem(from: fileToMoveURL, to: newRemoteFileToMoveURL)
		}.then {
			XCTFail("moveItem fulfilled although a file already exists at the target URL")
		}.catch { error in
			guard case CloudProviderError.itemAlreadyExists = error else {
				XCTFail(error.localizedDescription)
				return
			}
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 60.0)
	}

	func testMoveItemFailWithItemAlreadyExistsIfTheFolderExistsAtTheTargetURL() throws {
		let remoteFolderToMoveURL = CryptomatorIntegrationTestInterface.remoteFolderForMoveItemsURL.appendingPathComponent("FolderForItemAlreadyExists", isDirectory: true)
		let newRemoteFolderToMoveURL = CryptomatorIntegrationTestInterface.remoteFolderForMoveItemsURL.appendingPathComponent("FolderForItemTypeMismatch", isDirectory: true)
		let expectation = XCTestExpectation(description: "moveItem fails with CloudProviderError.itemAlreadyExists if a folder already exists at the target URL")
		authentication.authenticate().then {
			self.provider.moveItem(from: remoteFolderToMoveURL, to: newRemoteFolderToMoveURL)
		}.then {
			XCTFail("moveItem fulfilled although a folder already exists at the target URL")
		}.catch { error in
			guard case CloudProviderError.itemAlreadyExists = error else {
				XCTFail(error.localizedDescription)
				return
			}
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 60.0)
	}

	func testMoveItemFailWithItemTypeMismatchIfFileWithThisNameDoesNotExistsButAFolder() throws {
		let remoteNonExistentFileToMoveURL = CryptomatorIntegrationTestInterface.remoteFolderForMoveItemsURL.appendingPathComponent("FolderForItemTypeMismatch", isDirectory: false)
		let newRemoteFileToMoveURL = CryptomatorIntegrationTestInterface.remoteFolderForMoveItemsURL.appendingPathComponent("FileForItemTypeMismatch-AAA", isDirectory: false)
		let expectation = XCTestExpectation(description: "moveItem did not move the folder with the same name because we wanted to move a file")
		authentication.authenticate().then {
			self.provider.moveItem(from: remoteNonExistentFileToMoveURL, to: newRemoteFileToMoveURL)
		}.then {
			XCTFail("moveItem fulfilled although the file to be moved does not exist")
		}.catch { error in
			guard case CloudProviderError.itemTypeMismatch = error else {
				XCTFail(error.localizedDescription)
				return
			}
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 30.0)
	}

	func testMoveItemFailWithItemTypeMismatchIfFolderWithThisNameDoesNotExistsButAFile() throws {
		let remoteNonExistentFolderToMoveURL = CryptomatorIntegrationTestInterface.remoteFolderForMoveItemsURL.appendingPathComponent("FileForItemTypeMismatch", isDirectory: true)
		let newRemoteFolderToMoveURL = CryptomatorIntegrationTestInterface.remoteFolderForMoveItemsURL.appendingPathComponent("FolderForItemTypeMismatch-AAA", isDirectory: true)
		let expectation = XCTestExpectation(description: "moveItem did not move the file with the same name because we wanted to move a folder")
		authentication.authenticate().then {
			self.provider.moveItem(from: remoteNonExistentFolderToMoveURL, to: newRemoteFolderToMoveURL)
		}.then {
			XCTFail("moveItem fulfilled although the folder to be moved does not exist")
		}.catch { error in
			guard case CloudProviderError.itemTypeMismatch = error else {
				XCTFail(error.localizedDescription)
				return
			}
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 30.0)
	}

	func testMoveItemFailWithParentFolderDoesNotExistIfParentFolderDoesNotExistAtTheTargetURLForFile() throws {
		let remoteFileToMoveURL = CryptomatorIntegrationTestInterface.remoteFolderForMoveItemsURL.appendingPathComponent("FileForParentFolderDoesNotExist", isDirectory: false)
		let newRemoteFileToMoveURL = CryptomatorIntegrationTestInterface.remoteFolderForMoveItemsURL.appendingPathComponent("thisFolderMustNotExist/FileForParentFolderDoesNotExists", isDirectory: false)
		let expectation = XCTestExpectation(description: "moveItem did not move the file because the parent folder does not exist at the target URL")
		authentication.authenticate().then {
			self.provider.moveItem(from: remoteFileToMoveURL, to: newRemoteFileToMoveURL)
		}.then {
			XCTFail("moveItem fulfilled although the parent folder of the target URL does not exist")
		}.catch { error in
			guard case CloudProviderError.parentFolderDoesNotExist = error else {
				XCTFail(error.localizedDescription)
				return
			}
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 30.0)
	}

	func testMoveItemFailWithParentFolderDoesNotExistIfParentFolderDoesNotExistAtTheTargetURLForFolder() throws {
		let remoteFolderToMoveURL = CryptomatorIntegrationTestInterface.remoteFolderForMoveItemsURL.appendingPathComponent("FolderForParentFolderDoesNotExist/", isDirectory: true)
		let newRemoteFolderToMoveURL = CryptomatorIntegrationTestInterface.remoteFolderForMoveItemsURL.appendingPathComponent("thisFolderMustNotExist/FolderForParentFolderDoesNotExist/", isDirectory: true)
		let expectation = XCTestExpectation(description: "moveItem did not move the folder because the parent folder does not exist at the target URL")
		authentication.authenticate().then {
			self.provider.moveItem(from: remoteFolderToMoveURL, to: newRemoteFolderToMoveURL)
		}.then {
			XCTFail("moveItem fulfilled although the parent folder of the target URL does not exist")
		}.catch { error in
			guard case CloudProviderError.parentFolderDoesNotExist = error else {
				XCTFail(error.localizedDescription)
				return
			}
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 30.0)
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

extension CloudItemMetadata: Comparable {
	public static func < (lhs: CloudItemMetadata, rhs: CloudItemMetadata) -> Bool {
		return lhs.name < rhs.name
	}

	public static func == (lhs: CloudItemMetadata, rhs: CloudItemMetadata) -> Bool {
		return lhs.name == rhs.name && lhs.remoteURL == rhs.remoteURL
	}
}

extension CloudProvider {
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
