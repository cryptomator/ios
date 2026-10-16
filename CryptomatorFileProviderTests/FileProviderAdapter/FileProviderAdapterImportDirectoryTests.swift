//
//  FileProviderAdapterImportDirectoryTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 21.03.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import XCTest
@testable import CryptomatorFileProvider

class FileProviderAdapterImportDirectoryTests: FileProviderAdapterTestCase {
	private lazy var localFileURL = tmpDirectory.appendingPathComponent("test.txt")

	override func setUp() async throws {
		try await super.setUp()
		let fileContent = "Content"
		try fileContent.write(to: localFileURL, atomically: true, encoding: .utf8)
	}

	func testImportDirectory() async throws {
		localURLProviderMock.itemIdentifierDirectoryURLForItemWithPersistentIdentifierClosure = { [tmpDirectory] in
			return tmpDirectory!.appendingPathComponent($0.rawValue)
		}
		metadataManagerMock.cachedMetadata[1] = ItemMetadata(item: .init(name: "/", cloudPath: CloudPath("/"), itemType: .folder, lastModifiedDate: nil, size: nil), withParentID: 1)
		let adapter = createPackageAdapter(provider: CloudProviderGraphMock(), scheduler: GraphWorkflowSchedulerMock())
		let directoryCount = 5
		var parentIdentifier: NSFileProviderItemIdentifier = .rootContainer

		for _ in 0 ..< directoryCount {
			parentIdentifier = try await createDirectoryWithFiles(adapter: adapter, parentIdentifier: parentIdentifier).itemIdentifier
		}
		// The completion handlers fire before the workflows run, so only the workflows settling marks their end.
		await adapter.awaitWorkflows()
		XCTAssertEqual(directoryCount * 2, fileProviderItemUpdateDelegateMock.signalUpdateForCallsCount)
	}

	// MARK: Cancellation

	func testProviderCancellationMarksPackageFileAsFailed() async throws {
		let provider = CloudProviderGraphMock()
		provider.failureByCloudPath[CloudPath("/Design Notes.rtfd/TXT.rtf")] = CancellationError()
		let adapter = createPackageAdapter(provider: provider, scheduler: GraphWorkflowSchedulerMock())
		let rootNode = try importPackage(adapter: adapter)
		let file = try XCTUnwrap(rootNode.children.first { $0.itemMetadata.name == "TXT.rtf" })

		try await adapter.schedulePackageFolder(rootNode, isRoot: true)

		try assertPersisted(file.itemMetadata, statusCode: .uploadError)
		let fileID = try XCTUnwrap(file.itemMetadata.id)
		let recordedError = uploadTaskManagerMock.updateTaskRecordWithLastFailedUploadDateUploadErrorCodeUploadErrorDomainReceivedInvocations.last { $0.id == fileID }
		XCTAssertEqual((CancellationError() as NSError).domain, recordedError?.uploadErrorDomain, "Recorded the cancellation as a different error")
		XCTAssertNotNil(try cachedFileManagerMock.cachedLocalFileInfo[XCTUnwrap(file.itemMetadata.id)], "Retry Upload needs the local copy")
	}

	func testProviderCancellationOnPackageFolderMarksWholeSubtree() async throws {
		let provider = CloudProviderGraphMock()
		provider.failureByCloudPath[CloudPath("/Design Notes.rtfd/Attachments")] = CancellationError()
		let scheduler = GraphWorkflowSchedulerMock()
		scheduler.failsTestOnRejection = false
		let adapter = createPackageAdapter(provider: provider, scheduler: scheduler)
		let rootNode = try importPackage(adapter: adapter)
		let attachments = try XCTUnwrap(rootNode.children.first { $0.itemMetadata.name == "Attachments" })
		let deep = try XCTUnwrap(attachments.children.first { $0.itemMetadata.name == "Deep" })
		let logo = try XCTUnwrap(attachments.children.first { $0.itemMetadata.name == "logo.png" })
		let note = try XCTUnwrap(deep.children.first)

		try await adapter.schedulePackageFolder(rootNode, isRoot: true)

		try assertPersisted(attachments.itemMetadata, statusCode: .uploadError)
		try assertPersisted(deep.itemMetadata, statusCode: .uploadError)
		try assertPersisted(logo.itemMetadata, statusCode: .uploadError)
		try assertPersisted(note.itemMetadata, statusCode: .uploadError)
		let markedFileIDs = uploadTaskManagerMock.updateTaskRecordWithLastFailedUploadDateUploadErrorCodeUploadErrorDomainReceivedInvocations.map { $0.id }
		XCTAssertEqual(Set([logo.itemMetadata.id, note.itemMetadata.id].compactMap { $0 }), Set(markedFileIDs), "Did not record a failure for every file below the cancelled folder")
		// The sibling subtree is independent and must be unaffected.
		XCTAssertNotNil(provider.virtualCloudFileSystem.getItem(at: CloudPath("/Design Notes.rtfd/TXT.rtf")))
	}

	private func importPackage(adapter: FileProviderAdapter) throws -> FileProviderAdapter.ImportedPackageNode {
		localURLProviderMock.itemIdentifierDirectoryURLForItemWithPersistentIdentifierClosure = { [tmpDirectory] identifier in
			guard let itemID = identifier.databaseValue else {
				return nil
			}
			return tmpDirectory!.appendingPathComponent("\(itemID)", isDirectory: true)
		}
		let rootItemMetadata = ItemMetadata(id: NSFileProviderItemIdentifier.rootContainerDatabaseValue, name: "Home", type: .folder, size: nil, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploaded, isPlaceholderItem: false)
		try metadataManagerMock.cacheMetadata(rootItemMetadata)
		let packageURL = tmpDirectory.appendingPathComponent("Design Notes.rtfd", isDirectory: true)
		let attachmentsURL = packageURL.appendingPathComponent("Attachments", isDirectory: true)
		let deepURL = attachmentsURL.appendingPathComponent("Deep", isDirectory: true)
		try FileManager.default.createDirectory(at: deepURL, withIntermediateDirectories: true)
		try "TestContent".write(to: packageURL.appendingPathComponent("TXT.rtf"), atomically: true, encoding: .utf8)
		try "Logo".write(to: attachmentsURL.appendingPathComponent("logo.png"), atomically: true, encoding: .utf8)
		try "Note".write(to: deepURL.appendingPathComponent("note.txt"), atomically: true, encoding: .utf8)
		return try adapter.localPackageImport(fileURL: packageURL, parentIdentifier: .rootContainer).rootNode
	}

	private func createDirectoryWithFiles(adapter: FileProviderAdapter, parentIdentifier: NSFileProviderItemIdentifier) async throws -> NSFileProviderItem {
		let createdItem = try await adapter.createDirectory(withName: "1", inParentItemIdentifier: parentIdentifier)
		let firstDirectoryItem = try XCTUnwrap(createdItem)
		_ = try await adapter.importDocument(at: localFileURL, toParentItemIdentifier: firstDirectoryItem.itemIdentifier)
		return firstDirectoryItem
	}
}
