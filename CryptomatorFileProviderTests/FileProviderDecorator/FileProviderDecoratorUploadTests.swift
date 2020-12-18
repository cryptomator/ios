//
//  FileProviderDecoratorUploadTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 17.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import Promises
import XCTest
@testable import CryptomatorFileProvider
class FileProviderDecoratorUploadTests: FileProviderDecoratorTestCase {
	func testCreatePlaceholderItemForFile() throws {
		let localURL = tmpDirectory.appendingPathComponent("FileNotYetUploaded.txt", isDirectory: false)
		try "".write(to: localURL, atomically: true, encoding: .utf8)
		let actualFileProviderItem = try decorator.createPlaceholderItemForFile(for: localURL, in: .rootContainer)
		let expectedCloudPath = CloudPath("/FileNotYetUploaded.txt")
		XCTAssertEqual("2", actualFileProviderItem.itemIdentifier.rawValue)
		XCTAssertEqual("FileNotYetUploaded.txt", actualFileProviderItem.filename)
		XCTAssertEqual("public.plain-text", actualFileProviderItem.typeIdentifier)
		XCTAssertEqual(0, actualFileProviderItem.documentSize)
		XCTAssertEqual(NSFileProviderItemIdentifier.rootContainer, actualFileProviderItem.parentItemIdentifier)
		XCTAssertNotNil(actualFileProviderItem.contentModificationDate)
		XCTAssert(actualFileProviderItem.isUploading)
		XCTAssertEqual(expectedCloudPath, actualFileProviderItem.metadata.cloudPath)
		XCTAssert(actualFileProviderItem.metadata.isPlaceholderItem)
		let lastModifiedDateInCloud = try decorator.cachedFileManager.getLastModifiedDate(for: actualFileProviderItem.metadata.id!)
		XCTAssertNil(lastModifiedDateInCloud)
	}

	func skip_testCreatePlaceholderItemForFileWithNameCollision() throws {
		let localURL = tmpDirectory.appendingPathComponent("FileNotYetUploaded.txt", isDirectory: false)
		try "".write(to: localURL, atomically: true, encoding: .utf8)
		let expectedCloudPath = CloudPath("/FileNotYetUploaded.txt")
		let itemMetadata = ItemMetadata(name: "FileNotYetUploaded.txt", type: .file, size: 0, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: expectedCloudPath, isPlaceholderItem: false)
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
		mockedProvider.lastModifiedDate[itemMetadata.cloudPath.path] = mockedCloudDate
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
		XCTAssertEqual(mockedProvider.lastModifiedDate[itemMetadata.cloudPath.path], localLastModifiedDate)
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
			XCTAssertEqual(placeholderFileProviderItem.itemIdentifier, item.itemIdentifier)
			XCTAssert(item.metadata.cloudPath.path.hasPrefix("/itemAlreadyExists ("))
			XCTAssert(item.metadata.cloudPath.path.hasSuffix(").txt"))
			XCTAssertNil(try self.decorator.uploadTaskManager.getTask(for: item.metadata.id!))
			// Ensure that the file with the collision hash was uploaded
			XCTAssert(self.mockedProvider.createdFiles.keys.filter { $0.hasPrefix("/itemAlreadyExists (") && $0.hasSuffix(").txt") && $0.count == 30 }.count == 1)
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 2.0)
	}
}
