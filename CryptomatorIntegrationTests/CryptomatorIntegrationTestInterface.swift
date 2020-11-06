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
	var provider: CloudProvider!
	static var testFolderCloudPath: CloudPath!
	static var emptySubFolderCloudPath: CloudPath!
	static var folderForMoveItemsCloudPath: CloudPath!
	static var folderForDeleteItemsCloudPath: CloudPath!
	static let testContentForFilesInRoot = "testContent"
	static let testContentForFilesInTestFolder = "File inside Folder Content"
	class var setUpProvider: CloudProvider? {
		fatalError("Not implemented")
	}

	class var folderWhereTheIntegrationTestFolderIsCreated: CloudPath {
		fatalError("Not implemented")
	}

	static var rootCloudPathForIntegrationTest: CloudPath {
		folderWhereTheIntegrationTestFolderIsCreated.appendingPathComponent("/IntegrationTest/")
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
		guard let provider = setUpProvider else {
			classSetUpError = IntegrationTestError.cloudProviderInitError
			return
		}
		let setUpPromise = setUpForIntegrationTest(at: provider, rootCloudPathForIntegrationTest: rootCloudPathForIntegrationTest)

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
	class func setUpForIntegrationTest(at provider: CloudProvider, rootCloudPathForIntegrationTest: CloudPath) -> Promise<Void> {
		let tempDirectory = FileManager.default.temporaryDirectory
		let currentTestTempDirectory = tempDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)

		testFolderCloudPath = rootCloudPathForIntegrationTest.appendingPathComponent("testFolder/")
		emptySubFolderCloudPath = testFolderCloudPath.appendingPathComponent("Empty Sub Folder/")
		folderForDeleteItemsCloudPath = testFolderCloudPath.appendingPathComponent("FolderForDeleteItems/")
		folderForMoveItemsCloudPath = testFolderCloudPath.appendingPathComponent("FolderForMoveItems/")
		let remoteFolderToDeleteURL = folderForDeleteItemsCloudPath.appendingPathComponent("FolderToDelete/")
		let remoteFolderToMoveURL = folderForMoveItemsCloudPath.appendingPathComponent("FolderToMove/")

		return provider.deleteFolderIfExisting(at: rootCloudPathForIntegrationTest)
			.then {
				provider.createFolderWithIntermediates(for: rootCloudPathForIntegrationTest)
			}.then {
				createRootFolderContent(localCurrentTestTempDirectory: currentTestTempDirectory, with: provider)
			}.then {
				createTestFolderContent(localCurrentTestTempDirectory: currentTestTempDirectory, with: provider)
			}.then {
				createFolderForDeleteItemsContent(localCurrentTestTempDirectory: currentTestTempDirectory, folderToDeleteCloudPath: remoteFolderToDeleteURL, with: provider)
			}.then {
				createFolderForMoveItemsContent(localCurrentTestTempDirectory: currentTestTempDirectory, folderToMoveCloudPath: remoteFolderToMoveURL, with: provider)
			}.then { _ in
				try FileManager.default.removeItem(at: currentTestTempDirectory)
			}
	}

	private class func createRootFolderContent(localCurrentTestTempDirectory: URL, with provider: CloudProvider) -> Promise<Void> {
		let remoteRootFileURLs = createTestFileURLs(in: URL(fileURLWithPath: rootCloudPathForIntegrationTest.path))
		let localTestFolderURL = localCurrentTestTempDirectory.appendPathComponents(from: URL(fileURLWithPath: testFolderCloudPath.path))
		do {
			try FileManager.default.createDirectory(at: localTestFolderURL, withIntermediateDirectories: true, attributes: nil)
			for remoteFileURL in remoteRootFileURLs {
				try testContentForFilesInRoot.write(to: localCurrentTestTempDirectory.appendPathComponents(from: remoteFileURL), atomically: true, encoding: .utf8)
			}
		} catch {
			return Promise(error)
		}
		return all(remoteRootFileURLs.map { provider.uploadFile(from: localCurrentTestTempDirectory.appendPathComponents(from: $0), to: CloudPath($0.path), replaceExisting: false) }).then { _ in
			provider.createFolder(at: testFolderCloudPath)
		}
	}

	private class func createTestFolderContent(localCurrentTestTempDirectory: URL, with provider: CloudProvider) -> Promise<Void> {
		let remoteTestFolderFileURLs = createTestFileURLs(in: URL(fileURLWithPath: testFolderCloudPath.path))

		let localFolderToDeleteURL = localCurrentTestTempDirectory.appendPathComponents(from: URL(fileURLWithPath: folderForDeleteItemsCloudPath.path))
		let localFolderToMoveURL = localCurrentTestTempDirectory.appendPathComponents(from: URL(fileURLWithPath: folderForMoveItemsCloudPath.path))
		do {
			try FileManager.default.createDirectory(at: localFolderToDeleteURL, withIntermediateDirectories: false, attributes: nil)
			try FileManager.default.createDirectory(at: localFolderToMoveURL, withIntermediateDirectories: false, attributes: nil)
			for remoteFileURL in remoteTestFolderFileURLs {
				try testContentForFilesInTestFolder.write(to: localCurrentTestTempDirectory.appendPathComponents(from: remoteFileURL), atomically: true, encoding: .utf8)
			}
		} catch {
			return Promise(error)
		}
		return all(remoteTestFolderFileURLs.map { provider.uploadFile(from: localCurrentTestTempDirectory.appendPathComponents(from: $0), to: CloudPath($0.path), replaceExisting: false) }).then { _ in
			provider.createFolder(at: emptySubFolderCloudPath)
		}.then {
			provider.createFolder(at: folderForDeleteItemsCloudPath)
		}.then {
			provider.createFolder(at: folderForMoveItemsCloudPath)
		}
	}

	private class func createFolderForDeleteItemsContent(localCurrentTestTempDirectory: URL, folderToDeleteCloudPath: CloudPath, with provider: CloudProvider) -> Promise<Void> {
		let remoteFileToDeleteURL = folderForDeleteItemsCloudPath.appendingPathComponent("FileToDelete")
		let remoteFileForItemTypeMismatchURL = folderForDeleteItemsCloudPath.appendingPathComponent("FileForItemTypeMismatch")
		let remoteFolderForItemTypeMismatchURL = folderForDeleteItemsCloudPath.appendingPathComponent("FolderForItemTypeMismatch/")

		let localFileToDeleteURL = localCurrentTestTempDirectory.appendPathComponents(from: URL(fileURLWithPath: remoteFileToDeleteURL.path))
		let localFileForItemTypeMismatchURL = localCurrentTestTempDirectory.appendPathComponents(from: URL(fileURLWithPath: remoteFileForItemTypeMismatchURL.path))
		let emptyTestContent = "AAAAAAAAAAAAAAAAAAAAAAAAAABBBBBBABABABABABBABABABBABABABABABAB"

		do {
			try emptyTestContent.write(to: localFileToDeleteURL, atomically: true, encoding: .utf8)
			try emptyTestContent.write(to: localFileForItemTypeMismatchURL, atomically: true, encoding: .utf8)
		} catch {
			return Promise(error)
		}
		return provider.uploadFile(from: localFileToDeleteURL, to: remoteFileToDeleteURL, replaceExisting: false).then { _ in
			provider.uploadFile(from: localFileForItemTypeMismatchURL, to: remoteFileForItemTypeMismatchURL, replaceExisting: false)
		}.then { _ in
			provider.createFolder(at: folderToDeleteCloudPath)
		}.then {
			provider.createFolder(at: remoteFolderForItemTypeMismatchURL)
		}
	}

	private class func createFolderForMoveItemsContent(localCurrentTestTempDirectory: URL, folderToMoveCloudPath: CloudPath, with provider: CloudProvider) -> Promise<Void> {
		let moveItemsInThisFolderCloudPath = folderForMoveItemsCloudPath.appendingPathComponent("MoveItemsInThisFolder/")
		let fileToMoveCloudPath = folderForMoveItemsCloudPath.appendingPathComponent("FileToMove")
		let fileToRenameCloudPath = folderForMoveItemsCloudPath.appendingPathComponent("FileToRename")
		let folderToRenameCloudPath = folderForMoveItemsCloudPath.appendingPathComponent("FolderToRename/")
		let fileForItemTypeMismatchCloudPath = folderForMoveItemsCloudPath.appendingPathComponent("FileForItemTypeMismatch")
		let folderForItemTypeMismatchCloudPath = folderForMoveItemsCloudPath.appendingPathComponent("FolderForItemTypeMismatch/")
		let fileForItemItemAlreadyExistsCloudPath = folderForMoveItemsCloudPath.appendingPathComponent("FileForItemAlreadyExists")
		let folderForItemAlreadyExistsCloudPath = folderForMoveItemsCloudPath.appendingPathComponent("FolderForItemAlreadyExists/")
		let fileForParentFolderDoesNotExistCloudPath = folderForMoveItemsCloudPath.appendingPathComponent("FileForParentFolderDoesNotExist")
		let folderForParentFolderDoesNotExistCloudPath = folderForMoveItemsCloudPath.appendingPathComponent("FolderForParentFolderDoesNotExist/")
		let cloudFolders = [folderToRenameCloudPath, folderToMoveCloudPath, moveItemsInThisFolderCloudPath, folderForItemTypeMismatchCloudPath, folderForItemAlreadyExistsCloudPath, folderForParentFolderDoesNotExistCloudPath]
		let cloudFiles = [fileToMoveCloudPath, fileToRenameCloudPath, fileForItemTypeMismatchCloudPath, fileForItemItemAlreadyExistsCloudPath, fileForParentFolderDoesNotExistCloudPath]

		let emptyTestContent = "AAAAAAAAAAAAAAAAAAAAAAAAAABBBBBBABABABABABBABABABBABABABABABAB"

		do {
			for cloudFile in cloudFiles {
				let localFileURL = localCurrentTestTempDirectory.appendPathComponents(from: URL(fileURLWithPath: cloudFile.path))
				try emptyTestContent.write(to: localFileURL, atomically: true, encoding: .utf8)
			}
		} catch {
			return Promise(error)
		}
		return all(cloudFiles.map { provider.uploadFile(from: localCurrentTestTempDirectory.appendPathComponents(from: URL(fileURLWithPath: $0.path)), to: CloudPath($0.path), replaceExisting: false) }).then { _ in
			all(cloudFolders.map { provider.createFolder(at: $0) })
		}.then{ _ in
			return Promise(())
		}
	}

	override class func tearDown() {
		_ = setUpProvider?.deleteFolder(at: rootCloudPathForIntegrationTest)
		_ = waitForPromises(timeout: 60.0)
	}

	private class func createTestFileURLs(in folderURL: URL, filename: String = "test", fileExtension: String = "txt", amount: Int = 5) -> [URL] {
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
		let fileCloudPath = type(of: self).rootCloudPathForIntegrationTest.appendingPathComponent("test 0.txt")
		let expectation = XCTestExpectation(description: "fetchItemMetadataForFile")
		provider.fetchItemMetadata(at: fileCloudPath)
			.then { metadata in
				XCTAssertEqual("test 0.txt", metadata.name)
				XCTAssertEqual(fileCloudPath, metadata.cloudPath)
				XCTAssertEqual(CloudItemType.file, metadata.itemType)
			}.catch { error in
				XCTFail(error.localizedDescription)
			}.always {
				expectation.fulfill()
			}
		wait(for: [expectation], timeout: 60.0)
	}

	func testFetchItemMetadataForFolder() throws {
		let folderCloudPath = type(of: self).rootCloudPathForIntegrationTest.appendingPathComponent("testFolder/")
		let expectation = XCTestExpectation(description: "fetchItemMetadataForFolder")
		provider.fetchItemMetadata(at: folderCloudPath)
			.then { metadata in
				XCTAssertEqual("testFolder", metadata.name)
				XCTAssertEqual(folderCloudPath, metadata.cloudPath)
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
		let nonexistentFileURL = type(of: self).rootCloudPathForIntegrationTest.appendingPathComponent("thisFileMustNotExist.pdf")
		provider.fetchItemMetadata(at: nonexistentFileURL).then { _ in
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
		let nonexistentFolderURL = type(of: self).rootCloudPathForIntegrationTest.appendingPathComponent("thisFolderMustNotExist/")
		provider.fetchItemMetadata(at: nonexistentFolderURL)
			.then { _ in
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
		let fileCloudPath = type(of: self).rootCloudPathForIntegrationTest.appendingPathComponent("testFolder/test 0.txt")
		provider.fetchItemMetadata(at: fileCloudPath)
			.then { metadata in
				XCTAssertEqual("test 0.txt", metadata.name)
				XCTAssertEqual(fileCloudPath, metadata.cloudPath)
				XCTAssertEqual(CloudItemType.file, metadata.itemType)
			}.catch { error in
				XCTFail(error.localizedDescription)
			}.always {
				expectation.fulfill()
			}
		wait(for: [expectation], timeout: 60.0)
	}

	func testFetchItemMetadataForFolderFromSubFolder() throws {
		let folderCloudPath = CryptomatorIntegrationTestInterface.emptySubFolderCloudPath!
		let expectation = XCTestExpectation(description: "fetchItemMetadataForFolderFromSubFolder")
		provider.fetchItemMetadata(at: folderCloudPath)
			.then { metadata in
				XCTAssertEqual("Empty Sub Folder", metadata.name)
				XCTAssertEqual(folderCloudPath, metadata.cloudPath)
				XCTAssertEqual(CloudItemType.folder, metadata.itemType)
				expectation.fulfill()
			}.catch { error in
				XCTFail(error.localizedDescription)
			}
		wait(for: [expectation], timeout: 60.0)
	}

	// MARK: fetchItemList Tests

	func testFetchItemListFromRootFolder() throws {
		let folderCloudPath = type(of: self).rootCloudPathForIntegrationTest
		let expectation = XCTestExpectation(description: "fetchItemList")
		let expectedItems = [
			CloudItemMetadata(name: "test 0.txt", cloudPath: folderCloudPath.appendingPathComponent("test 0.txt"), itemType: .file, lastModifiedDate: nil, size: nil),
			CloudItemMetadata(name: "test 1.txt", cloudPath: folderCloudPath.appendingPathComponent("test 1.txt"), itemType: .file, lastModifiedDate: nil, size: nil),
			CloudItemMetadata(name: "test 2.txt", cloudPath: folderCloudPath.appendingPathComponent("test 2.txt"), itemType: .file, lastModifiedDate: nil, size: nil),
			CloudItemMetadata(name: "test 3.txt", cloudPath: folderCloudPath.appendingPathComponent("test 3.txt"), itemType: .file, lastModifiedDate: nil, size: nil),
			CloudItemMetadata(name: "test 4.txt", cloudPath: folderCloudPath.appendingPathComponent("test 4.txt"), itemType: .file, lastModifiedDate: nil, size: nil),
			CloudItemMetadata(name: "testFolder", cloudPath: CryptomatorIntegrationTestInterface.testFolderCloudPath, itemType: .folder, lastModifiedDate: nil, size: nil)
		]
		provider.fetchItemList(forFolderAt: folderCloudPath, withPageToken: nil)
			.then { retrievedItemList in
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
		let folderCloudPath = type(of: self).rootCloudPathForIntegrationTest.appendingPathComponent("testFolder/")
		let expectation = XCTestExpectation(description: "fetchItemList")
		let expectedItems = [
			CloudItemMetadata(name: "Empty Sub Folder", cloudPath: CryptomatorIntegrationTestInterface.emptySubFolderCloudPath, itemType: .folder, lastModifiedDate: nil, size: nil),
			CloudItemMetadata(name: "FolderForDeleteItems", cloudPath: CryptomatorIntegrationTestInterface.folderForDeleteItemsCloudPath, itemType: .folder, lastModifiedDate: nil, size: nil),
			CloudItemMetadata(name: "FolderForMoveItems", cloudPath: CryptomatorIntegrationTestInterface.folderForMoveItemsCloudPath, itemType: .folder, lastModifiedDate: nil, size: nil),
			CloudItemMetadata(name: "test 0.txt", cloudPath: folderCloudPath.appendingPathComponent("test 0.txt"), itemType: .file, lastModifiedDate: nil, size: nil),
			CloudItemMetadata(name: "test 1.txt", cloudPath: folderCloudPath.appendingPathComponent("test 1.txt"), itemType: .file, lastModifiedDate: nil, size: nil),
			CloudItemMetadata(name: "test 2.txt", cloudPath: folderCloudPath.appendingPathComponent("test 2.txt"), itemType: .file, lastModifiedDate: nil, size: nil),
			CloudItemMetadata(name: "test 3.txt", cloudPath: folderCloudPath.appendingPathComponent("test 3.txt"), itemType: .file, lastModifiedDate: nil, size: nil),
			CloudItemMetadata(name: "test 4.txt", cloudPath: folderCloudPath.appendingPathComponent("test 4.txt"), itemType: .file, lastModifiedDate: nil, size: nil)
		]
		provider.fetchItemList(forFolderAt: folderCloudPath, withPageToken: nil)
			.then { retrievedItemList in
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
		let folderCloudPath = CryptomatorIntegrationTestInterface.emptySubFolderCloudPath!
		let expectation = XCTestExpectation(description: "fetchItemList in empty folder")
		let expectedItems = [CloudItemMetadata]()
		provider.fetchItemList(forFolderAt: folderCloudPath, withPageToken: nil)
			.then { retrievedItemList in
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
		let nonexistentFolderURL = type(of: self).rootCloudPathForIntegrationTest.appendingPathComponent("thisFolderMustNotExist/")
		provider.fetchItemList(forFolderAt: nonexistentFolderURL, withPageToken: nil)
			.then { _ in
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
		let folderCloudPath = type(of: self).rootCloudPathForIntegrationTest.appendingPathComponent("test 0.txt/")
		let expectation = XCTestExpectation(description: "fetchItemList fails with CloudProviderError.itemTypeMismatch")
		provider.fetchItemList(forFolderAt: folderCloudPath, withPageToken: nil)
			.then { _ in
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

	// MARK: downloadFile Tests

	func testDownloadFileFromRootFolder() throws {
		let filename = "test 0.txt"
		let expectedFileContent = CryptomatorIntegrationTestInterface.testContentForFilesInRoot

		let fileCloudPath = type(of: self).rootCloudPathForIntegrationTest.appendingPathComponent(filename)

		let tempDirectory = FileManager.default.temporaryDirectory
		let uniqueTempFolderURL = tempDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: uniqueTempFolderURL, withIntermediateDirectories: false, attributes: nil)
		let localFileURL = uniqueTempFolderURL.appendingPathComponent(filename, isDirectory: false)
		let expectation = XCTestExpectation(description: "downloadFile")
		provider.downloadFile(from: fileCloudPath, to: localFileURL)
			.then {
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

		let fileCloudPath = type(of: self).rootCloudPathForIntegrationTest.appendingPathComponent("testFolder/test 0.txt")

		let tempDirectory = FileManager.default.temporaryDirectory
		let uniqueTempFolderURL = tempDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: uniqueTempFolderURL, withIntermediateDirectories: false, attributes: nil)
		let localFileURL = uniqueTempFolderURL.appendingPathComponent(filename, isDirectory: false)
		let expectation = XCTestExpectation(description: "downloadFile")
		provider.downloadFile(from: fileCloudPath, to: localFileURL)
			.then {
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

		let fileCloudPath = type(of: self).rootCloudPathForIntegrationTest.appendingPathComponent(filename)
		let tempDirectory = FileManager.default.temporaryDirectory
		let uniqueTempFolderURL = tempDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: uniqueTempFolderURL, withIntermediateDirectories: false, attributes: nil)
		let localFileURL = uniqueTempFolderURL.appendingPathComponent(filename, isDirectory: false)
		let expectation = XCTestExpectation(description: "downloadFile fail with CloudProviderError.itemNotFound")
		provider.downloadFile(from: fileCloudPath, to: localFileURL)
			.then { _ in
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
		let fileCloudPath = type(of: self).rootCloudPathForIntegrationTest.appendingPathComponent(filename)
		let tempDirectory = FileManager.default.temporaryDirectory
		let uniqueTempFolderURL = tempDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: uniqueTempFolderURL, withIntermediateDirectories: false, attributes: nil)
		let localFileURL = uniqueTempFolderURL.appendingPathComponent(filename, isDirectory: false)
		let emptyFileContent = ""
		try emptyFileContent.write(to: localFileURL, atomically: true, encoding: .utf8)
		let expectation = XCTestExpectation(description: "downloadFile fail with CloudProviderError.itemAlreadyExists")
		provider.downloadFile(from: fileCloudPath, to: localFileURL)
			.then { _ in
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
		let fileCloudPath = type(of: self).rootCloudPathForIntegrationTest.appendingPathComponent("testFolder")
		let tempDirectory = FileManager.default.temporaryDirectory
		let uniqueTempFolderURL = tempDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: uniqueTempFolderURL, withIntermediateDirectories: false, attributes: nil)
		let localFileURL = uniqueTempFolderURL.appendingPathComponent("testFolder", isDirectory: false)
		let expectation = XCTestExpectation(description: "downloadFile fails with CloudProviderError.itemTypeMismatch")
		provider.downloadFile(from: fileCloudPath, to: localFileURL)
			.then { _ in
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

	// MARK: uploadFile Tests

	func testUploadFileWithUpdateOverwriteExistingFile() throws {
		let tempDirectory = FileManager.default.temporaryDirectory
		let uniqueTempFolderURL = tempDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: uniqueTempFolderURL, withIntermediateDirectories: false, attributes: nil)
		let localFileURL = uniqueTempFolderURL.appendingPathComponent("overwriteFile.txt", isDirectory: false)
		let localDownloadedFileURL = uniqueTempFolderURL.appendingPathComponent("downloadedFile.txt", isDirectory: false)
		let testContent = "Start content"
		try testContent.write(to: localFileURL, atomically: true, encoding: .utf8)
		let overwrittenContent = "Overwritten content"
		let fileCloudPath = CryptomatorIntegrationTestInterface.emptySubFolderCloudPath.appendingPathComponent("FileToOverwrite.txt")
		let expectation = XCTestExpectation(description: "uploadFile fail overwrites file with update")
		provider.uploadFile(from: localFileURL, to: fileCloudPath, replaceExisting: false)
			.then { _ -> Promise<CloudItemMetadata> in
				try overwrittenContent.write(to: localFileURL, atomically: true, encoding: .utf8)
				return self.provider.uploadFile(from: localFileURL, to: fileCloudPath, replaceExisting: true)
			}.then { _ in
				self.provider.downloadFile(from: fileCloudPath, to: localDownloadedFileURL)
			}.then { _ in
				self.provider.deleteFile(at: fileCloudPath)
			}.then {
				let downloadedContent = try String(contentsOf: localDownloadedFileURL)
				XCTAssertEqual(overwrittenContent, downloadedContent)
			}.catch { error in
				XCTFail("Promise failed with error: \(error)")
			}.always {
				expectation.fulfill()
			}
		wait(for: [expectation], timeout: 60.0)
		try FileManager.default.removeItem(at: uniqueTempFolderURL)
	}

	func testUploadFileFailWithItemNotFoundWhenLocalFileDoesNotExist() throws {
		let tempDirectory = FileManager.default.temporaryDirectory
		let uniqueTempFolderURL = tempDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		let nonExistentLocalFileURL = uniqueTempFolderURL.appendingPathComponent("nonExistentFile.txt", isDirectory: false)
		let fileCloudPath = CryptomatorIntegrationTestInterface.emptySubFolderCloudPath.appendingPathComponent("nonExistentFile.txt")
		let expectation = XCTestExpectation(description: "uploadFile fail with CloudProviderError.itemNotFound when localFile does not exists")
		provider.uploadFile(from: nonExistentLocalFileURL, to: fileCloudPath, replaceExisting: false)
			.then { _ in
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
		let fileCloudPath = CryptomatorIntegrationTestInterface.testFolderCloudPath.appendingPathComponent("test 0.txt")

		let expectation = XCTestExpectation(description: "uploadFile fail with CloudProviderError.itemNotFound when remoteFile already exists and !isUpdate")

		provider.uploadFile(from: localFileURL, to: fileCloudPath, replaceExisting: false)
			.then { _ in
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
		let nonExistentCloudPath = CryptomatorIntegrationTestInterface.testFolderCloudPath.appendingPathComponent("thisFolderMustNotExist/")
		let fileCloudPath = nonExistentCloudPath.appendingPathComponent("test 0.txt")
		let expectation = XCTestExpectation(description: "uploadFile fail with CloudProviderError.parentFolderDoesNotExist when the parent folder in the remote URL does not exist")
		provider.uploadFile(from: localFileURL, to: fileCloudPath, replaceExisting: false)
			.then { _ in
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
		let fileCloudPath = type(of: self).rootCloudPathForIntegrationTest.appendingPathComponent("itemTypeMismatchFolder")
		let tempDirectory = FileManager.default.temporaryDirectory
		let uniqueTempFolderURL = tempDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		let localFileURL = uniqueTempFolderURL.appendingPathComponent("itemTypeMismatchFolder", isDirectory: false)
		try FileManager.default.createDirectory(at: localFileURL, withIntermediateDirectories: true, attributes: nil)

		let expectation = XCTestExpectation(description: "downloadFile fails with CloudProviderError.itemTypeMismatch")
		provider.uploadFile(from: localFileURL, to: fileCloudPath, replaceExisting: false)
			.then { _ in
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

	// MARK: createFolder Tests

	func testCreateFolderFailWithItemAlreadyExistsWhenAFolderAlreadyExists() throws {
		let folderCloudPath = CryptomatorIntegrationTestInterface.emptySubFolderCloudPath!
		let expectation = XCTestExpectation(description: "createFolder fail with CloudProviderError.itemAlreadyExists when a folder already exists at the remoteURL")
		provider.createFolder(at: folderCloudPath)
			.then { _ in
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
		let folderCloudPath = type(of: self).rootCloudPathForIntegrationTest.appendingPathComponent("test 0.txt/")
		let expectation = XCTestExpectation(description: "createFolder fail with CloudProviderError.itemAlreadyExists when a folder already exists at the remoteURL")
		provider.createFolder(at: folderCloudPath)
			.then { _ in
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
		let nonexistentFolderURL = type(of: self).rootCloudPathForIntegrationTest.appendingPathComponent("thisFolderMustNotExist-AAA/")
		let folderCloudPath = nonexistentFolderURL.appendingPathComponent("folderToCreate/")
		let expectation = XCTestExpectation(description: "createFolder fail with CloudProviderError.itemAlreadyExists when a folder already exists at the remoteURL")
		provider.createFolder(at: folderCloudPath)
			.then { _ in
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

	// MARK: deleteFile Tests

	func testDeleteFileCanDeleteExistingFile() throws {
		let itemToDeleteCloudPath = CryptomatorIntegrationTestInterface.folderForDeleteItemsCloudPath.appendingPathComponent("FileToDelete")
		let expectation = XCTestExpectation(description: "deleteFile can delete existing file")
		provider.deleteFile(at: itemToDeleteCloudPath)
			.then {
				self.provider.checkForItemExistence(at: itemToDeleteCloudPath)
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

	func testDeleteItemFailWithItemNotFoundIfFileDoesNotExist() throws {
		let nonExistentFileCloudPath = CryptomatorIntegrationTestInterface.folderForDeleteItemsCloudPath.appendingPathComponent("thisFileMustNotExist")
		let expectation = XCTestExpectation(description: "deleteFile fail with CloudProviderError.itemNotFound if the file to be deleted does not exist")
		provider.deleteFile(at: nonExistentFileCloudPath)
			.then {
				XCTFail("deleteFile fulfilled although the file to be deleted does not exist")
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

	// MARK: deleteFolder Tests

	func testDeleteFolderCanDeleteExistingFolder() throws {
		let folderToDeleteCloudPath = CryptomatorIntegrationTestInterface.folderForDeleteItemsCloudPath.appendingPathComponent("FolderToDelete/")
		let expectation = XCTestExpectation(description: "deleteFolder can delete existing folder")
		provider.deleteFolder(at: folderToDeleteCloudPath)
			.then {
				self.provider.checkForItemExistence(at: folderToDeleteCloudPath)
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

	func testDeleteItemFailWithItemNotFoundIfFolderDoesNotExist() throws {
		let nonExistentFolderCloudPath = CryptomatorIntegrationTestInterface.folderForDeleteItemsCloudPath.appendingPathComponent("thisFolderMustNotExist/")
		let expectation = XCTestExpectation(description: "deleteFolder fail with CloudProviderError.itemNotFound if the folder to be deleted does not exist")
		provider.deleteFolder(at: nonExistentFolderCloudPath)
			.then {
				XCTFail("deleteFolder fulfilled although the folder to be deleted does not exist")
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

	// MARK: moveFile Tests

	func testMoveFileAsRenameForFile() throws {
		let fileToRenameCloudPath = CryptomatorIntegrationTestInterface.folderForMoveItemsCloudPath.appendingPathComponent("FileToRename")
		let newFileToRenameCloudPath = CryptomatorIntegrationTestInterface.folderForMoveItemsCloudPath.appendingPathComponent("RenamedFile")
		let expectation = XCTestExpectation(description: "moveFile works as rename for file")
		let cloudPaths = [fileToRenameCloudPath, newFileToRenameCloudPath]
		provider.moveFile(from: fileToRenameCloudPath, to: newFileToRenameCloudPath)
			.then {
				all(cloudPaths.map { self.provider.checkForItemExistence(at: $0) })
			}.then { itemsExist in
				let oldItemExist = itemsExist[0]
				let newItemExist = itemsExist[1]
				guard !oldItemExist, newItemExist else {
					XCTFail("moveFile did not move the file correctly")
					return
				}
			}.catch { error in
				XCTFail(error.localizedDescription)
			}.always {
				expectation.fulfill()
			}
		wait(for: [expectation], timeout: 20.0)
	}

	func testMoveFile() throws {
		let fileToMoveCloudPath = CryptomatorIntegrationTestInterface.folderForMoveItemsCloudPath.appendingPathComponent("FileToMove")
		let newFileToMoveCloudPath = CryptomatorIntegrationTestInterface.folderForMoveItemsCloudPath.appendingPathComponent("MoveItemsInThisFolder/renamedAndMovedFile")
		let expectation = XCTestExpectation(description: "moveFile works for file")
		let remoteURLs = [fileToMoveCloudPath, newFileToMoveCloudPath]
		provider.moveFile(from: fileToMoveCloudPath, to: newFileToMoveCloudPath)
			.then {
				all(remoteURLs.map { self.provider.checkForItemExistence(at: $0) })
			}.then { itemsExist in
				let oldItemExist = itemsExist[0]
				let newItemExist = itemsExist[1]
				guard !oldItemExist, newItemExist else {
					XCTFail("moveFile did not move the file correctly")
					return
				}
			}.catch { error in
				XCTFail(error.localizedDescription)
			}.always {
				expectation.fulfill()
			}
		wait(for: [expectation], timeout: 60.0)
	}

	func testMoveFileFailWithItemNotFoundIfTheFileToMoveDoesNotExist() throws {
		let nonExistentFileToMoveCloudPath = CryptomatorIntegrationTestInterface.folderForMoveItemsCloudPath.appendingPathComponent("thisFileMustNotExist.pdf")
		let newFileToMoveCloudPath = CryptomatorIntegrationTestInterface.folderForMoveItemsCloudPath.appendingPathComponent("MoveItemsInThisFolder/thisFileMustNotExistRenamed.pdf")
		let expectation = XCTestExpectation(description: "moveFile fails with CloudProviderError.itemNotFound if the file to move does not exist")
		provider.moveFile(from: nonExistentFileToMoveCloudPath, to: newFileToMoveCloudPath)
			.then {
				XCTFail("moveFile fulfilled although the file to be moved does not exist")
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

	func testMoveFileFailWithItemAlreadyExistsIfTheFileExistsAtTheTargetCloudPath() throws {
		let fileToMoveCloudPath = CryptomatorIntegrationTestInterface.folderForMoveItemsCloudPath.appendingPathComponent("FileForItemAlreadyExists")
		let newFileToMoveCloudPath = CryptomatorIntegrationTestInterface.folderForMoveItemsCloudPath.appendingPathComponent("FileForItemTypeMismatch")
		let expectation = XCTestExpectation(description: "moveFile fails with CloudProviderError.itemAlreadyExists if a file already exists at the target URL")
		provider.moveFile(from: fileToMoveCloudPath, to: newFileToMoveCloudPath)
			.then {
				XCTFail("moveFile fulfilled although a file already exists at the target URL")
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

	func testMoveFileFailWithParentFolderDoesNotExistIfParentFolderDoesNotExistAtTheTargetCloudPath() throws {
		let fileToMoveCloudPath = CryptomatorIntegrationTestInterface.folderForMoveItemsCloudPath.appendingPathComponent("FileForParentFolderDoesNotExist")
		let newFileToMoveCloudPath = CryptomatorIntegrationTestInterface.folderForMoveItemsCloudPath.appendingPathComponent("thisFolderMustNotExist/FileForParentFolderDoesNotExists")
		let expectation = XCTestExpectation(description: "moveFile did not move the file because the parent folder does not exist at the target URL")
		provider.moveFile(from: fileToMoveCloudPath, to: newFileToMoveCloudPath)
			.then {
				XCTFail("moveFile fulfilled although the parent folder of the target URL does not exist")
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

	// MARK: moveFolder Tests

	func testMoveFolderAsRenameForFolder() throws {
		let folderToRenameCloudPath = CryptomatorIntegrationTestInterface.folderForMoveItemsCloudPath.appendingPathComponent("FolderToRename/")
		let newFolderToRenameCloudPath = CryptomatorIntegrationTestInterface.folderForMoveItemsCloudPath.appendingPathComponent("RenamedFolder/")
		let expectation = XCTestExpectation(description: "moveFolder works as rename for folder")
		let remoteURLs = [folderToRenameCloudPath, newFolderToRenameCloudPath]
		provider.moveFolder(from: folderToRenameCloudPath, to: newFolderToRenameCloudPath)
			.then {
				all(remoteURLs.map { self.provider.checkForItemExistence(at: $0) })
			}.then { itemsExist in
				let oldItemExist = itemsExist[0]
				let newItemExist = itemsExist[1]
				guard !oldItemExist, newItemExist else {
					XCTFail("moveFolder did not move the folder correctly")
					return
				}
			}.catch { error in
				XCTFail(error.localizedDescription)
			}.always {
				expectation.fulfill()
			}
		wait(for: [expectation], timeout: 60.0)
	}

	func testMoveFolder() throws {
		let fileToMoveCloudPath = CryptomatorIntegrationTestInterface.folderForMoveItemsCloudPath.appendingPathComponent("FolderToMove/")
		let newFileToMoveCloudPath = CryptomatorIntegrationTestInterface.folderForMoveItemsCloudPath.appendingPathComponent("MoveItemsInThisFolder/renamedAndMovedFolder/")
		let expectation = XCTestExpectation(description: "moveFolder works for folder")
		let remoteURLs = [fileToMoveCloudPath, newFileToMoveCloudPath]
		provider.moveFolder(from: fileToMoveCloudPath, to: newFileToMoveCloudPath)
			.then {
				all(remoteURLs.map { self.provider.checkForItemExistence(at: $0) })
			}.then { itemsExist in
				let oldItemExist = itemsExist[0]
				let newItemExist = itemsExist[1]
				guard !oldItemExist, newItemExist else {
					XCTFail("moveFolder did not move the folder correctly")
					return
				}
			}.catch { error in
				XCTFail(error.localizedDescription)
			}.always {
				expectation.fulfill()
			}
		wait(for: [expectation], timeout: 60.0)
	}

	func testMoveFolderFailWithItemNotFoundIfTheFolderToMoveDoesNotExist() throws {
		let nonExistentFolderToMoveCloudPath = CryptomatorIntegrationTestInterface.folderForMoveItemsCloudPath.appendingPathComponent("thisFolderMustNotExist/")
		let newRemoteFileToMoveCloudPath = CryptomatorIntegrationTestInterface.folderForMoveItemsCloudPath.appendingPathComponent("MoveItemsInThisFolder/thisFolderMustNotExistRenamed/")
		let expectation = XCTestExpectation(description: "moveFolder fails with CloudProviderError.itemNotFound if the folder to move does not exist")
		provider.moveFolder(from: nonExistentFolderToMoveCloudPath, to: newRemoteFileToMoveCloudPath)
			.then {
				XCTFail("moveFolder fulfilled although the file to be moved does not exist")
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

	func testMoveFolderFailWithItemAlreadyExistsIfTheFolderExistsAtTheTargetCloudPath() throws {
		let folderToMoveCloudPath = CryptomatorIntegrationTestInterface.folderForMoveItemsCloudPath.appendingPathComponent("FolderForItemAlreadyExists/")
		let newFolderToMoveCloudPath = CryptomatorIntegrationTestInterface.folderForMoveItemsCloudPath.appendingPathComponent("FolderForItemTypeMismatch/")
		let expectation = XCTestExpectation(description: "moveFolder fails with CloudProviderError.itemAlreadyExists if a folder already exists at the target URL")
		provider.moveFolder(from: folderToMoveCloudPath, to: newFolderToMoveCloudPath)
			.then {
				XCTFail("moveFolder fulfilled although a folder already exists at the target URL")
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

	func testMoveFolderFailWithParentFolderDoesNotExistIfParentFolderDoesNotExistAtTheTargetCloudPath() throws {
		let folderToMoveCloudPath = CryptomatorIntegrationTestInterface.folderForMoveItemsCloudPath.appendingPathComponent("FolderForParentFolderDoesNotExist/")
		let newFolderToMoveCloudPath = CryptomatorIntegrationTestInterface.folderForMoveItemsCloudPath.appendingPathComponent("thisFolderMustNotExist/FolderForParentFolderDoesNotExist/")
		let expectation = XCTestExpectation(description: "moveFolder did not move the folder because the parent folder does not exist at the target URL")
		provider.moveFolder(from: folderToMoveCloudPath, to: newFolderToMoveCloudPath)
			.then {
				XCTFail("moveFolder fulfilled although the parent folder of the target URL does not exist")
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
}

extension CloudItemMetadata: Comparable {
	public static func < (lhs: CloudItemMetadata, rhs: CloudItemMetadata) -> Bool {
		return lhs.name < rhs.name
	}

	public static func == (lhs: CloudItemMetadata, rhs: CloudItemMetadata) -> Bool {
		return lhs.name == rhs.name && lhs.cloudPath == rhs.cloudPath && lhs.itemType == rhs.itemType
	}
}
