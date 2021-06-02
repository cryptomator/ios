//
//  FileProviderDecoratorItemEnumerationTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 15.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Promises
import XCTest
@testable import CryptomatorFileProvider

class FileProviderDecoratorItemEnumerationTests: FileProviderDecoratorTestCase {
	func testWorkingSetReturnsEmptyItemList() {
		let expectation = XCTestExpectation()
		decorator.enumerateItems(for: .workingSet, withPageToken: nil).then { itemList in
			XCTAssert(itemList.items.isEmpty)
			XCTAssertNil(itemList.nextPageToken)
		}.catch { error in
			XCTFail("Error in promise: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testWorkingSetReturnsEmptyItemListWithPageTokenSet() {
		let expectation = XCTestExpectation()
		decorator.enumerateItems(for: .workingSet, withPageToken: "PageToken").then { itemList in
			XCTAssert(itemList.items.isEmpty)
			XCTAssertNil(itemList.nextPageToken)
		}.catch { error in
			XCTFail("Error in promise: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	// MARK: File

	func testFileEnumeration() throws {
		let expectation = XCTestExpectation()
		let path = CloudPath("/File 1")
		let fileMetadata = ItemMetadata(name: "File 1", type: .file, size: nil, parentId: MetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: path, isPlaceholderItem: false)
		try decorator.itemMetadataManager.cacheMetadata(fileMetadata)
		guard let id = fileMetadata.id else {
			XCTFail("ItemMetadata has no id")
			return
		}
		let identifier = NSFileProviderItemIdentifier("\(id)")
		decorator.enumerateItems(for: identifier, withPageToken: nil).then { itemList in
			XCTAssertEqual(1, itemList.items.count)
			XCTAssertNil(itemList.nextPageToken)
			guard let fetchedItemMetadata = try self.decorator.itemMetadataManager.getCachedMetadata(for: id) else {
				XCTFail("No Metadata in DB")
				return
			}
			XCTAssertEqual("File 1", fetchedItemMetadata.name)
			XCTAssertEqual(CloudItemType.file, fetchedItemMetadata.type)
			XCTAssertEqual(14, fetchedItemMetadata.size)
			XCTAssertEqual(MetadataDBManager.rootContainerId, fetchedItemMetadata.parentId)
			XCTAssertNotNil(fetchedItemMetadata.lastModifiedDate)
			XCTAssertEqual(ItemStatus.isUploaded, fetchedItemMetadata.statusCode)
			XCTAssertEqual(CloudPath("/File 1"), fetchedItemMetadata.cloudPath)
			XCTAssertFalse(fetchedItemMetadata.isPlaceholderItem)
			XCTAssertFalse(fetchedItemMetadata.isMaybeOutdated)

			let item = itemList.items[0]
			XCTAssertEqual(fetchedItemMetadata, item.metadata)
			XCTAssertNil(item.error)
			XCTAssertFalse(item.newestVersionLocallyCached)
			XCTAssertNil(item.localURL)
		}.catch { error in
			XCTFail("Error in promise: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testFileEnumerationPreservesUploadError() throws {
		let expectation = XCTestExpectation()
		let path = CloudPath("/File 1")
		let fileMetadata = ItemMetadata(name: "File 1", type: .file, size: nil, parentId: MetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: path, isPlaceholderItem: false)
		try decorator.itemMetadataManager.cacheMetadata(fileMetadata)
		guard let id = fileMetadata.id else {
			XCTFail("ItemMetadata has no id")
			return
		}
		var task = try decorator.uploadTaskManager.createNewTaskRecord(for: id)
		fileMetadata.statusCode = .uploadError
		try decorator.itemMetadataManager.updateMetadata(fileMetadata)
		try decorator.uploadTaskManager.updateTaskRecord(&task, error: NSFileProviderError(.insufficientQuota)._nsError)

		let identifier = NSFileProviderItemIdentifier("\(id)")
		decorator.enumerateItems(for: identifier, withPageToken: nil).then { itemList in
			XCTAssertEqual(1, itemList.items.count)
			XCTAssertNil(itemList.nextPageToken)
			guard let fetchedItemMetadata = try self.decorator.itemMetadataManager.getCachedMetadata(for: id) else {
				XCTFail("No Metadata in DB")
				return
			}
			XCTAssertEqual(ItemStatus.uploadError, fetchedItemMetadata.statusCode)
			guard let uploadTask = try self.decorator.uploadTaskManager.getTaskRecord(for: id) else {
				XCTFail("No UploadTask found for id")
				return
			}
			XCTAssertEqual(-1003, uploadTask.uploadErrorCode)
			XCTAssertEqual(NSFileProviderErrorDomain, uploadTask.uploadErrorDomain)
			XCTAssertNotNil(uploadTask.lastFailedUploadDate)

			let item = itemList.items[0]
			XCTAssertEqual(NSFileProviderError(.insufficientQuota)._nsError, item.uploadingError as NSError?)
		}.catch { error in
			XCTFail("Error in promise: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testFileEnumerationPreservesLocalCachedFileInfo() throws {
		let expectation = XCTestExpectation()
		let path = CloudPath("/File 1")
		let fileMetadata = ItemMetadata(name: "File 1", type: .file, size: nil, parentId: MetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: path, isPlaceholderItem: false)
		try decorator.itemMetadataManager.cacheMetadata(fileMetadata)
		guard let id = fileMetadata.id else {
			XCTFail("ItemMetadata has no id")
			return
		}

		let localURL = URL(fileURLWithPath: "/LocalFile 1")
		let lastModifiedDate = Date(timeIntervalSince1970: 0)
		try decorator.cachedFileManager.cacheLocalFileInfo(for: id, localURL: localURL, lastModifiedDate: lastModifiedDate)

		let identifier = NSFileProviderItemIdentifier("\(id)")
		decorator.enumerateItems(for: identifier, withPageToken: nil).then { itemList in
			XCTAssertEqual(1, itemList.items.count)
			XCTAssertNil(itemList.nextPageToken)
			guard let fetchedLocalFileInfo = try self.decorator.cachedFileManager.getLocalCachedFileInfo(for: id) else {
				XCTFail("No LocalCachedFileInfo in DB")
				return
			}
			XCTAssertEqual(lastModifiedDate, fetchedLocalFileInfo.lastModifiedDate)
			XCTAssertEqual(localURL, fetchedLocalFileInfo.localURL)

			guard let fetchedItemMetadata = try self.decorator.itemMetadataManager.getCachedMetadata(for: id) else {
				XCTFail("No Metadata in DB")
				return
			}
			XCTAssertEqual("File 1", fetchedItemMetadata.name)
			XCTAssertEqual(CloudItemType.file, fetchedItemMetadata.type)
			XCTAssertEqual(14, fetchedItemMetadata.size)
			XCTAssertEqual(MetadataDBManager.rootContainerId, fetchedItemMetadata.parentId)
			XCTAssertNotNil(fetchedItemMetadata.lastModifiedDate)
			XCTAssertEqual(ItemStatus.isUploaded, fetchedItemMetadata.statusCode)
			XCTAssertEqual(CloudPath("/File 1"), fetchedItemMetadata.cloudPath)
			XCTAssertFalse(fetchedItemMetadata.isPlaceholderItem)
			XCTAssertFalse(fetchedItemMetadata.isMaybeOutdated)

			let item = itemList.items[0]
			XCTAssertEqual(fetchedItemMetadata, item.metadata)
			XCTAssert(item.newestVersionLocallyCached)
			XCTAssertEqual(localURL, item.localURL)
		}.catch { error in
			XCTFail("Error in promise: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	func testEnumerationOnNonExistentFile() throws {
		let expectation = XCTestExpectation()
		let cloudPath = CloudPath("/itemNotFound")
		let folderMetadata = ItemMetadata(name: "ItemNotExistInCloud", type: .file, size: nil, parentId: MetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploading, cloudPath: cloudPath, isPlaceholderItem: true)
		try decorator.itemMetadataManager.cacheMetadata(folderMetadata)
		guard let id = folderMetadata.id else {
			XCTFail("FolderMetadata not saved in DB")
			return
		}
		let identifier = NSFileProviderItemIdentifier("\(id)")
		decorator.enumerateItems(for: identifier, withPageToken: nil).then { _ in
			XCTFail("Promise should not fulfill for non-existent File")
		}.catch { error in
			let nsError = error as NSError
			guard nsError.domain == NSFileProviderErrorDomain, nsError.code == NSFileProviderError.noSuchItem.rawValue else {
				XCTFail("Promise rejected but with the wrong error: \(error)")
				return
			}
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}

	// MARK: Folder

	func testFolderEnumeration() throws {
		let expectation = XCTestExpectation(description: "Folder Enumeration")
		let expectedRootFolderFileProviderItems = [FileProviderItem(metadata: ItemMetadata(id: 2, name: "Directory 1", type: .folder, size: 0, parentId: MetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/Directory 1/"), isPlaceholderItem: false)),
		                                           FileProviderItem(metadata: ItemMetadata(id: 3, name: "File 1", type: .file, size: 14, parentId: MetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/File 1"), isPlaceholderItem: false)),
		                                           FileProviderItem(metadata: ItemMetadata(id: 4, name: "File 2", type: .file, size: 14, parentId: MetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/File 3"), isPlaceholderItem: false)),
		                                           FileProviderItem(metadata: ItemMetadata(id: 5, name: "File 3", type: .file, size: 14, parentId: MetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/File 3"), isPlaceholderItem: false)),
		                                           FileProviderItem(metadata: ItemMetadata(id: 6, name: "File 4", type: .file, size: 14, parentId: MetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/File 4"), isPlaceholderItem: false))]
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
		let expectedRootFolderFileProviderItems = [FileProviderItem(metadata: ItemMetadata(id: 2, name: "Directory 1", type: .folder, size: 0, parentId: MetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/Directory 1/"), isPlaceholderItem: false)),
		                                           FileProviderItem(metadata: ItemMetadata(id: 3, name: "File 1", type: .file, size: 14, parentId: MetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/File 1"), isPlaceholderItem: false)),
		                                           FileProviderItem(metadata: ItemMetadata(id: 4, name: "File 2", type: .file, size: 14, parentId: MetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/File 3"), isPlaceholderItem: false)),
		                                           FileProviderItem(metadata: ItemMetadata(id: 5, name: "File 3", type: .file, size: 14, parentId: MetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/File 3"), isPlaceholderItem: false)),
		                                           FileProviderItem(metadata: ItemMetadata(id: 6, name: "File 4", type: .file, size: 14, parentId: MetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/File 4"), isPlaceholderItem: false))]
		let expectedChangedRootFolderFileProviderItems = [FileProviderItem(metadata: ItemMetadata(id: 2, name: "Directory 1", type: .folder, size: 0, parentId: MetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/Directory 1/"), isPlaceholderItem: false)),
		                                                  FileProviderItem(metadata: ItemMetadata(id: 4, name: "File 2", type: .file, size: 14, parentId: MetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/File 3"), isPlaceholderItem: false)),
		                                                  FileProviderItem(metadata: ItemMetadata(id: 5, name: "File 3", type: .file, size: 14, parentId: MetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/File 3"), isPlaceholderItem: false)),
		                                                  FileProviderItem(metadata: ItemMetadata(id: 6, name: "File 4", type: .file, size: 14, parentId: MetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/File 4"), isPlaceholderItem: false)),
		                                                  FileProviderItem(metadata: ItemMetadata(id: 7, name: "NewFileFromCloud", type: .file, size: 24, parentId: MetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/NewFileFromCloud"), isPlaceholderItem: false))]
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
		let id: Int64 = 3
		decorator.enumerateItems(for: .rootContainer, withPageToken: nil).then { _ -> Void in
			var task = try self.decorator.uploadTaskManager.createNewTaskRecord(for: id)
			guard let metadata = try self.decorator.itemMetadataManager.getCachedMetadata(for: id) else {
				XCTFail("No ItemMetadata for id found")
				return
			}
			metadata.statusCode = .uploadError
			try self.decorator.itemMetadataManager.updateMetadata(metadata)
			try self.decorator.uploadTaskManager.updateTaskRecord(&task, error: NSFileProviderError(.insufficientQuota)._nsError)
		}.then {
			return self.decorator.enumerateItems(for: .rootContainer, withPageToken: nil)
		}.then { fileProviderItemList in
			XCTAssertEqual(5, fileProviderItemList.items.count)
			let errorItem = fileProviderItemList.items[1]
			guard let fetchedItemMetadata = try self.decorator.itemMetadataManager.getCachedMetadata(for: id) else {
				XCTFail("No Metadata in DB")
				return
			}
			XCTAssertEqual(ItemStatus.uploadError, fetchedItemMetadata.statusCode)
			guard let uploadTask = try self.decorator.uploadTaskManager.getTaskRecord(for: id) else {
				XCTFail("No UploadTask found for id")
				return
			}
			XCTAssertEqual(-1003, uploadTask.uploadErrorCode)
			XCTAssertEqual(NSFileProviderErrorDomain, uploadTask.uploadErrorDomain)
			XCTAssertNotNil(uploadTask.lastFailedUploadDate)

			XCTAssertNotNil(errorItem.uploadingError)
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
		let itemMetadata = ItemMetadata(name: "TestItem", type: .file, size: nil, parentId: MetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/TestItem"), isPlaceholderItem: false)
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
			let cachedMetadata = try decorator.itemMetadataManager.getCachedMetadata(forParentId: MetadataDBManager.rootContainerId)
			let folderItem = cachedMetadata.first(where: { $0.name == "Folder" && $0.type == .folder })
			guard let folderIdentifier = folderItem?.id else {
				throw NSError(domain: "FileProviderDecoratorTestError", code: -100, userInfo: ["localizedDescription": "no Folder Id found!"])
			}
			return decorator.enumerateItems(for: NSFileProviderItemIdentifier("\(folderIdentifier)"), withPageToken: nil)
		}.then { _ -> Promise<FileProviderItemList> in
			let rootItem = ItemMetadata(id: MetadataDBManager.rootContainerId, name: "root", type: .folder, size: nil, parentId: MetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/"), isPlaceholderItem: false, isCandidateForCacheCleanup: false)
			let cachedMetadata = try decorator.itemMetadataManager.getAllCachedMetadata(inside: rootItem)
			XCTAssertEqual(8, cachedMetadata.count)
			paginatedMockedProvider.nextPageToken["0"] = nil
			paginatedMockedProvider.pages["1"] = nil
			return decorator.enumerateItems(for: .rootContainer, withPageToken: nil)
		}.then { fileProviderItemList in
			XCTAssertNil(fileProviderItemList.nextPageToken)
			XCTAssertEqual(2, fileProviderItemList.items.count)
			let cachedMetadata = try decorator.itemMetadataManager.getCachedMetadata(forParentId: MetadataDBManager.rootContainerId)
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

	func testEnumerationOnNonExistentFolder() throws {
		let expectation = XCTestExpectation()
		let cloudPath = CloudPath("/itemNotFound")
		let folderMetadata = ItemMetadata(name: "ItemNotExistInCloud", type: .folder, size: nil, parentId: MetadataDBManager.rootContainerId, lastModifiedDate: nil, statusCode: .isUploading, cloudPath: cloudPath, isPlaceholderItem: true)
		try decorator.itemMetadataManager.cacheMetadata(folderMetadata)
		guard let id = folderMetadata.id else {
			XCTFail("FolderMetadata not saved in DB")
			return
		}
		let identifier = NSFileProviderItemIdentifier("\(id)")
		decorator.enumerateItems(for: identifier, withPageToken: nil).then { _ in
			XCTFail("Promise should not fulfill for non-existent Folder")
		}.catch { error in
			let nsError = error as NSError
			guard nsError.domain == NSFileProviderErrorDomain, nsError.code == NSFileProviderError.noSuchItem.rawValue else {
				XCTFail("Promise rejected but with the wrong error: \(error)")
				return
			}
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 1.0)
	}
}
