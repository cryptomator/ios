//
//  WorkingSetObserverTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 25.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Dependencies
import GRDB
import XCTest
@testable import CryptomatorFileProvider

class WorkingSetObserverTests: XCTestCase {
	var observer: WorkingSetObserver!
	var notificatorMock: FileProviderNotificatorTypeMock!
	var database: DatabaseQueue!
	var uploadTaskManagerMock: UploadTaskManagerMock!
	let updatedMetadataIDs: [Int64] = [1, 2, 3]
	lazy var updatedItems: [FileProviderItem] = updatedMetadataIDs.map {
		FileProviderItem(metadata: ItemMetadata(id: $0, name: "\($0)", type: .file, size: nil, parentID: 0, lastModifiedDate: nil, statusCode: .isDownloading, isPlaceholderItem: false), domainIdentifier: .test)
	}

	override func setUpWithError() throws {
		notificatorMock = FileProviderNotificatorTypeMock()
		database = try DatabaseQueue()
		try DatabaseHelper.migrate(database)
		uploadTaskManagerMock = UploadTaskManagerMock()
		observer = WorkingSetObserver(domainIdentifier: .test, database: database, notificator: notificatorMock, uploadTaskManager: uploadTaskManagerMock, cachedFileManager: CloudTaskExecutorTestCase.CachedFileManagerMock())
	}

	func testStartObservationDeliversWorkingSetItemWithAllFields() throws {
		uploadTaskManagerMock.getCorrespondingTaskRecordsIdsClosure = { ids in ids.map { _ in nil } }
		let itemMetadata = ItemMetadata(id: 2, name: "Favorite.txt", type: .file, size: 42, parentID: NSFileProviderItemIdentifier.rootContainerDatabaseValue, lastModifiedDate: Date(timeIntervalSince1970: 100), statusCode: .uploadError, isPlaceholderItem: true, isCandidateForCacheCleanup: true, favoriteRank: 7, tagData: Data("Tag".utf8), lastEnumeratedAt: Date(timeIntervalSince1970: 200))
		let workingSetUpdated = expectation(description: "Working set updated")
		notificatorMock.updateWorkingSetItemsClosure = { _ in
			workingSetUpdated.fulfill()
		}

		observer.startObservation()
		try database.write { db in
			try itemMetadata.insert(db)
		}
		wait(for: [workingSetUpdated], timeout: 5.0)

		let items = try XCTUnwrap(notificatorMock.updateWorkingSetItemsReceivedItems as? [FileProviderItem])
		XCTAssertEqual([itemMetadata], items.map(\.metadata))
	}

	func testHandleNewWorkingSetUpdate() {
		observer.handleWorkingSetUpdate(items: updatedItems)
		XCTAssertFalse(notificatorMock.removeItemsFromWorkingSetWithCalled)
		XCTAssertFalse(notificatorMock.removeItemFromWorkingSetWithCalled)

		XCTAssertEqual(1, notificatorMock.updateWorkingSetItemsCallsCount)
		let actualUpdatedItems = notificatorMock.updateWorkingSetItemsReceivedItems as? [FileProviderItem]
		let permissionProviderMock = PermissionProviderMock()
		withDependencies {
			$0.permissionProvider = permissionProviderMock
		} operation: {
			permissionProviderMock.getPermissionsForAtReturnValue = .allowsReading
			XCTAssertEqual(updatedItems.sorted(), actualUpdatedItems?.sorted())
		}
		XCTAssertEqual(1, notificatorMock.refreshWorkingSetCallsCount)
	}

	func testHandleWorkingSetUpdateRemoveItems() {
		observer.handleWorkingSetUpdate(items: updatedItems)
		observer.handleWorkingSetUpdate(items: [])
		let actualRemovedItems = notificatorMock.removeItemsFromWorkingSetWithReceivedIdentifiers
		XCTAssertEqual(updatedItems.map { $0.itemIdentifier }.sorted(), actualRemovedItems?.sorted())
		XCTAssertEqual(2, notificatorMock.refreshWorkingSetCallsCount)
	}

	func testHandleWorkingSetUpdatePartiallyRemoveItems() {
		observer.handleWorkingSetUpdate(items: updatedItems)
		let removedItem = updatedItems.removeLast()
		observer.handleWorkingSetUpdate(items: updatedItems)
		let actualRemovedItems = notificatorMock.removeItemsFromWorkingSetWithReceivedIdentifiers
		XCTAssertEqual([removedItem.itemIdentifier].sorted(), actualRemovedItems?.sorted())
		XCTAssertEqual(2, notificatorMock.refreshWorkingSetCallsCount)
	}
}
