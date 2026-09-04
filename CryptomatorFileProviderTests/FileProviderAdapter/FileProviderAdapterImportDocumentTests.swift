//
//  FileProviderAdapterImportDocumentTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 05.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Dependencies
import Foundation
import XCTest
@testable import CryptomatorCommonCore
@testable import CryptomatorFileProvider
@testable import Promises

class FileProviderAdapterImportDocumentTests: FileProviderAdapterTestCase {
	let itemID: Int64 = 2
	/// Number of files in `createNestedPackage`.
	let packageFileCount = 5
	lazy var itemIdentifierDirectory = tmpDirectory.appendingPathComponent("\(itemID)", isDirectory: true)
	lazy var expectedFileURL = itemIdentifierDirectory.appendingPathComponent("ItemToBeImported.txt")

	override func setUpWithError() throws {
		try super.setUpWithError()
		// Per identifier, not one fixed directory for all: two same-named files in different interior folders of a package
		// would otherwise resolve to the same URL and collide with `fileWriteFileExists`.
		localURLProviderMock.itemIdentifierDirectoryURLForItemWithPersistentIdentifierClosure = { [tmpDirectory] identifier in
			guard let itemID = identifier.databaseValue else {
				return nil
			}
			return tmpDirectory!.appendingPathComponent("\(itemID)", isDirectory: true)
		}
	}

	// MARK: LocalItemImport

	func testLocalItemImport() throws {
		let permissionProviderMock = PermissionProviderMock()
		try withDependencies {
			$0.permissionProvider = permissionProviderMock
		} operation: {
			permissionProviderMock.getPermissionsForAtReturnValue = .allowsReading
			let fileURL = tmpDirectory.appendingPathComponent("ItemToBeImported.txt", isDirectory: false)
			let fileContent = "TestContent"
			try fileContent.write(to: fileURL, atomically: true, encoding: .utf8)
			try cacheRootItemMetadata()

			let result = try adapter.localItemImport(fileURL: fileURL, parentIdentifier: .rootContainer)

			XCTAssert(FileManager.default.fileExists(atPath: expectedFileURL.path))
			let contentOfCopiedFile = try String(data: Data(contentsOf: expectedFileURL), encoding: .utf8)
			XCTAssertEqual(fileContent, contentOfCopiedFile)
			XCTAssert(FileManager.default.contentsEqual(atPath: fileURL.path, andPath: expectedFileURL.path))
			XCTAssertEqual([itemID], uploadTaskManagerMock.createNewTaskRecordForReceivedInvocations.map { $0.id! })
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
	}

	func testLocalItemImportFailsWhenNoLocalURLIsProvided() throws {
		localURLProviderMock.itemIdentifierDirectoryURLForItemWithPersistentIdentifierClosure = nil
		localURLProviderMock.itemIdentifierDirectoryURLForItemWithPersistentIdentifierReturnValue = nil

		let fileURL = tmpDirectory.appendingPathComponent("ItemToBeImported.txt", isDirectory: false)
		let fileContent = "TestContent"
		try fileContent.write(to: fileURL, atomically: true, encoding: .utf8)

		try cacheRootItemMetadata()

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
		try cacheRootItemMetadata()

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

		try cacheRootItemMetadata()

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
		wait(for: [expectation], timeout: 5.0)
		assertLocalURLProviderCalledWithItemID()
	}

	// MARK: Packages

	func testLocalPackageImportCreatesRowsForEveryItem() throws {
		try cacheRootItemMetadata()
		let packageURL = try createPackage()

		let result = try adapter.localPackageImport(fileURL: packageURL, parentIdentifier: .rootContainer)

		XCTAssertEqual("Design Notes.rtfd", result.item.filename)
		XCTAssertEqual(.folder, result.rootNode.itemMetadata.type)
		XCTAssertEqual(["TXT.rtf"], result.rootNode.children.map { $0.itemMetadata.name })

		let child = try XCTUnwrap(result.rootNode.children.first)
		XCTAssertEqual(.file, child.itemMetadata.type)
		let localURL = try XCTUnwrap(child.localURL)
		XCTAssert(FileManager.default.fileExists(atPath: localURL.path))
		XCTAssert(FileManager.default.contentsEqual(atPath: packageURL.appendingPathComponent("TXT.rtf").path, andPath: localURL.path))
		XCTAssertEqual(localURL, try cachedFileManagerMock.cachedLocalFileInfo[XCTUnwrap(child.itemMetadata.id)]?.localURL)
	}

	func testLocalPackageImportWalksNestedPackage() throws {
		try cacheRootItemMetadata()
		let packageURL = try createNestedPackage()

		let result = try adapter.localPackageImport(fileURL: packageURL, parentIdentifier: .rootContainer)

		// Dot-files are part of the package and must not be skipped.
		XCTAssertEqual([".metadata", "Attachments", "TXT.rtf"], result.rootNode.children.map { $0.itemMetadata.name })
		let attachments = try XCTUnwrap(result.rootNode.children.first { $0.itemMetadata.name == "Attachments" })
		XCTAssertEqual(.folder, attachments.itemMetadata.type)
		XCTAssertNil(attachments.localURL)
		XCTAssertEqual(["Deep", "logo.png", "note.txt"], attachments.children.map { $0.itemMetadata.name })

		let deep = try XCTUnwrap(attachments.children.first { $0.itemMetadata.name == "Deep" })
		XCTAssertEqual(["note.txt"], deep.children.map { $0.itemMetadata.name })

		let deepFileID = try XCTUnwrap(deep.children.first?.itemMetadata.id)
		let resolvedPath = try metadataManagerMock.getCloudPath(for: deepFileID)
		XCTAssertEqual("/Design Notes.rtfd/Attachments/Deep/note.txt", resolvedPath.path)

		// Same leaf name in two interior folders, so a name-keyed local URL would have collided.
		let attachedNote = try XCTUnwrap(attachments.children.first { $0.itemMetadata.name == "note.txt" })
		XCTAssertNotEqual(try XCTUnwrap(attachedNote.localURL), try XCTUnwrap(deep.children.first?.localURL))
	}

	/// A folder must never be handed to `registerFileInUploadQueue`, whose `precondition` would crash the extension.
	func testPackageSchedulingNeverRegistersFolderMetadataForUpload() throws {
		try cacheRootItemMetadata()
		let packageURL = try createNestedPackage()
		let adapter = createPackageAdapter(provider: CloudProviderGraphMock(), scheduler: createGraphScheduler())

		let result = try adapter.localPackageImport(fileURL: packageURL, parentIdentifier: .rootContainer)
		wait(for: adapter.schedulePackageFolder(result.rootNode, isRoot: true), timeout: 30.0)

		let registeredTypes = uploadTaskManagerMock.createNewTaskRecordForReceivedInvocations.map { $0.type }
		XCTAssertEqual(packageFileCount, registeredTypes.count, "Did not register every package file")
		XCTAssert(registeredTypes.allSatisfy { $0 == .file }, "Registered a non-file for upload: \(registeredTypes)")
	}

	/// For a move the Files app deletes the source as soon as the handler fires, so the local copies are all the user has left.
	func testImportPackageReportsRootUpFrontAndKeepsRowsWhenTheRootFails() throws {
		try cacheRootItemMetadata()
		let packageURL = try createPackage()
		let provider = CloudProviderGraphMock()
		let scheduler = createGraphScheduler()
		scheduler.failsTestOnRejection = false
		let adapter = createPackageAdapter(provider: provider, scheduler: scheduler)
		provider.failureByCloudPath[CloudPath("/Design Notes.rtfd")] = CloudProviderError.noInternetConnection

		var reportedItem: NSFileProviderItem?
		var reportedError: Error?
		let scheduled = adapter.importPackage(at: packageURL, toParentItemIdentifier: .rootContainer) { item, error in
			reportedItem = item
			reportedError = error
		}

		XCTAssertNil(reportedError)
		XCTAssertEqual("Design Notes.rtfd", reportedItem?.filename)

		wait(for: scheduled, timeout: 30.0)

		let remaining = metadataManagerMock.cachedMetadata.values.filter { $0.id != NSFileProviderItemIdentifier.rootContainerDatabaseValue }
		XCTAssertEqual(2, remaining.count, "Rolled back a subtree after success was already reported")
		XCTAssertFalse(cachedFileManagerMock.cachedLocalFileInfo.isEmpty, "Deleted cached bytes after success was already reported")
		let root = try XCTUnwrap(remaining.first { $0.type == .folder })
		try assertPersisted(root, statusCode: .uploadError)
	}

	func testImportDocumentRoutesAPackageToThePackageImport() throws {
		try cacheRootItemMetadata()
		let packageURL = try createPackage()
		let scheduler = createGraphScheduler()
		let adapter = createPackageAdapter(provider: CloudProviderGraphMock(), scheduler: scheduler)

		let importPromise = adapter.importDocument(at: packageURL, toParentItemIdentifier: .rootContainer)
		wait(for: importPromise, timeout: 10.0)

		let item = try XCTUnwrap(importPromise.value ?? nil) as? FileProviderItem
		let rootItem = try XCTUnwrap(item)
		XCTAssertEqual("Design Notes.rtfd", rootItem.filename)
		// A package must not be routed to `localItemImport`, which rejects a directory with `folderUploadNotSupported`.
		XCTAssertEqual(.folder, rootItem.metadata.type)
		let children = metadataManagerMock.cachedMetadata.values.filter { $0.parentID == rootItem.metadata.id }
		XCTAssertEqual(["TXT.rtf"], children.map { $0.name })

		// The completion handler fires before scheduling, so without this the workflows would run on into the next test.
		let expectation = XCTestExpectation()
		DispatchQueue.global().async {
			XCTAssertEqual(.success, scheduler.dispatchGroup.wait(timeout: .now() + 30))
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 35)
	}

	func testImportPackageReportsCollisionWithoutFlatteningIt() throws {
		try cacheRootItemMetadata()
		let packageURL = try createPackage()
		let existingItemMetadata = ItemMetadata(name: "Design Notes.rtfd", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(existingItemMetadata)
		let adapter = createPackageAdapter(provider: CloudProviderGraphMock(), scheduler: createGraphScheduler())

		var reportedError: NSError?
		let scheduled = adapter.importPackage(at: packageURL, toParentItemIdentifier: .rootContainer) { _, error in
			reportedError = error as NSError?
		}

		XCTAssertEqual(NSFileProviderErrorDomain, reportedError?.domain)
		XCTAssertEqual(NSFileProviderError.filenameCollision.rawValue, reportedError?.code)
		// Fulfilled rather than rejected, because `importDocument` discards the returned promise.
		wait(for: scheduled, timeout: 10.0)
	}

	/// Nothing path-bearing may exist before the parent succeeded, because `recoverStuckUploads` picks up any record it finds.
	func testLocalPackageImportCreatesNoUploadTaskRecords() throws {
		try cacheRootItemMetadata()
		let packageURL = try createNestedPackage()

		_ = try adapter.localPackageImport(fileURL: packageURL, parentIdentifier: .rootContainer)

		XCTAssertFalse(uploadTaskManagerMock.createNewTaskRecordForCalled)
	}

	func testLocalPackageImportFailsForSymbolicLinkToFile() throws {
		try cacheRootItemMetadata()
		let packageURL = try createPackage()
		try FileManager.default.createSymbolicLink(atPath: packageURL.appendingPathComponent("link.rtf").path, withDestinationPath: "TXT.rtf")

		XCTAssertThrowsError(try adapter.localPackageImport(fileURL: packageURL, parentIdentifier: .rootContainer)) { error in
			guard case FileProviderAdapterError.symbolicLinkNotSupported = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}
		assertPackageImportRolledBack()
	}

	func testLocalPackageImportFailsForSymbolicLinkFormingDirectoryCycle() throws {
		try cacheRootItemMetadata()
		let packageURL = try createPackage()
		try FileManager.default.createSymbolicLink(at: packageURL.appendingPathComponent("cycle"), withDestinationURL: packageURL)

		XCTAssertThrowsError(try adapter.localPackageImport(fileURL: packageURL, parentIdentifier: .rootContainer)) { error in
			guard case FileProviderAdapterError.symbolicLinkNotSupported = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}
		assertPackageImportRolledBack()
	}

	func testLocalPackageImportRollsBackWholeSubtreeOnFailure() throws {
		try cacheRootItemMetadata()
		let packageURL = try createNestedPackage()
		// Sorted order is `Attachments` then `TXT.rtf`, so `Deep/note.txt` and `logo.png` are already imported by now.
		try FileManager.default.createSymbolicLink(atPath: packageURL.appendingPathComponent("zz-link.rtf").path, withDestinationPath: "TXT.rtf")

		XCTAssertThrowsError(try adapter.localPackageImport(fileURL: packageURL, parentIdentifier: .rootContainer))

		assertPackageImportRolledBack()
		XCTAssert(cachedFileManagerMock.cachedLocalFileInfo.isEmpty, "Left cached files behind: \(cachedFileManagerMock.cachedLocalFileInfo)")
		// Removing a cached file leaves its (now empty) item directory behind, exactly as deleting an item does.
		let itemDirectories = try FileManager.default.contentsOfDirectory(atPath: tmpDirectory.path).filter { Int64($0) != nil }
		for itemDirectory in itemDirectories {
			let contents = try FileManager.default.contentsOfDirectory(atPath: tmpDirectory.appendingPathComponent(itemDirectory).path)
			XCTAssert(contents.isEmpty, "Left copied bytes behind in \(itemDirectory): \(contents)")
		}
	}

	/// A pending deletion on the path must count as a collision, unlike in `checkLocalItemCollision`.
	func testLocalPackageImportReportsCollisionForRootWithPendingDeletion() throws {
		try cacheRootItemMetadata()
		let packageURL = try createPackage()
		let existingItemMetadata = ItemMetadata(name: "Design Notes.rtfd", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(existingItemMetadata)
		_ = try deletionTaskManagerMock.createTaskRecord(for: existingItemMetadata, cloudPath: CloudPath("/Design Notes.rtfd"))

		XCTAssertThrowsError(try adapter.localPackageImport(fileURL: packageURL, parentIdentifier: .rootContainer)) { error in
			XCTAssertEqual(NSFileProviderErrorDomain, (error as NSError).domain)
			XCTAssertEqual(NSFileProviderError.filenameCollision.rawValue, (error as NSError).code)
		}
	}

	func testImportDocumentReportsPlainDirectoryAsNoSuchItem() throws {
		try cacheRootItemMetadata()
		let directoryURL = tmpDirectory.appendingPathComponent("Plain Folder", isDirectory: true)
		try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: false)
		try "content".write(to: directoryURL.appendingPathComponent("child.txt"), atomically: true, encoding: .utf8)
		let cachedMetadataCount = metadataManagerMock.cachedMetadata.count

		let adapter = createFullyMockedAdapter()

		XCTAssertRejects(adapter.importDocument(at: directoryURL, toParentItemIdentifier: .rootContainer), with: NSFileProviderError(.noSuchItem))
		XCTAssertEqual(cachedMetadataCount, metadataManagerMock.cachedMetadata.count, "Created a placeholder row for a plain directory")
		XCTAssertFalse(uploadTaskManagerMock.createNewTaskRecordForCalled)
	}

	/**
	 Uses a path that cannot be inspected, because for anything that exists the resource value answers first and the fallback
	 this pins is never reached.
	 */
	func testUninspectableItemWithUnregisteredExtensionIsNotTreatedAsPackage() {
		XCTAssertFalse(adapter.isPackage(at: tmpDirectory.appendingPathComponent("Gone.unregisteredext", isDirectory: true)))
	}

	func testDirectoryWithUnregisteredExtensionIsNotTreatedAsPackage() throws {
		let directoryURL = tmpDirectory.appendingPathComponent("Archive.unregisteredext", isDirectory: true)
		try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: false)

		XCTAssertFalse(adapter.isPackage(at: directoryURL))
	}

	func testPackageIsTreatedAsPackage() throws {
		let packageURL = try createPackage()

		XCTAssert(adapter.isPackage(at: packageURL))
	}

	/// iWork writes flat documents that carry a declared package extension, so the extension alone must never decide.
	func testFlatFileWithPackageExtensionIsNotTreatedAsPackage() throws {
		let fileURL = tmpDirectory.appendingPathComponent("Flat.rtfd", isDirectory: false)
		try "TestContent".write(to: fileURL, atomically: true, encoding: .utf8)

		XCTAssertFalse(adapter.isPackage(at: fileURL))
	}

	/// Reaches the fallback, because the resource value cannot be read for an item that is not there.
	func testUninspectableItemWithPackageExtensionIsNotTreatedAsPackage() {
		XCTAssertFalse(adapter.isPackage(at: tmpDirectory.appendingPathComponent("Gone.rtfd", isDirectory: true)))
	}

	/// Rollback finds copied bytes only via their cached-file row.
	func testLocalPackageImportRemovesCopiedBytesWhenCachingThemFails() throws {
		try cacheRootItemMetadata()
		let packageURL = try createPackage()
		cachedFileManagerMock.cacheLocalFileInfoThrowableError = CloudProviderError.noInternetConnection

		XCTAssertThrowsError(try adapter.localPackageImport(fileURL: packageURL, parentIdentifier: .rootContainer))

		let itemDirectories = try FileManager.default.contentsOfDirectory(atPath: tmpDirectory.path).filter { Int64($0) != nil }
		for itemDirectory in itemDirectories {
			let contents = try FileManager.default.contentsOfDirectory(atPath: tmpDirectory.appendingPathComponent(itemDirectory).path)
			XCTAssert(contents.isEmpty, "Left cleartext behind in \(itemDirectory): \(contents)")
		}
		assertPackageImportRolledBack()
	}

	/// Only reachable through `localPackageImport` directly: `isPackage` reports `false` for a link, so `importDocument`
	/// routes a symbolic link to the ordinary single-file path instead.
	func testLocalPackageImportRejectsASymbolicLinkRoot() throws {
		try cacheRootItemMetadata()
		let packageURL = try createPackage()
		let linkURL = tmpDirectory.appendingPathComponent("Link.rtfd", isDirectory: true)
		try FileManager.default.createSymbolicLink(at: linkURL, withDestinationURL: packageURL)

		XCTAssertThrowsError(try adapter.localPackageImport(fileURL: linkURL, parentIdentifier: .rootContainer)) { error in
			guard case FileProviderAdapterError.symbolicLinkNotSupported = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}
	}

	func testLocalPackageImportNormalizesEveryPathComponentToNFC() throws {
		try cacheRootItemMetadata()
		let nfdFolderName = "Anha\u{0308}nge"
		let nfcFolderName = "Anhänge"
		let nfdFileName = "Erho\u{0308}hung.txt"
		let nfcFileName = "Erhöhung.txt"
		XCTAssertNotEqual(Array(nfdFolderName.utf8), Array(nfcFolderName.utf8))

		let packageURL = tmpDirectory.appendingPathComponent("Design Notes.rtfd", isDirectory: true)
		let interiorURL = packageURL.appendingPathComponent(nfdFolderName, isDirectory: true)
		try FileManager.default.createDirectory(at: interiorURL, withIntermediateDirectories: true)
		try "TestContent".write(to: interiorURL.appendingPathComponent(nfdFileName), atomically: true, encoding: .utf8)

		let result = try adapter.localPackageImport(fileURL: packageURL, parentIdentifier: .rootContainer)

		let interior = try XCTUnwrap(result.rootNode.children.first)
		// Swift string equality treats NFD and NFC as equal, so only the bytes prove normalization happened.
		XCTAssertEqual(Array(nfcFolderName.utf8), Array(interior.itemMetadata.name.utf8))
		let file = try XCTUnwrap(interior.children.first)
		XCTAssertEqual(Array(nfcFileName.utf8), Array(file.itemMetadata.name.utf8))
		let resolvedPath = try metadataManagerMock.getCloudPath(for: XCTUnwrap(file.itemMetadata.id))
		XCTAssertEqual(Array("/Design Notes.rtfd/\(nfcFolderName)/\(nfcFileName)".utf8), Array(resolvedPath.path.utf8))
	}

	// MARK: Package Scheduling

	/**
	 Observes task *construction* rather than scheduling, because an implementation that builds child workflows eagerly and only
	 defers `schedule` would already have snapshotted a stale path and registered dependency state.
	 */
	func testFailedPackageFolderNeverConstructsTasksForItsDescendants() throws {
		try cacheRootItemMetadata()
		let packageURL = try createNestedPackage()
		let provider = CloudProviderGraphMock()
		let scheduler = createGraphScheduler()
		scheduler.failsTestOnRejection = false
		let adapter = createPackageAdapter(provider: provider, scheduler: scheduler)

		let result = try adapter.localPackageImport(fileURL: packageURL, parentIdentifier: .rootContainer)
		let attachments = try XCTUnwrap(result.rootNode.children.first { $0.itemMetadata.name == "Attachments" })
		let logo = try XCTUnwrap(attachments.children.first { $0.itemMetadata.name == "logo.png" })
		let deep = try XCTUnwrap(attachments.children.first { $0.itemMetadata.name == "Deep" })
		let note = try XCTUnwrap(deep.children.first)
		let sibling = try XCTUnwrap(result.rootNode.children.first { $0.itemMetadata.name == "TXT.rtf" })
		provider.failureByCloudPath[CloudPath("/Design Notes.rtfd/Attachments")] = CloudProviderError.noInternetConnection

		metadataManagerMock.getCloudPathForReceivedInvocations.removeAll()
		wait(for: adapter.schedulePackageFolder(result.rootNode, isRoot: true), timeout: 30.0)

		let constructedFor = Set(metadataManagerMock.getCloudPathForReceivedInvocations)
		XCTAssertFalse(try constructedFor.contains(XCTUnwrap(deep.itemMetadata.id)), "Constructed a task for a folder below a failed folder")
		XCTAssertFalse(try constructedFor.contains(XCTUnwrap(logo.itemMetadata.id)), "Constructed a task for a file below a failed folder")
		XCTAssertFalse(try constructedFor.contains(XCTUnwrap(note.itemMetadata.id)), "Constructed a task for a nested file below a failed folder")
		let registeredIDs = uploadTaskManagerMock.createNewTaskRecordForReceivedInvocations.map { $0.id! }
		XCTAssertFalse(try registeredIDs.contains(XCTUnwrap(logo.itemMetadata.id)))
		XCTAssertFalse(try registeredIDs.contains(XCTUnwrap(note.itemMetadata.id)))

		// The sibling subtree is independent and must be unaffected.
		XCTAssertNotNil(provider.virtualCloudFileSystem.getItem(at: CloudPath("/Design Notes.rtfd/TXT.rtf")))
		XCTAssert(try registeredIDs.contains(XCTUnwrap(sibling.itemMetadata.id)))

		// Failed after the completion handler already reported success, so the local subtree survives and is marked instead.
		try assertPersisted(attachments.itemMetadata, statusCode: .uploadError)
		XCTAssertNotNil(try metadataManagerMock.cachedMetadata[XCTUnwrap(deep.itemMetadata.id)])
		XCTAssertNotNil(try metadataManagerMock.cachedMetadata[XCTUnwrap(note.itemMetadata.id)])
		XCTAssertNotNil(try cachedFileManagerMock.cachedLocalFileInfo[XCTUnwrap(note.itemMetadata.id)])
	}

	func testCollidingPackageRootIsRenamedAndImportSucceeds() throws {
		try cacheRootItemMetadata()
		let packageURL = try createPackage()
		let provider = CloudProviderGraphMock()
		try provider.virtualCloudFileSystem.createItem(at: CloudPath("/Design Notes.rtfd"), metadata: .init(name: "Design Notes.rtfd", cloudPath: CloudPath("/Design Notes.rtfd"), itemType: .folder, lastModifiedDate: nil, size: nil))
		let adapter = createPackageAdapter(provider: provider, scheduler: createGraphScheduler())

		let result = try adapter.localPackageImport(fileURL: packageURL, parentIdentifier: .rootContainer)
		wait(for: adapter.schedulePackageFolder(result.rootNode, isRoot: true), timeout: 30.0)

		let renamedName = result.rootNode.itemMetadata.name
		XCTAssertNotEqual("Design Notes.rtfd", renamedName)
		XCTAssert(renamedName.hasPrefix("Design Notes ("), "Unexpected collision name: \(renamedName)")
		XCTAssert(renamedName.hasSuffix(").rtfd"), "Unexpected collision name: \(renamedName)")
		try assertPersisted(result.rootNode.itemMetadata, name: renamedName, statusCode: .isUploaded)
		// Nothing was written into the folder that was already there.
		XCTAssert(try XCTUnwrap(provider.virtualCloudFileSystem.getItem(at: CloudPath("/Design Notes.rtfd"))).children.isEmpty)
		XCTAssertNotNil(provider.virtualCloudFileSystem.getItem(at: CloudPath("/\(renamedName)/TXT.rtf")))

		// Without a signal per node the subtree only shows up on the next enumeration.
		let signalledNames = fileProviderItemUpdateDelegateMock.signalUpdateForReceivedInvocations.map { $0.filename }
		XCTAssert(signalledNames.contains(renamedName), "Never signalled the package root: \(signalledNames)")
		XCTAssert(signalledNames.contains("TXT.rtf"), "Never signalled the package child: \(signalledNames)")
	}

	/// Renaming a component inside a package changes user data, so an interior collision has to fail rather than rename.
	func testCollidingInteriorPackageFolderFailsWithoutRenamingAnything() throws {
		try cacheRootItemMetadata()
		let packageURL = try createNestedPackage()
		let provider = CloudProviderGraphMock()
		let scheduler = createGraphScheduler()
		scheduler.failsTestOnRejection = false
		let adapter = createPackageAdapter(provider: provider, scheduler: scheduler)
		provider.failureByCloudPath[CloudPath("/Design Notes.rtfd/Attachments")] = CloudProviderError.itemAlreadyExists

		let result = try adapter.localPackageImport(fileURL: packageURL, parentIdentifier: .rootContainer)
		let attachments = try XCTUnwrap(result.rootNode.children.first { $0.itemMetadata.name == "Attachments" })
		wait(for: adapter.schedulePackageFolder(result.rootNode, isRoot: true), timeout: 30.0)

		try assertPersisted(attachments.itemMetadata, name: "Attachments", statusCode: .uploadError)
		// The root's own files still upload; only `Attachments` must be missing, and nothing like `Attachments (1)` may appear.
		let packageChildren = try XCTUnwrap(provider.virtualCloudFileSystem.getItem(at: CloudPath("/Design Notes.rtfd"))).children.map { $0.metadata.name }
		XCTAssertEqual([".metadata", "TXT.rtf"], packageChildren.sorted(), "A collision-generated interior object was created remotely")
	}

	func testCreateDirectoryOutsideAPackageStillRenamesOnCollision() throws {
		try cacheRootItemMetadata()
		let provider = CloudProviderGraphMock()
		try provider.virtualCloudFileSystem.createItem(at: CloudPath("/Reports"), metadata: .init(name: "Reports", cloudPath: CloudPath("/Reports"), itemType: .folder, lastModifiedDate: nil, size: nil))
		let scheduler = createGraphScheduler()
		let adapter = createPackageAdapter(provider: provider, scheduler: scheduler)

		let createDirectoryPromise = adapter.createDirectory(withName: "Reports", inParentItemIdentifier: .rootContainer)
		wait(for: createDirectoryPromise, timeout: 10.0)
		let item = try XCTUnwrap(createDirectoryPromise.value ?? nil) as? FileProviderItem
		let placeholderItem = try XCTUnwrap(item)
		let expectation = XCTestExpectation()
		DispatchQueue.global().async {
			XCTAssertEqual(.success, scheduler.dispatchGroup.wait(timeout: .now() + 30))
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 35)

		let renamedName = placeholderItem.metadata.name
		XCTAssertNotEqual("Reports", renamedName)
		XCTAssert(renamedName.hasPrefix("Reports ("), "Unexpected collision name: \(renamedName)")
	}

	/// A file upload never reaches the collision handler, so it is never renamed; the orchestration only classifies the result.
	func testCollidingPackageFileSurfacesAsFilenameCollision() throws {
		try cacheRootItemMetadata()
		let packageURL = try createPackage()
		let provider = CloudProviderGraphMock()
		let scheduler = createGraphScheduler()
		let adapter = createPackageAdapter(provider: provider, scheduler: scheduler)
		provider.failureByCloudPath[CloudPath("/Design Notes.rtfd/TXT.rtf")] = CloudProviderError.itemAlreadyExists

		let result = try adapter.localPackageImport(fileURL: packageURL, parentIdentifier: .rootContainer)
		let child = try XCTUnwrap(result.rootNode.children.first)
		wait(for: adapter.schedulePackageFolder(result.rootNode, isRoot: true), timeout: 30.0)

		try assertPersisted(child.itemMetadata, name: "TXT.rtf", statusCode: .uploadError)
		let recordedError = uploadTaskManagerMock.updateTaskRecordWithLastFailedUploadDateUploadErrorCodeUploadErrorDomainReceivedInvocations.last
		XCTAssertEqual(NSFileProviderErrorDomain, recordedError?.uploadErrorDomain)
		XCTAssertEqual(NSFileProviderError.filenameCollision.rawValue, recordedError?.uploadErrorCode)
		XCTAssertNotEqual(NSFileProviderError.serverUnreachable.rawValue, recordedError?.uploadErrorCode)
	}

	// MARK: ItemChanged

	func testItemChanged() throws {
		let cloudPath = CloudPath("/Item.txt")
		let itemMetadata = ItemMetadata(id: itemID, name: "Item.txt", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false, isCandidateForCacheCleanup: false)
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

		try cacheRootItemMetadata()

		let itemFolderURL = tmpDirectory.appendingPathComponent("\(itemID)", isDirectory: true)
		try FileManager.default.createDirectory(at: itemFolderURL, withIntermediateDirectories: true)
		let expectedFileURL = itemFolderURL.appendingPathComponent("File 1", isDirectory: false)
		let existingFileContent = "Existing Content"
		try existingFileContent.write(to: expectedFileURL, atomically: true, encoding: .utf8)
		let existingItemMetadata = ItemMetadata(id: itemID, name: "File 1", type: .file, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false, isCandidateForCacheCleanup: false)
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
		wait(for: [expectation], timeout: 5.0)
		assertLocalURLProviderCalledWithItemID()
	}

	// MARK: Unicode Normalization

	func testLocalItemImportNormalizesNFDFilenameToNFC() throws {
		let permissionProviderMock = PermissionProviderMock()
		try withDependencies {
			$0.permissionProvider = permissionProviderMock
		} operation: {
			permissionProviderMock.getPermissionsForAtReturnValue = .allowsReading

			let nfdName = "Erh\u{006F}\u{0308}hung.pdf"
			let nfcName = "Erhöhung.pdf"
			XCTAssertEqual(nfdName, nfcName)
			XCTAssertNotEqual(Array(nfdName.utf8), Array(nfcName.utf8))

			let fileURL = tmpDirectory.appendingPathComponent(nfdName, isDirectory: false)
			try "test".write(to: fileURL, atomically: true, encoding: .utf8)

			try cacheRootItemMetadata()

			let result = try adapter.localItemImport(fileURL: fileURL, parentIdentifier: .rootContainer)

			let storedName = result.item.filename
			XCTAssertEqual(Array(storedName.utf8), Array(nfcName.utf8), "Filename should be stored in NFC form")
		}
	}

	/// The Files app hands over packages such as `.rtfd` as directories.
	private func createPackage() throws -> URL {
		let packageURL = tmpDirectory.appendingPathComponent("Design Notes.rtfd", isDirectory: true)
		try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: false)
		try "TestContent".write(to: packageURL.appendingPathComponent("TXT.rtf"), atomically: true, encoding: .utf8)
		return packageURL
	}

	/**
	 A nested package, so that parent-before-child chaining is actually exercised.

	 Package types that are nested by nature tend to be declared by apps a stock simulator does not have, which would make the
	 package check reject them for reasons unrelated to what is under test, so a nested `.rtfd` stands in for them.
	 */
	private func createNestedPackage() throws -> URL {
		let packageURL = tmpDirectory.appendingPathComponent("Design Notes.rtfd", isDirectory: true)
		let attachmentsURL = packageURL.appendingPathComponent("Attachments", isDirectory: true)
		let deepURL = attachmentsURL.appendingPathComponent("Deep", isDirectory: true)
		try FileManager.default.createDirectory(at: deepURL, withIntermediateDirectories: true)
		try "Metadata".write(to: packageURL.appendingPathComponent(".metadata"), atomically: true, encoding: .utf8)
		try "TestContent".write(to: packageURL.appendingPathComponent("TXT.rtf"), atomically: true, encoding: .utf8)
		try "Logo".write(to: attachmentsURL.appendingPathComponent("logo.png"), atomically: true, encoding: .utf8)
		try "Attached note".write(to: attachmentsURL.appendingPathComponent("note.txt"), atomically: true, encoding: .utf8)
		try "Note".write(to: deepURL.appendingPathComponent("note.txt"), atomically: true, encoding: .utf8)
		return packageURL
	}

	private func cacheRootItemMetadata() throws {
		let rootItemMetadata = ItemMetadata(id: NSFileProviderItemIdentifier.rootContainerDatabaseValue, name: "Home", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(rootItemMetadata)
	}

	private func assertPackageImportRolledBack(file: StaticString = #filePath, line: UInt = #line) {
		let remaining = metadataManagerMock.cachedMetadata.values.filter { $0.id != NSFileProviderItemIdentifier.rootContainerDatabaseValue }
		XCTAssert(remaining.isEmpty, "Left metadata behind: \(remaining.map { $0.name })", file: file, line: line)
		XCTAssertFalse(uploadTaskManagerMock.createNewTaskRecordForCalled, file: file, line: line)
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
