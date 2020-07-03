//
//  FileProviderDecoratorTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 01.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import GRDB
import Promises
import XCTest
@testable import CryptomatorFileProvider
class FileProviderDecoratorTests: XCTestCase {
	var decorator: FileProviderDecorator!
	override func setUpWithError() throws {
		decorator = try FileProviderDecoratorMock(for: NSFileProviderDomainIdentifier("test"))
	}

	override func tearDownWithError() throws {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
	}

	func testFolderEnumeration() throws {
		let expectation = XCTestExpectation(description: "Folder Enumeration")
		let expectedRootFolderFileProviderItems = [FileProviderItem(metadata: ItemMetadata(id: 2, name: "Directory 1", type: .folder, size: 0, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: URL(fileURLWithPath: "/Directory 1/", isDirectory: true).relativePath, isPlaceholderItem: false)),
												   FileProviderItem(metadata: ItemMetadata(id: 3, name: "File 1", type: .file, size: 14, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: URL(fileURLWithPath: "/File 1", isDirectory: false).relativePath, isPlaceholderItem: false)),
												   FileProviderItem(metadata: ItemMetadata(id: 4, name: "File 2", type: .file, size: 14, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: URL(fileURLWithPath: "/File 3", isDirectory: false).relativePath, isPlaceholderItem: false)),
												   FileProviderItem(metadata: ItemMetadata(id: 5, name: "File 3", type: .file, size: 14, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: URL(fileURLWithPath: "/File 3", isDirectory: false).relativePath, isPlaceholderItem: false)),
												   FileProviderItem(metadata: ItemMetadata(id: 6, name: "File 4", type: .file, size: 14, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: URL(fileURLWithPath: "/File 4", isDirectory: false).relativePath, isPlaceholderItem: false))]
		let expectedSubFolderFileProviderItems = [FileProviderItem(metadata: ItemMetadata(id: 7, name: "Directory 2", type: .folder, size: 0, parentId: 2, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: URL(fileURLWithPath: "/Directory 1/Directory 2", isDirectory: true).relativePath, isPlaceholderItem: false)),
												  FileProviderItem(metadata: ItemMetadata(id: 8, name: "File 5", type: .file, size: 14, parentId: 2, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: URL(fileURLWithPath: "/Directory 1/File 5", isDirectory: false).relativePath, isPlaceholderItem: false))]
		decorator.fetchItemList(for: .rootContainer, withPageToken: nil).then { fileProviderItemList -> FileProviderItem in
			XCTAssertEqual(5, fileProviderItemList.items.count)
			XCTAssertEqual(expectedRootFolderFileProviderItems, fileProviderItemList.items)
			return fileProviderItemList.items[0]
		}.then { folderFileProviderItem in
			self.decorator.fetchItemList(for: folderFileProviderItem.itemIdentifier, withPageToken: nil)
		}.then { fileProviderItemList in
			XCTAssertEqual(2, fileProviderItemList.items.count)
			XCTAssertEqual(expectedSubFolderFileProviderItems, fileProviderItemList.items)
		}.catch { error in
			XCTFail("Error in promise: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testLocalFileIsCurrentForUploadingFile() throws {
		let expectation = XCTestExpectation()
		let remoteURL = URL(fileURLWithPath: "/TestUploadFile", isDirectory: false)
		let uploadingItemMetadata = ItemMetadata(name: "TestUploadFile", type: .file, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploading, remotePath: remoteURL.relativePath, isPlaceholderItem: false)
		try decorator.itemMetadataManager.cacheMetadata(uploadingItemMetadata)
		guard let id = uploadingItemMetadata.id else {
			XCTFail("uploadingItemMetadata has no id")
			return
		}
		decorator.localFileIsCurrent(with: NSFileProviderItemIdentifier(String(id))).then { result in
			XCTAssert(result)
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 2.0)
	}

	func testLocalFileIsCurrentForCloudLastModifiedDateIsNil() throws {
		let expectation = XCTestExpectation()
		let mockedDecorator = decorator as? FileProviderDecoratorMock
		mockedDecorator?.internalProvider.setLastModifiedDate(nil, for: URL(fileURLWithPath: "/File 1", isDirectory: false))
		let tmpDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: tmpDirectory, withIntermediateDirectories: false, attributes: nil)
		let localURL = tmpDirectory.appendingPathComponent("File 1", isDirectory: false)
		let itemIdentifier = NSFileProviderItemIdentifier("3")
		decorator.fetchItemList(for: .rootContainer, withPageToken: nil).then { _ in
			self.decorator.downloadFile(with: itemIdentifier, to: localURL)
		}.then { _ in
			self.decorator.localFileIsCurrent(with: itemIdentifier)
		}.then { result in
			XCTAssertFalse(result)
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 2.0)
	}

	func testLocalFileIsCurrentForNewerVersionInCloud() throws {
		let expectation = XCTestExpectation()
		let itemIdentifier = NSFileProviderItemIdentifier("3")
		let tmpDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: tmpDirectory, withIntermediateDirectories: false, attributes: nil)
		let localURL = tmpDirectory.appendingPathComponent("File 1", isDirectory: false)
		decorator.fetchItemList(for: .rootContainer, withPageToken: nil).then { _ in
			self.decorator.downloadFile(with: itemIdentifier, to: localURL)
		}.then { _ -> Promise<Bool> in
			let mockedDecorator = self.decorator as? FileProviderDecoratorMock
			mockedDecorator?.internalProvider.setLastModifiedDate(Date(timeIntervalSince1970: 100), for: URL(fileURLWithPath: "/File 1", isDirectory: false))
			return self.decorator.localFileIsCurrent(with: itemIdentifier)
		}.then { result in
			XCTAssertFalse(result)
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 2.0)
	}

	func testLocalFileIsCurrentForCloudLastModifiedDateIsEqual() throws {
		let expectation = XCTestExpectation()
		let tmpDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: tmpDirectory, withIntermediateDirectories: false, attributes: nil)
		let localURL = tmpDirectory.appendingPathComponent("File 1", isDirectory: false)
		let itemIdentifier = NSFileProviderItemIdentifier("3")
		decorator.fetchItemList(for: .rootContainer, withPageToken: nil).then { _ in
			self.decorator.downloadFile(with: itemIdentifier, to: localURL)
		}.then { _ in
			self.decorator.localFileIsCurrent(with: itemIdentifier)
		}.then { result in
			XCTAssert(result)
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 2.0)
	}

	func testCreatePlaceholderItemForFile() throws {
		let tmpDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: tmpDirectory, withIntermediateDirectories: false, attributes: nil)
		let localURL = tmpDirectory.appendingPathComponent("FileNotYetUploaded", isDirectory: false)
		try "".write(to: localURL, atomically: true, encoding: .utf8)
		let actualFileProviderItem = try decorator.createPlaceholderItemForFile(for: localURL, in: .rootContainer)
		let expectedRemoteURL = URL(fileURLWithPath: "/FileNotYetUploaded", isDirectory: false)
		XCTAssertEqual("2", actualFileProviderItem.itemIdentifier.rawValue)
		XCTAssertEqual("FileNotYetUploaded", actualFileProviderItem.filename)
		XCTAssertEqual("dyn.age8u", actualFileProviderItem.typeIdentifier)
		XCTAssertEqual(0, actualFileProviderItem.documentSize)
		XCTAssertEqual(NSFileProviderItemIdentifier.rootContainer, actualFileProviderItem.parentItemIdentifier)
		XCTAssertNotNil(actualFileProviderItem.contentModificationDate)
		XCTAssert(actualFileProviderItem.isUploading)
		XCTAssertEqual(expectedRemoteURL.relativePath, actualFileProviderItem.metadata.remotePath)
		XCTAssert(actualFileProviderItem.metadata.isPlaceholderItem)
		let localLastModifiedDate = try decorator.cachedFileManager.getLastModifiedDate(for: actualFileProviderItem.metadata.id!)
		XCTAssertNotNil(localLastModifiedDate)
	}
}

extension FileProviderItem {
	override open func isEqual(_ object: Any?) -> Bool {
		let other = object as? FileProviderItem
		return filename == other?.filename && itemIdentifier == other?.itemIdentifier && parentItemIdentifier == other?.parentItemIdentifier && typeIdentifier == other?.typeIdentifier && capabilities == other?.capabilities && documentSize == other?.documentSize
	}
}

private class FileProviderDecoratorMock: FileProviderDecorator {
	let internalProvider = CloudProviderMock()
	override var provider: CloudProvider {
		return internalProvider
	}

	override init(for domainIdentifier: NSFileProviderDomainIdentifier) throws {
		try super.init(for: domainIdentifier)
		self.homeRoot = URL(fileURLWithPath: "/", isDirectory: true)
	}
}
