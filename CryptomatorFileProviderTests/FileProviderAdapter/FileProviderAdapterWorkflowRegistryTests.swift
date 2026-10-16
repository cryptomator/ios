//
//  FileProviderAdapterWorkflowRegistryTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Tobias Hagemann on 15.10.26.
//  Copyright © 2026 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Foundation
import os
import XCTest
@testable import CryptomatorFileProvider

class FileProviderAdapterWorkflowRegistryTests: FileProviderAdapterTestCase {
	private let itemID: Int64 = 3
	private lazy var itemIdentifier = NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: itemID)

	override func setUp() async throws {
		try await super.setUp()
		metadataManagerMock.cachedMetadata[itemID] = ItemMetadata(id: itemID, name: "upload.txt", type: .file, size: 100, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: nil, statusCode: .isUploading, isPlaceholderItem: false)
	}

	func testUploadsForTheSameItemStayRegisteredUntilEachFinishes() async throws {
		let localURL = tmpDirectory.appendingPathComponent("upload.txt")
		try Data("Upload content".utf8).write(to: localURL)
		try cachedFileManagerMock.cacheLocalFileInfo(for: itemID, localURL: localURL, lastModifiedDate: nil)
		let uploadsStarted = [XCTestExpectation(description: "First upload started"), XCTestExpectation(description: "Second upload started")]
		let uploadCompletions = [OneShotSignal<Void>(), OneShotSignal<Void>()]
		let uploadCount = OSAllocatedUnfairLock(initialState: 0)
		let provider = CloudProviderErrorMock()
		provider.uploadFileResponse = { localURL, cloudPath, _ in
			let index = uploadCount.withLock { count in
				defer { count += 1 }
				return count
			}
			uploadsStarted[index].fulfill()
			try await uploadCompletions[index].value
			return try CloudItemMetadata(name: cloudPath.lastPathComponent, cloudPath: cloudPath, itemType: .file, lastModifiedDate: nil, size: Data(contentsOf: localURL).count)
		}
		let adapter = createAdapter(provider: provider)
		let taskRecord = UploadTaskRecord(correspondingItem: itemID, lastFailedUploadDate: nil, uploadErrorCode: nil, uploadErrorDomain: nil, uploadStartedAt: Date())

		adapter.uploadFile(taskRecord: taskRecord, itemIdentifier: itemIdentifier)
		adapter.uploadFile(taskRecord: taskRecord, itemIdentifier: itemIdentifier)

		await fulfillment(of: [uploadsStarted[0]], timeout: 5.0)
		await assertStaysBlocked({ await adapter.awaitWorkflows() }, for: 0.5)
		uploadCompletions[0].fulfill(())
		await fulfillment(of: [uploadsStarted[1]], timeout: 5.0)
		await assertStaysBlocked({ await adapter.awaitWorkflows() }, for: 0.5)
		uploadCompletions[1].fulfill(())
		await adapter.awaitWorkflows()
		XCTAssertEqual(2, uploadCount.withLock { $0 })
	}

	func testWorkflowFailingImmediatelyLeavesNoEntryBehind() async throws {
		let adapter = createFullyMockedAdapter()

		try await adapter.deleteItem(withIdentifier: itemIdentifier)
		XCTAssertNotNil(deletionTaskManagerMock.deletionTasks[itemID])

		await assertFinishes({ await adapter.awaitWorkflows() })
	}

	func testStartProvidingItemFailingBeforeRegistrationLeavesNoEntryBehind() async {
		let adapter = createFullyMockedAdapter()
		let url = tmpDirectory.appendingPathComponent("4/File.txt")

		await assertFinishes({
			await self.XCTAssertThrowsAsyncError(try await adapter.startProvidingItem(at: url)) { error in
				XCTAssertEqual(NSFileProviderError(.noSuchItem), error as? NSFileProviderError)
			}
		})
		await assertFinishes({ await adapter.awaitWorkflows() })
	}
}
