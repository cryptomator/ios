//
//  FileProviderDecoratorFolderEnumerationTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 15.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import Promises
import XCTest
@testable import CryptomatorFileProvider
class FileProviderDecoratorFolderEnumerationTests: FileProviderDecoratorTestCase {
	func testFolderEnumeration() throws {
		let expectation = XCTestExpectation(description: "Folder Enumeration")
		let expectedRootFolderFileProviderItems = [FileProviderItem(metadata: ItemMetadata(id: 2, name: "Directory 1", type: .folder, size: 0, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/Directory 1/"), isPlaceholderItem: false)),
												   FileProviderItem(metadata: ItemMetadata(id: 3, name: "File 1", type: .file, size: 14, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/File 1"), isPlaceholderItem: false)),
												   FileProviderItem(metadata: ItemMetadata(id: 4, name: "File 2", type: .file, size: 14, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/File 3"), isPlaceholderItem: false)),
												   FileProviderItem(metadata: ItemMetadata(id: 5, name: "File 3", type: .file, size: 14, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/File 3"), isPlaceholderItem: false)),
												   FileProviderItem(metadata: ItemMetadata(id: 6, name: "File 4", type: .file, size: 14, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/File 4"), isPlaceholderItem: false))]
		let expectedSubFolderFileProviderItems = [FileProviderItem(metadata: ItemMetadata(id: 7, name: "Directory 2", type: .folder, size: 0, parentId: 2, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/Directory 1/Directory 2"), isPlaceholderItem: false)),
												  FileProviderItem(metadata: ItemMetadata(id: 8, name: "File 5", type: .file, size: 14, parentId: 2, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/Directory 1/File 5"), isPlaceholderItem: false))]
		decorator.enumerateItems(for: .rootContainer, withPageToken: nil).then { fileProviderItemList -> FileProviderItem in
			XCTAssertEqual(5, fileProviderItemList.items.count)
			XCTAssertEqual(expectedRootFolderFileProviderItems, fileProviderItemList.items)
			return fileProviderItemList.items[0]
		}.then { folderFileProviderItem in
			self.decorator.enumerateItems(for: folderFileProviderItem.itemIdentifier, withPageToken: nil)
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

	func testFolderEnumerationSameFolderTwice() throws {
		let expectation = XCTestExpectation(description: "Folder Enumeration")
		let expectedRootFolderFileProviderItems = [FileProviderItem(metadata: ItemMetadata(id: 2, name: "Directory 1", type: .folder, size: 0, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/Directory 1/"), isPlaceholderItem: false)),
												   FileProviderItem(metadata: ItemMetadata(id: 3, name: "File 1", type: .file, size: 14, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/File 1"), isPlaceholderItem: false)),
												   FileProviderItem(metadata: ItemMetadata(id: 4, name: "File 2", type: .file, size: 14, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/File 3"), isPlaceholderItem: false)),
												   FileProviderItem(metadata: ItemMetadata(id: 5, name: "File 3", type: .file, size: 14, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/File 3"), isPlaceholderItem: false)),
												   FileProviderItem(metadata: ItemMetadata(id: 6, name: "File 4", type: .file, size: 14, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/File 4"), isPlaceholderItem: false))]
		let expectedChangedRootFolderFileProviderItems = [FileProviderItem(metadata: ItemMetadata(id: 2, name: "Directory 1", type: .folder, size: 0, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/Directory 1/"), isPlaceholderItem: false)),
														  FileProviderItem(metadata: ItemMetadata(id: 4, name: "File 2", type: .file, size: 14, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/File 3"), isPlaceholderItem: false)),
														  FileProviderItem(metadata: ItemMetadata(id: 5, name: "File 3", type: .file, size: 14, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/File 3"), isPlaceholderItem: false)),
														  FileProviderItem(metadata: ItemMetadata(id: 6, name: "File 4", type: .file, size: 14, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/File 4"), isPlaceholderItem: false)),
														  FileProviderItem(metadata: ItemMetadata(id: 7, name: "NewFileFromCloud", type: .file, size: 24, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/NewFileFromCloud"), isPlaceholderItem: false))]
		decorator.enumerateItems(for: .rootContainer, withPageToken: nil).then { fileProviderItemList -> Promise<FileProviderItemList> in
			XCTAssertEqual(5, fileProviderItemList.items.count)
			XCTAssertEqual(expectedRootFolderFileProviderItems, fileProviderItemList.items)
			self.mockedProvider.files["/File 1"] = nil
			self.mockedProvider.files["/NewFileFromCloud"] = "NewFileFromCloud content".data(using: .utf8)!
			return self.decorator.enumerateItems(for: .rootContainer, withPageToken: nil)
		}.then { fileProviderItemList in
			XCTAssertEqual(5, fileProviderItemList.items.count)
			XCTAssertEqual(expectedChangedRootFolderFileProviderItems, fileProviderItemList.items)
		}.catch { error in
			XCTFail("Error in promise: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 2.0)
	}

	func testFolderEnumerationPreservesUploadError() throws {
		let expectation = XCTestExpectation()

		decorator.enumerateItems(for: .rootContainer, withPageToken: nil).then { _ -> Void in
			var task = try self.decorator.uploadTaskManager.createNewTask(for: 3)
			guard let metadata = try self.decorator.itemMetadataManager.getCachedMetadata(for: 3) else {
				XCTFail("No ItemMetadata for id found")
				return
			}
			metadata.statusCode = .uploadError
			try self.decorator.itemMetadataManager.updateMetadata(metadata)
			try self.decorator.uploadTaskManager.updateTask(&task, error: NSFileProviderError(.insufficientQuota)._nsError)
		}.then {
			return self.decorator.enumerateItems(for: .rootContainer, withPageToken: nil)
		}.then { fileProviderItemList in
			XCTAssertEqual(5, fileProviderItemList.items.count)
			let errorItem = fileProviderItemList.items[1]
			XCTAssertNotNil(errorItem.uploadingError)
			// XCTAssertEqual(ItemStatus.uploadError, errorItem.metadata.statusCode)
			XCTAssertEqual(NSFileProviderError(.insufficientQuota)._nsError, errorItem.uploadingError as NSError?)
		}.catch { error in
			XCTFail("Error in promise: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testPartialFolderEnumerationMarksMetadataAsMaybeOutdated() throws {
		let expectation = XCTestExpectation()
		let paginatedMockedProvider = CloudProviderPaginationMock()
		let domainIdentifier = NSFileProviderDomainIdentifier("test")
		let domain = NSFileProviderDomain(identifier: domainIdentifier, displayName: "", pathRelativeToDocumentStorage: "")
		guard let manager = NSFileProviderManager(for: domain) else {
			XCTFail("Manager is nil")
			return
		}
		let decorator = try FileProviderDecoratorMock(with: paginatedMockedProvider, for: domain, with: manager)
		let itemMetadata = ItemMetadata(name: "TestItem", type: .file, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/TestItem"), isPlaceholderItem: false)
		try decorator.itemMetadataManager.cacheMetadata(itemMetadata)
		XCTAssertFalse(itemMetadata.isMaybeOutdated)
		guard let id = itemMetadata.id else {
			XCTFail("id is nil")
			return
		}
		decorator.enumerateItems(for: .rootContainer, withPageToken: nil).then { fileProviderItemList in
			XCTAssertNotNil(fileProviderItemList.nextPageToken)
			XCTAssertEqual(2, fileProviderItemList.items.count)
			XCTAssertEqual(0, fileProviderItemList.items.filter { $0.metadata.id == itemMetadata.id }.count)
			guard let markedAsMaybeOutdatedCachedMetadata = try decorator.itemMetadataManager.getCachedMetadata(for: id) else {
				XCTFail("No ItemMetadata for id found")
				return
			}
			XCTAssert(markedAsMaybeOutdatedCachedMetadata.isMaybeOutdated)
		}.catch { error in
			XCTFail("Error in promise: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testFullFolderEnumerationRemovesInvalidatedCachedMetadata() throws {
		let expectation = XCTestExpectation()
		let paginatedMockedProvider = CloudProviderPaginationMock()
		let domainIdentifier = NSFileProviderDomainIdentifier("test")
		let domain = NSFileProviderDomain(identifier: domainIdentifier, displayName: "", pathRelativeToDocumentStorage: "")
		guard let manager = NSFileProviderManager(for: domain) else {
			XCTFail("Manager is nil")
			return
		}
		let decorator = try FileProviderDecoratorMock(with: paginatedMockedProvider, for: domain, with: manager)
		decorator.enumerateItems(for: .rootContainer, withPageToken: nil).then { fileProviderItemList -> Promise<FileProviderItemList> in
			XCTAssertNotNil(fileProviderItemList.nextPageToken)
			guard let tokenData = fileProviderItemList.nextPageToken, let nextPageToken = String(data: tokenData.rawValue, encoding: .utf8) else {
				throw NSError(domain: "FileProviderDecoratorTestError", code: -100, userInfo: ["localizedDescription": "No page Token"])
			}
			return decorator.enumerateItems(for: .rootContainer, withPageToken: nextPageToken)
		}.then { fileProviderItemList -> Promise<FileProviderItemList> in
			XCTAssertNil(fileProviderItemList.nextPageToken)
			let cachedMetadata = try decorator.itemMetadataManager.getCachedMetadata(forParentId: MetadataManager.rootContainerId)
			let folderItem = cachedMetadata.first(where: { $0.name == "Folder" && $0.type == .folder })
			guard let folderIdentifier = folderItem?.id else {
				throw NSError(domain: "FileProviderDecoratorTestError", code: -100, userInfo: ["localizedDescription": "no Folder Id found!"])
			}
			return decorator.enumerateItems(for: NSFileProviderItemIdentifier("\(folderIdentifier)"), withPageToken: nil)
		}.then { _ -> Promise<FileProviderItemList> in
			let rootItem = ItemMetadata(id: MetadataManager.rootContainerId, name: "root", type: .folder, size: nil, parentId: MetadataManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/"), isPlaceholderItem: false, isCandidateForCacheCleanup: false)
			let cachedMetadata = try decorator.itemMetadataManager.getAllCachedMetadata(inside: rootItem)
			XCTAssertEqual(8, cachedMetadata.count)
			paginatedMockedProvider.nextPageToken["0"] = nil
			paginatedMockedProvider.pages["1"] = nil
			return decorator.enumerateItems(for: .rootContainer, withPageToken: nil)
		}.then { fileProviderItemList in
			XCTAssertNil(fileProviderItemList.nextPageToken)
			XCTAssertEqual(2, fileProviderItemList.items.count)
			let cachedMetadata = try decorator.itemMetadataManager.getCachedMetadata(forParentId: MetadataManager.rootContainerId)
			XCTAssertEqual(2, cachedMetadata.count)
			XCTAssertFalse(cachedMetadata[0].isMaybeOutdated)
			XCTAssertFalse(cachedMetadata[1].isMaybeOutdated)
		}.catch { error in
			XCTFail("Error in promise: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testFolderEnumerationDidNotOverwriteReparentTask() throws {
		let expectation = XCTestExpectation()
		let newCloudPath = CloudPath("/RenamedItem")
		decorator.enumerateItems(for: .rootContainer, withPageToken: nil).then { itemList -> Promise<FileProviderItemList> in
			let item = itemList.items[1]
			XCTAssertEqual("File 1", item.filename)
			_ = try self.decorator.moveItemLocally(withIdentifier: item.itemIdentifier, toParentItemWithIdentifier: nil, newName: "RenamedItem")
			return self.decorator.enumerateItems(for: .rootContainer, withPageToken: nil)
		}.then { fileProviderItemList in
			XCTAssertEqual(5, fileProviderItemList.items.count)
			let renamedItem = fileProviderItemList.items.first(where: { $0.filename == "RenamedItem" })
			let oldItem = fileProviderItemList.items.first(where: { $0.filename == "File 1" })
			XCTAssertNil(oldItem)
			XCTAssertNotNil(renamedItem)
			XCTAssertEqual(ItemStatus.isUploading, renamedItem?.metadata.statusCode)
			XCTAssertEqual(newCloudPath, renamedItem?.metadata.cloudPath)
		}.catch { error in
			XCTFail("Error in promise: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testFolderEnumerationDidNotOverwriteDeletionTask() throws {
		let expectation = XCTestExpectation()
		decorator.enumerateItems(for: .rootContainer, withPageToken: nil).then { itemList -> Promise<FileProviderItemList> in
			let item = itemList.items[1]
			XCTAssertEqual("File 1", item.filename)
			_ = try self.decorator.deleteItemLocally(withIdentifier: item.itemIdentifier)
			return self.decorator.enumerateItems(for: .rootContainer, withPageToken: nil)
		}.then { fileProviderItemList in
			XCTAssertEqual(4, fileProviderItemList.items.count)
			XCTAssertFalse(fileProviderItemList.items.contains(where: { $0.filename == "File 1" }))
		}.catch { error in
			XCTFail("Error in promise: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}
}
