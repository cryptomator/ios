//
//  FileProviderAdapterImportDocumentTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 05.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation
import Promises
import XCTest
@testable import CryptomatorCommonCore
@testable import CryptomatorFileProvider
@testable import Dependencies

class FileProviderAdapterImportDocumentTests: FileProviderAdapterTestCase {
	let itemID: Int64 = 2
	lazy var itemIdentifierDirectory = tmpDirectory.appendingPathComponent("\(itemID)", isDirectory: true)
	lazy var expectedFileURL = itemIdentifierDirectory.appendingPathComponent("ItemToBeImported.txt")

	override func setUpWithError() throws {
		try super.setUpWithError()
		localURLProviderMock.itemIdentifierDirectoryURLForItemWithPersistentIdentifierReturnValue = itemIdentifierDirectory
	}

	// MARK: LocalItemImport

	func testLocalItemImport() throws {
		let permissionProviderMock = PermissionProviderMock()
		DependencyValues.mockDependency(\.permissionProvider, with: permissionProviderMock)
		permissionProviderMock.getPermissionsForAtReturnValue = .allowsReading
		let fileURL = tmpDirectory.appendingPathComponent("ItemToBeImported.txt", isDirectory: false)
		let fileContent = "TestContent"
		try fileContent.write(to: fileURL, atomically: true, encoding: .utf8)
		let rootItemMetadata = ItemMetadata(id: NSFileProviderItemIdentifier.rootContainerDatabaseValue, name: "Home", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/"), isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(rootItemMetadata)

		let result = try adapter.localItemImport(fileURL: fileURL, parentIdentifier: .rootContainer)

		// Check that file was copied to the url provided by the localURLProvider
		XCTAssert(FileManager.default.fileExists(atPath: expectedFileURL.path))
		let contentOfCopiedFile = try String(data: Data(contentsOf: expectedFileURL), encoding: .utf8)
		XCTAssertEqual(fileContent, contentOfCopiedFile)
		// Check that the original file was not altered
		XCTAssert(FileManager.default.contentsEqual(atPath: fileURL.path, andPath: expectedFileURL.path))

		// Check that the correct uploadTask was created
		XCTAssertEqual([itemID], uploadTaskManagerMock.createNewTaskRecordForReceivedInvocations.map { $0.id! })

		// Check that the file was cached
		XCTAssertEqual(1, cachedFileManagerMock.cachedLocalFileInfo.count)
		guard let localCachedFileInfo = cachedFileManagerMock.cachedLocalFileInfo[itemID] else {
			XCTFail("LocalCachedFileInfo is nil")
			return
		}
		XCTAssertEqual(itemID, localCachedFileInfo.correspondingItem)
		XCTAssertEqual(expectedFileURL, localCachedFileInfo.localURL)

		try assertAllExpectedPropertiesSet(for: result.item)
		assertLocalURLProviderCalledWithItemID()
	}

	func testLocalItemImportFailsWhenNoLocalURLIsProvided() throws {
		localURLProviderMock.itemIdentifierDirectoryURLForItemWithPersistentIdentifierReturnValue = nil

		let fileURL = tmpDirectory.appendingPathComponent("ItemToBeImported.txt", isDirectory: false)
		let fileContent = "TestContent"
		try fileContent.write(to: fileURL, atomically: true, encoding: .utf8)

		let rootItemMetadata = ItemMetadata(id: NSFileProviderItemIdentifier.rootContainerDatabaseValue, name: "Home", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/"), isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(rootItemMetadata)

		XCTAssertThrowsError(try adapter.localItemImport(fileURL: fileURL, parentIdentifier: .rootContainer)) { error in
			guard NSFileProviderError(.noSuchItem) as NSError == error as NSError else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}
		XCTAssertFalse(uploadTaskManagerMock.createNewTaskRecordForCalled)
		assertLocalURLProviderCalledWithItemID()
	}

	func testLocalItemImportFailsIfItemAlreadyExistsAtLocalURL() throws {
		let fileURL = tmpDirectory.appendingPathComponent("ItemToBeImported.txt", isDirectory: false)
		let fileContent = "TestContent"
		try fileContent.write(to: fileURL, atomically: true, encoding: .utf8)
		// Simulate an existing folder structure and file at the URL of the localURLProvider
		try FileManager.default.createDirectory(at: expectedFileURL.deletingLastPathComponent(), withIntermediateDirectories: false)
		let existingFileContent = "ExistingFileContent"
		try existingFileContent.write(to: expectedFileURL, atomically: true, encoding: .utf8)
		let rootItemMetadata = ItemMetadata(id: NSFileProviderItemIdentifier.rootContainerDatabaseValue, name: "Home", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/"), isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(rootItemMetadata)

		XCTAssertThrowsError(try adapter.localItemImport(fileURL: fileURL, parentIdentifier: .rootContainer)) { error in
			guard case CocoaError.fileWriteFileExists = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}

		// Check that existing file at the url provided by the localURLProvider was not overwritten
		XCTAssert(FileManager.default.fileExists(atPath: expectedFileURL.path))
		let contentOfCopiedFile = try String(data: Data(contentsOf: expectedFileURL), encoding: .utf8)
		XCTAssertEqual(existingFileContent, contentOfCopiedFile)

		XCTAssertEqual(1, metadataManagerMock.removedMetadataID.count)
		XCTAssertEqual(itemID, metadataManagerMock.removedMetadataID[0])

		XCTAssertFalse(uploadTaskManagerMock.createNewTaskRecordForCalled)
		assertLocalURLProviderCalledWithItemID()
	}

	// MARK: Import Document

	func testImportDocument() throws {
		let expectation = XCTestExpectation()

		let rootItemMetadata = ItemMetadata(id: NSFileProviderItemIdentifier.rootContainerDatabaseValue, name: "Home", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/"), isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(rootItemMetadata)

		let fileURL = tmpDirectory.appendingPathComponent("ItemToBeImported.txt", isDirectory: false)
		let fileContent = "TestContent"
		try fileContent.write(to: fileURL, atomically: true, encoding: .utf8)

		let adapter = createFullyMockedAdapter()
		adapter.importDocument(at: fileURL, toParentItemIdentifier: .rootContainer) { item, error in
			XCTAssertNil(error)
			guard let item = item as? FileProviderItem else {
				XCTFail("Item is nil")
				return
			}
			XCTAssertEqual("ItemToBeImported.txt", item.filename)
			XCTAssertNil(item.uploadingError ?? nil)
			XCTAssert(item.isUploading)
			XCTAssert(item.newestVersionLocallyCached)
			XCTAssertEqual(self.expectedFileURL, item.localURL)

			// Check that file was copied to the url provided by the localURLProvider
			XCTAssert(FileManager.default.fileExists(atPath: self.expectedFileURL.path))
			let contentOfCopiedFile: String?
			do {
				contentOfCopiedFile = try String(data: Data(contentsOf: self.expectedFileURL), encoding: .utf8)
			} catch {
				XCTFail("Content of copied file failed with error: \(error)")
				return
			}
			XCTAssertEqual(fileContent, contentOfCopiedFile)
			// Check that the original file was not altered
			XCTAssert(FileManager.default.contentsEqual(atPath: fileURL.path, andPath: self.expectedFileURL.path))

			// Check that the correct uploadTask was created
			XCTAssertEqual([self.itemID], self.uploadTaskManagerMock.createNewTaskRecordForReceivedInvocations.map { $0.id })
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
		assertLocalURLProviderCalledWithItemID()
	}

	// MARK: ItemChanged

	func testItemChanged() throws {
		let cloudPath = CloudPath("/Item.txt")
		let itemMetadata = ItemMetadata(id: itemID, name: "Item.txt", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: cloudPath, isPlaceholderItem: false, isCandidateForCacheCleanup: false)
		metadataManagerMock.cachedMetadata[itemID] = itemMetadata
		let adapter = createFullyMockedAdapter()

		let fileURL = tmpDirectory.appendingPathComponent("/\(itemID)/Item.txt")
		try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: false)
		let fileContent = "TestContent"
		try fileContent.write(to: fileURL, atomically: true, encoding: .utf8)

		adapter.itemChanged(at: fileURL)

		XCTAssertEqual(1, metadataManagerMock.updatedMetadata.count)
		let updatedMetadata = metadataManagerMock.updatedMetadata[0]
		XCTAssertEqual(itemMetadata, updatedMetadata)
		XCTAssertEqual(ItemStatus.isUploading, updatedMetadata.statusCode)

		// Check that the local file info was cached
		XCTAssertEqual(1, cachedFileManagerMock.cachedLocalFileInfo.count)
		guard let cachedLocalFileInfo = cachedFileManagerMock.cachedLocalFileInfo[itemID] else {
			XCTFail("CachedLocalFileInfo is nil")
			return
		}
		XCTAssertEqual(itemID, cachedLocalFileInfo.correspondingItem)
		XCTAssertEqual(fileURL, cachedLocalFileInfo.localURL)

		// Check that the correct uploadTask was created
		XCTAssertEqual([itemID], uploadTaskManagerMock.createNewTaskRecordForReceivedInvocations.map { $0.id })
	}

	// MARK: Replace Existing

	// swiftlint:disable:next function_body_length
	func testReplaceExisting() throws {
		let expectation = XCTestExpectation()

		// Simulate delete item in cloud is not finished until `importDocument` locally succeeded
		let cloudProviderMock = CloudProviderMock()
		let deleteItemPromise = Promise<Void>.pending()
		let uploadItemPromise = deleteItemPromise.then { _ -> CloudItemMetadata in
			let metadata = CloudItemMetadata(name: "File 1", cloudPath: CloudPath("/File 1"), itemType: .file, lastModifiedDate: nil, size: 11)
			expectation.fulfill()
			return metadata
		}
		cloudProviderMock.deleteFileAtReturnValue = deleteItemPromise
		cloudProviderMock.uploadFileFromToReplaceExistingReturnValue = uploadItemPromise

		let rootItemMetadata = ItemMetadata(id: NSFileProviderItemIdentifier.rootContainerDatabaseValue, name: "Home", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/"), isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(rootItemMetadata)

		let itemFolderURL = tmpDirectory.appendingPathComponent("\(itemID)", isDirectory: true)
		try FileManager.default.createDirectory(at: itemFolderURL, withIntermediateDirectories: true)
		let expectedFileURL = itemFolderURL.appendingPathComponent("File 1", isDirectory: false)
		let existingFileContent = "Existing Content"
		try existingFileContent.write(to: expectedFileURL, atomically: true, encoding: .utf8)
		let existingItemMetadata = ItemMetadata(id: itemID, name: "File 1", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/File 1"), isPlaceholderItem: false, isCandidateForCacheCleanup: false)
		try metadataManagerMock.cacheMetadata(existingItemMetadata)
		try cachedFileManagerMock.cacheLocalFileInfo(for: itemID, localURL: expectedFileURL, lastModifiedDate: Date(timeIntervalSince1970: 0))

		let fileURL = tmpDirectory.appendingPathComponent("File 1", isDirectory: false)
		let fileContent = "TestContent"
		try fileContent.write(to: fileURL, atomically: true, encoding: .utf8)

		let adapter = FileProviderAdapter(domainIdentifier: .test, uploadTaskManager: uploadTaskManagerMock, cachedFileManager: cachedFileManagerMock, itemMetadataManager: metadataManagerMock, reparentTaskManager: reparentTaskManagerMock, deletionTaskManager: deletionTaskManagerMock, itemEnumerationTaskManager: itemEnumerationTaskManagerMock, downloadTaskManager: downloadTaskManagerMock, scheduler: WorkflowSchedulerMock(), provider: cloudProviderMock, coordinator: fileCoordinator, localURLProvider: localURLProviderMock, taskRegistrator: taskRegistratorMock)

		adapter.deleteItem(withIdentifier: NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: itemID), completionHandler: ({ error in
			XCTAssertNil(error)
			adapter.importDocument(at: fileURL, toParentItemIdentifier: .rootContainer, completionHandler: ({ item, error in
				XCTAssertNil(error)
				XCTAssertNotNil(item)
				guard let fileProviderItem = item as? FileProviderItem else {
					XCTFail("Can't cast to FileProviderItem")
					return
				}
				XCTAssertEqual(existingItemMetadata.name, fileProviderItem.metadata.name)
				XCTAssertEqual(existingItemMetadata.type, fileProviderItem.metadata.type)
				XCTAssertEqual(11, fileProviderItem.metadata.size)
				XCTAssertEqual(existingItemMetadata.parentID, fileProviderItem.metadata.parentID)
				XCTAssertEqual(.isUploading, fileProviderItem.metadata.statusCode)
				XCTAssert(fileProviderItem.metadata.isPlaceholderItem)
				XCTAssertFalse(fileProviderItem.metadata.isMaybeOutdated)

				XCTAssertEqual(expectedFileURL, fileProviderItem.localURL)

				// Check local file was overwritten
				do {
					let localFileContent = try String(contentsOf: expectedFileURL)
					XCTAssertEqual(fileContent, localFileContent)
				} catch {
					XCTFail("Read local file content from \(expectedFileURL) failed with error: \(error)")
				}

				// Check CachedFileInfo is updated
				guard let cachedLocalFileInfo = self.cachedFileManagerMock.cachedLocalFileInfo[self.itemID] else {
					XCTFail("CachedLocalFileInfo does not exists")
					return
				}
				XCTAssertEqual(expectedFileURL, cachedLocalFileInfo.localURL)
				XCTAssertEqual(self.itemID, cachedLocalFileInfo.correspondingItem)
				XCTAssertNotNil(cachedLocalFileInfo.lastModifiedDate)
				XCTAssertNotEqual(Date(timeIntervalSince1970: 0), cachedLocalFileInfo.lastModifiedDate)
				deleteItemPromise.fulfill(())
			}))
		}))
		wait(for: [expectation], timeout: 1.0)
		assertLocalURLProviderCalledWithItemID()
	}

	private func assertLocalURLProviderCalledWithItemID() {
		XCTAssertEqual([NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: itemID)], localURLProviderMock.itemIdentifierDirectoryURLForItemWithPersistentIdentifierReceivedInvocations)
	}

	private func assertAllExpectedPropertiesSet(for item: NSFileProviderItem) throws {
		let resourceValues = try expectedFileURL.resourceValues(forKeys: [.creationDateKey, .nameKey, .contentModificationDateKey, .typeIdentifierKey, .totalFileSizeKey])

		XCTAssertEqual(NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: itemID), item.itemIdentifier)
		XCTAssertEqual(.rootContainer, item.parentItemIdentifier)
		XCTAssertEqual(resourceValues.name, item.filename)
		XCTAssertEqual(resourceValues.contentModificationDate, item.contentModificationDate)
		XCTAssertEqual(resourceValues.typeIdentifier, item.typeIdentifier)
		XCTAssertEqual(resourceValues.totalFileSize as NSNumber?, item.documentSize)
		XCTAssertNotNil(item.capabilities)
	}
}
