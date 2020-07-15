//
//  FileProviderDecoratorTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 01.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import FileProvider
import GRDB
import Promises
import XCTest
@testable import CryptomatorFileProvider
class FileProviderDecoratorTests: FileProviderDecoratorTestCase {
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
		wait(for: [expectation], timeout: 1.0)
	}

	func testLocalFileIsCurrentForCloudLastModifiedDateIsNil() throws {
		let expectation = XCTestExpectation()
		let mockedDecorator = decorator as? FileProviderDecoratorMock
		mockedDecorator?.internalProvider.setLastModifiedDate(nil, for: URL(fileURLWithPath: "/File 1", isDirectory: false))

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
		let localURL = tmpDirectory.appendingPathComponent("FileNotYetUploaded.txt", isDirectory: false)
		try "".write(to: localURL, atomically: true, encoding: .utf8)
		let actualFileProviderItem = try decorator.createPlaceholderItemForFile(for: localURL, in: .rootContainer)
		let expectedRemoteURL = URL(fileURLWithPath: "/FileNotYetUploaded.txt", isDirectory: false)
		XCTAssertEqual("2", actualFileProviderItem.itemIdentifier.rawValue)
		XCTAssertEqual("FileNotYetUploaded.txt", actualFileProviderItem.filename)
		XCTAssertEqual("public.plain-text", actualFileProviderItem.typeIdentifier)
		XCTAssertEqual(0, actualFileProviderItem.documentSize)
		XCTAssertEqual(NSFileProviderItemIdentifier.rootContainer, actualFileProviderItem.parentItemIdentifier)
		XCTAssertNotNil(actualFileProviderItem.contentModificationDate)
		XCTAssert(actualFileProviderItem.isUploading)
		XCTAssertEqual(expectedRemoteURL.relativePath, actualFileProviderItem.metadata.remotePath)
		XCTAssert(actualFileProviderItem.metadata.isPlaceholderItem)
		let localLastModifiedDate = try decorator.cachedFileManager.getLastModifiedDate(for: actualFileProviderItem.metadata.id!)
		XCTAssertNotNil(localLastModifiedDate)
	}

	func skip_testCreatePlaceholderItemForFileWithNameCollision() throws {
		let localURL = tmpDirectory.appendingPathComponent("FileNotYetUploaded.txt", isDirectory: false)
		try "".write(to: localURL, atomically: true, encoding: .utf8)
		let expectedRemoteURL = URL(fileURLWithPath: "/FileNotYetUploaded.txt", isDirectory: false)
		let itemMetadata = ItemMetadata(name: "FileNotYetUploaded.txt", type: .file, size: 0, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: expectedRemoteURL.relativePath, isPlaceholderItem: false)
		let expectation = XCTestExpectation()
		DispatchQueue.main.async {
			autoreleasepool {
				do {
					try self.decorator.itemMetadataManager.cacheMetadata(itemMetadata)
					_ = try self.decorator.createPlaceholderItemForFile(for: localURL, in: .rootContainer)
					XCTFail("function should throw")
				} catch {
					print("foo")
					expectation.fulfill()
					/*
					 guard error.domain == NSFileProviderErrorDomain, error.code == NSFileProviderError.filenameCollision.rawValue else {
					 XCTFail("throws wrong error: \(error)")
					 return
					 }*/
				}
			}
		}
		wait(for: [expectation], timeout: 2.0)
	}

	func testUploadFile() throws {
		let localURL = tmpDirectory.appendingPathComponent("FileToBeUploaded", isDirectory: false)
		try "TestContent".write(to: localURL, atomically: true, encoding: .utf8)
		let placeholderFileProviderItem = try decorator.createPlaceholderItemForFile(for: localURL, in: .rootContainer)
		let itemMetadata = try decorator.registerFileInUploadQueue(with: localURL, identifier: placeholderFileProviderItem.itemIdentifier)
		let expectation = XCTestExpectation()
		let mockedCloudDate = Date(timeIntervalSinceReferenceDate: 0)
		mockedProvider.lastModifiedDate[itemMetadata.remotePath] = mockedCloudDate
		decorator.uploadFileWithoutRecover(from: localURL, itemMetadata: itemMetadata).then { _ in
			XCTAssertEqual("TestContent".data(using: .utf8), self.mockedProvider.createdFiles["/FileToBeUploaded"])
			guard let cachedItemMetadata = try self.decorator.itemMetadataManager.getCachedMetadata(for: itemMetadata.id!) else {
				XCTFail("No ItemMetadata found")
				return
			}
			XCTAssertEqual(ItemStatus.isUploaded, cachedItemMetadata.statusCode)
			XCTAssertFalse(cachedItemMetadata.isPlaceholderItem)
		}
		.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 2.0)
		let localLastModifiedDate = try decorator.cachedFileManager.getLastModifiedDate(for: itemMetadata.id!)
		XCTAssertNotNil(localLastModifiedDate)
		XCTAssertEqual(mockedProvider.lastModifiedDate[itemMetadata.remotePath], localLastModifiedDate)
	}

	func testUploadFileFailIfProviderRejectWithItemNotFound() throws {
		let expectation = XCTestExpectation()

		let localURL = tmpDirectory.appendingPathComponent("itemNotFound.txt", isDirectory: false)
		try "".write(to: localURL, atomically: true, encoding: .utf8)

		let placeholderFileProviderItem = try decorator.createPlaceholderItemForFile(for: localURL, in: .rootContainer)
		_ = try decorator.registerFileInUploadQueue(with: localURL, identifier: placeholderFileProviderItem.itemIdentifier)
		decorator.uploadFileWithoutRecover(from: localURL, itemMetadata: placeholderFileProviderItem.metadata).then { item in
			XCTAssertFalse(item.isUploaded)
			XCTAssertFalse(item.isUploading)
			guard let actualError = item.uploadingError as NSError? else {
				XCTFail("Item has no Error")
				return
			}
			let expectedError = NSFileProviderError(.noSuchItem) as NSError
			XCTAssertTrue(expectedError.isEqual(actualError))
			guard let uploadTask = try? self.decorator.uploadTaskManager.getTask(for: placeholderFileProviderItem.metadata.id!) else {
				XCTFail("The item has no corresponding UploadTask")
				return
			}
			XCTAssertNotNil(uploadTask.lastFailedUploadDate)
			XCTAssertEqual(NSFileProviderError.noSuchItem.rawValue, uploadTask.uploadErrorCode)
			XCTAssertEqual(NSFileProviderErrorDomain, uploadTask.uploadErrorDomain)
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 2.0)
	}

	func testUploadFileFailIfProviderRejectWithQuotaInsufficient() throws {
		let expectation = XCTestExpectation()

		let localURL = tmpDirectory.appendingPathComponent("quotaInsufficient.txt", isDirectory: false)
		try "".write(to: localURL, atomically: true, encoding: .utf8)

		let placeholderFileProviderItem = try decorator.createPlaceholderItemForFile(for: localURL, in: .rootContainer)
		_ = try decorator.registerFileInUploadQueue(with: localURL, identifier: placeholderFileProviderItem.itemIdentifier)
		decorator.uploadFileWithoutRecover(from: localURL, itemMetadata: placeholderFileProviderItem.metadata).then { item in
			XCTAssertFalse(item.isUploaded)
			XCTAssertFalse(item.isUploading)
			guard let actualError = item.uploadingError as NSError? else {
				XCTFail("Item has no Error")
				return
			}
			let expectedError = NSFileProviderError(.insufficientQuota) as NSError
			XCTAssertTrue(expectedError.isEqual(actualError))
			guard let uploadTask = try? self.decorator.uploadTaskManager.getTask(for: placeholderFileProviderItem.metadata.id!) else {
				XCTFail("The item has no corresponding UploadTask")
				return
			}
			XCTAssertNotNil(uploadTask.lastFailedUploadDate)
			XCTAssertEqual(NSFileProviderError.insufficientQuota.rawValue, uploadTask.uploadErrorCode)
			XCTAssertEqual(NSFileProviderErrorDomain, uploadTask.uploadErrorDomain)
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 2.0)
	}

	func testUploadFileFailIfProviderRejectWithNoInternetConnection() throws {
		let expectation = XCTestExpectation()

		let localURL = tmpDirectory.appendingPathComponent("noInternetConnection.txt", isDirectory: false)
		try "".write(to: localURL, atomically: true, encoding: .utf8)

		let placeholderFileProviderItem = try decorator.createPlaceholderItemForFile(for: localURL, in: .rootContainer)
		_ = try decorator.registerFileInUploadQueue(with: localURL, identifier: placeholderFileProviderItem.itemIdentifier)
		decorator.uploadFileWithoutRecover(from: localURL, itemMetadata: placeholderFileProviderItem.metadata).then { item in
			XCTAssertFalse(item.isUploaded)
			XCTAssertFalse(item.isUploading)
			guard let actualError = item.uploadingError as NSError? else {
				XCTFail("Item has no Error")
				return
			}
			let expectedError = NSFileProviderError(.serverUnreachable) as NSError
			XCTAssertTrue(expectedError.isEqual(actualError))
			guard let uploadTask = try? self.decorator.uploadTaskManager.getTask(for: placeholderFileProviderItem.metadata.id!) else {
				XCTFail("The item has no corresponding UploadTask")
				return
			}
			XCTAssertNotNil(uploadTask.lastFailedUploadDate)
			XCTAssertEqual(NSFileProviderError.serverUnreachable.rawValue, uploadTask.uploadErrorCode)
			XCTAssertEqual(NSFileProviderErrorDomain, uploadTask.uploadErrorDomain)
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 2.0)
	}

	func testUploadFileFailIfProviderRejectWithUnauthorized() throws {
		let expectation = XCTestExpectation()

		let localURL = tmpDirectory.appendingPathComponent("unauthorized.txt", isDirectory: false)
		try "".write(to: localURL, atomically: true, encoding: .utf8)

		let placeholderFileProviderItem = try decorator.createPlaceholderItemForFile(for: localURL, in: .rootContainer)
		_ = try decorator.registerFileInUploadQueue(with: localURL, identifier: placeholderFileProviderItem.itemIdentifier)
		decorator.uploadFileWithoutRecover(from: localURL, itemMetadata: placeholderFileProviderItem.metadata).then { item in
			XCTAssertFalse(item.isUploaded)
			XCTAssertFalse(item.isUploading)
			guard let actualError = item.uploadingError as NSError? else {
				XCTFail("Item has no Error")
				return
			}
			let expectedError = NSFileProviderError(.notAuthenticated) as NSError
			XCTAssertTrue(expectedError.isEqual(actualError))
			guard let uploadTask = try? self.decorator.uploadTaskManager.getTask(for: placeholderFileProviderItem.metadata.id!) else {
				XCTFail("The item has no corresponding UploadTask")
				return
			}
			XCTAssertNotNil(uploadTask.lastFailedUploadDate)
			XCTAssertEqual(NSFileProviderError.notAuthenticated.rawValue, uploadTask.uploadErrorCode)
			XCTAssertEqual(NSFileProviderErrorDomain, uploadTask.uploadErrorDomain)
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 2.0)
	}

	func testUploadFileRejectIfProviderRejectWithItemAlreadyExists() throws {
		let expectation = XCTestExpectation()

		let localURL = tmpDirectory.appendingPathComponent("itemAlreadyExists.txt", isDirectory: false)
		try "".write(to: localURL, atomically: true, encoding: .utf8)

		let placeholderFileProviderItem = try decorator.createPlaceholderItemForFile(for: localURL, in: .rootContainer)
		_ = try decorator.registerFileInUploadQueue(with: localURL, identifier: placeholderFileProviderItem.itemIdentifier)
		decorator.uploadFileWithoutRecover(from: localURL, itemMetadata: placeholderFileProviderItem.metadata).then { _ in
			XCTFail("Promise was fulfilled although we expect an error")
		}.catch { error in
			guard case CloudProviderError.itemAlreadyExists = error else {
				XCTFail("Promise was rejected with the wrong error")
				return
			}
			guard let itemMetadata = try? self.decorator.itemMetadataManager.getCachedMetadata(for: placeholderFileProviderItem.metadata.id!) else {
				XCTFail("ItemMetadata is missing in the DB")
				return
			}
			XCTAssertEqual(ItemStatus.isUploading, itemMetadata.statusCode)
			guard let uploadTask = try? self.decorator.uploadTaskManager.getTask(for: placeholderFileProviderItem.metadata.id!) else {
				XCTFail("UploadTask is missing in the DB")
				return
			}
			XCTAssertNil(uploadTask.lastFailedUploadDate)
			XCTAssertNil(uploadTask.uploadErrorCode)
			XCTAssertNil(uploadTask.uploadErrorDomain)
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 2.0)
	}

	func testRegisterInUploadQueue() throws {
		let localURL = tmpDirectory.appendingPathComponent("FileToBeUploaded", isDirectory: false)
		try "".write(to: localURL, atomically: true, encoding: .utf8)
		let placeholderFileProviderItem = try decorator.createPlaceholderItemForFile(for: localURL, in: .rootContainer)
		let itemMetadata = try decorator.registerFileInUploadQueue(with: localURL, identifier: placeholderFileProviderItem.itemIdentifier)
		XCTAssertEqual(ItemStatus.isUploading, itemMetadata.statusCode)
		guard let id = itemMetadata.id else {
			XCTFail("id is nil")
			return
		}
		guard let fetchedItemMetadata = try decorator.itemMetadataManager.getCachedMetadata(for: id) else {
			XCTFail("No ItemMetadata found")
			return
		}
		XCTAssertEqual(ItemStatus.isUploading, fetchedItemMetadata.statusCode)
		guard let uploadTask = try decorator.uploadTaskManager.getTask(for: id) else {
			XCTFail("No UploadTask found")
			return
		}
		XCTAssertEqual(id, uploadTask.correspondingItem)
		XCTAssertNil(uploadTask.lastFailedUploadDate)
		XCTAssertNil(uploadTask.uploadErrorCode)
		XCTAssertNil(uploadTask.uploadErrorDomain)
		// TODO: Add localFileInfo Check
	}

	func testCloudFileNameCollisionHandling() throws {
		let localURL = tmpDirectory.appendingPathComponent("itemAlreadyExists.txt", isDirectory: false)
		try "".write(to: localURL, atomically: true, encoding: .utf8)
		let collisionFreeLocalURL = tmpDirectory.appendingPathComponent("itemAlreadyExists (AAAAA).txt", isDirectory: false)
		let metadata = try decorator.createPlaceholderItemForFile(for: localURL, in: .rootContainer).metadata
		guard let id = metadata.id else {
			XCTFail("Metadata has no id")
			return
		}
		try decorator.cloudFileNameCollisionHandling(for: localURL, with: collisionFreeLocalURL, itemMetadata: metadata)
		XCTAssertEqual("itemAlreadyExists (AAAAA).txt", metadata.name)
		XCTAssertEqual(id, metadata.id)
		XCTAssertEqual(collisionFreeLocalURL.relativePath, metadata.remotePath)
		XCTAssertFalse(FileManager.default.fileExists(atPath: localURL.path))
		XCTAssert(FileManager.default.fileExists(atPath: collisionFreeLocalURL.path))
	}

	func testCollisionHandlingUpload() throws {
		let expectation = XCTestExpectation()
		let localURL = tmpDirectory.appendingPathComponent("itemAlreadyExists.txt", isDirectory: false)
		try "".write(to: localURL, atomically: true, encoding: .utf8)
		let placeholderFileProviderItem = try decorator.createPlaceholderItemForFile(for: localURL, in: .rootContainer)
		_ = try decorator.registerFileInUploadQueue(with: localURL, identifier: placeholderFileProviderItem.itemIdentifier)
		decorator.collisionHandlingUpload(from: localURL, itemMetadata: placeholderFileProviderItem.metadata).then { item in
			XCTAssert(item.isUploaded)
			XCTAssertFalse(item.isUploading)
			XCTAssertNotEqual("itemAlreadyExists.txt", item.filename)
			XCTAssertNil(item.uploadTask)
			XCTAssertEqual(placeholderFileProviderItem.itemIdentifier, item.itemIdentifier)
			XCTAssertNil(try self.decorator.uploadTaskManager.getTask(for: item.metadata.id!))
			let parentFolder = localURL.deletingLastPathComponent()
			// Ensure that the file with the collision hash was uploaded
			XCTAssert(self.mockedProvider.createdFiles.keys.filter { $0.hasPrefix("\(parentFolder.path)/itemAlreadyExists (") && $0.hasSuffix(").txt") }.count == 1)
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 2.0)
	}

	func testDownloadFile() throws {
		let expectation = XCTestExpectation()
		let localURL = tmpDirectory.appendingPathComponent("localItem.txt", isDirectory: false)
		let remoteURL = URL(fileURLWithPath: "/File 1", isDirectory: false)
		let itemMetadata = ItemMetadata(id: 3, name: "File 1", type: .file, size: 14, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: remoteURL.relativePath, isPlaceholderItem: false)
		try decorator.itemMetadataManager.cacheMetadata(itemMetadata)
		let identifier = NSFileProviderItemIdentifier(String("3"))
		decorator.downloadFile(with: identifier, to: localURL).then {
			let localContent = try Data(contentsOf: localURL)
			XCTAssertEqual(self.mockedProvider.files[remoteURL.path], localContent)
			let lastModifiedDate = try self.decorator.cachedFileManager.getLastModifiedDate(for: 3)
			XCTAssertNotNil(lastModifiedDate)
			XCTAssertEqual(self.mockedProvider.lastModifiedDate[remoteURL.path], lastModifiedDate)
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 2.0)
	}

	func testRemoveItemFromCacheWithoutAnExistingLocalCachedFile() throws {
		let itemMetadata = ItemMetadata(id: 2, name: "TestFile", type: .file, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: "/Testfile", isPlaceholderItem: false)
		try decorator.itemMetadataManager.cacheMetadata(itemMetadata)
		try decorator.removeItemFromCache(with: 2)
		guard try decorator.itemMetadataManager.getCachedMetadata(for: 2) == nil else {
			XCTFail("ItemMetadata entry still exists")
			return
		}
	}

	func testRemoveItemFromCache() throws {
		let itemMetadata = ItemMetadata(id: 2, name: "TestFile", type: .file, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, remotePath: "/Testfile", isPlaceholderItem: false)
		try decorator.itemMetadataManager.cacheMetadata(itemMetadata)
		try decorator.cachedFileManager.cacheLocalFileInfo(for: 2, lastModifiedDate: Date(timeIntervalSinceReferenceDate: 0))
		let identifier = NSFileProviderItemIdentifier("2")
		guard let localURLForItem = decorator.urlForItem(withPersistentIdentifier: identifier) else {
			XCTFail("localURLForItem is nil")
			return
		}
		try FileManager.default.createDirectory(at: localURLForItem.deletingLastPathComponent(), withIntermediateDirectories: false, attributes: nil)
		let content = "TestLocalContent"
		try content.write(to: localURLForItem, atomically: true, encoding: .utf8)
		try decorator.removeItemFromCache(with: 2)
		guard try decorator.itemMetadataManager.getCachedMetadata(for: 2) == nil else {
			XCTFail("ItemMetadata entry still exists")
			return
		}
		guard try decorator.cachedFileManager.getLastModifiedDate(for: 2) == nil else {
			XCTFail("CachedFile entry still exists")
			return
		}
		XCTAssertFalse(FileManager.default.fileExists(atPath: localURLForItem.path))
	}
}
