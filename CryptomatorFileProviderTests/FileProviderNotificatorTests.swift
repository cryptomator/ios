//
//  FileProviderNotificatorTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 25.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import XCTest
@testable import CryptomatorFileProvider
@testable import Dependencies

@available(iOS 14.0, *)
class FileProviderNotificatorTests: XCTestCase {
	var notificator: FileProviderNotificator!
	var enumerationSignalingMock: EnumerationSignalingMock!
	let deleteItemIdentifiers = [1, 2, 3].map { NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: $0) }
	let updatedMetadataIDs: [Int64] = [2, 3, 4]
	lazy var updatedItemIdentifiers = updatedMetadataIDs.map { NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: $0) }
	lazy var updatedItems: [FileProviderItem] = updatedMetadataIDs.map {
		FileProviderItem(metadata: ItemMetadata(id: $0, name: "\($0)", type: .file, size: nil, parentID: 0, lastModifiedDate: nil, statusCode: .isDownloading, cloudPath: CloudPath("/\($0)"), isPlaceholderItem: false), domainIdentifier: .test)
	}

	override func setUpWithError() throws {
		enumerationSignalingMock = EnumerationSignalingMock()
		notificator = FileProviderNotificator(manager: enumerationSignalingMock)
	}

	// MARK: Working Set

	func testGetItemIdentifiersToDeleteFromWorkingSet() throws {
		notificator.removeItemsFromWorkingSet(with: deleteItemIdentifiers)
		XCTAssertEqual(deleteItemIdentifiers, getSortedItemIdentifiersToDeleteFromWorkingSet())
		// Check getter does not clear the identifiers
		XCTAssertEqual(deleteItemIdentifiers, getSortedItemIdentifiersToDeleteFromWorkingSet())
		XCTAssertFalse(enumerationSignalingMock.signalEnumeratorForCompletionHandlerCalled)
	}

	func testPopUpdateWorkingSetItems() throws {
		notificator.updateWorkingSetItems(updatedItems)
		assertUpdateWorkingSetHasUpdatedItems()
		// Check actually removed items
		XCTAssert(notificator.popUpdateWorkingSetItems().isEmpty)
		XCTAssertFalse(enumerationSignalingMock.signalEnumeratorForCompletionHandlerCalled)
	}

	func testUpdateWorkingSetItemRemovesFromDeleteSet() {
		notificator.removeItemsFromWorkingSet(with: deleteItemIdentifiers)
		notificator.updateWorkingSetItems(updatedItems)

		XCTAssertEqual([NSFileProviderItemIdentifier(domainIdentifier: .test, itemID: 1)], getSortedItemIdentifiersToDeleteFromWorkingSet())
		assertUpdateWorkingSetHasUpdatedItems()
		XCTAssertFalse(enumerationSignalingMock.signalEnumeratorForCompletionHandlerCalled)
	}

	func testInvalidatedWorkingSet() throws {
		let initialSyncAnchor = notificator.currentAnchor
		XCTAssertFalse(initialSyncAnchor.invalidated)
		notificator.updateWorkingSetItems(updatedItems)
		notificator.removeItemsFromWorkingSet(with: deleteItemIdentifiers)
		notificator.invalidatedWorkingSet()
		XCTAssert(notificator.getItemIdentifiersToDeleteFromWorkingSet().isEmpty)
		XCTAssert(notificator.popUpdateWorkingSetItems().isEmpty)
		XCTAssertFalse(enumerationSignalingMock.signalEnumeratorForCompletionHandlerCalled)
		let updatedSyncAnchor = notificator.currentAnchor
		XCTAssert(initialSyncAnchor.date < updatedSyncAnchor.date)
		XCTAssert(updatedSyncAnchor.invalidated)
	}

	func testRefreshWorkingSet() throws {
		let expectation = XCTestExpectation()
		let currentSyncAnchor = try getCurrentSyncAnchorDate()
		enumerationSignalingMock.signalEnumeratorForCompletionHandlerClosure = { _, _ in
			expectation.fulfill()
		}
		notificator.refreshWorkingSet()
		wait(for: [expectation], timeout: 1.0)
		XCTAssertEqual(1, enumerationSignalingMock.signalEnumeratorForCompletionHandlerCallsCount)
		XCTAssertEqual(.workingSet, enumerationSignalingMock.signalEnumeratorForCompletionHandlerReceivedArguments?.containerItemIdentifier)
		try assertSyncAnchorHasBeenUpdated(oldSyncAnchor: currentSyncAnchor)
	}

	// MARK: Normal Container

	func testSignalUpdate() throws {
		let expectation = XCTestExpectation()
		let currentSyncAnchor = try getCurrentSyncAnchorDate()
		enumerationSignalingMock.signalEnumeratorForCompletionHandlerClosure = { _, _ in
			expectation.fulfill()
		}
		let updatedItem = updatedItems[0]
		notificator.signalUpdate(for: updatedItem)
		wait(for: [expectation], timeout: 1.0)
		XCTAssertEqual(2, enumerationSignalingMock.signalEnumeratorForCompletionHandlerCallsCount)
		XCTAssertEqual([updatedItem.parentItemIdentifier, updatedItem.itemIdentifier], enumerationSignalingMock.signalEnumeratorForCompletionHandlerReceivedInvocations.map {
			$0.containerItemIdentifier
		})

		let actualItems = notificator.popUpdateContainerItems() as? [FileProviderItem]

		let permissionProviderMock = PermissionProviderMock()
		DependencyValues.mockDependency(\.permissionProvider, with: permissionProviderMock)
		permissionProviderMock.getPermissionsForAtReturnValue = .allowsReading

		XCTAssertEqual([updatedItem], actualItems?.sorted())
		XCTAssert(notificator.popUpdateWorkingSetItems().isEmpty)
		XCTAssert(notificator.getItemIdentifiersToDeleteFromWorkingSet().isEmpty)

		try assertSyncAnchorHasBeenUpdated(oldSyncAnchor: currentSyncAnchor)
	}

	private func getSortedItemIdentifiersToDeleteFromWorkingSet() -> [NSFileProviderItemIdentifier] {
		return notificator.getItemIdentifiersToDeleteFromWorkingSet().sorted()
	}

	private func assertUpdateWorkingSetHasUpdatedItems() {
		let permissionProviderMock = PermissionProviderMock()
		DependencyValues.mockDependency(\.permissionProvider, with: permissionProviderMock)
		permissionProviderMock.getPermissionsForAtReturnValue = .allowsReading
		let actualItems = notificator.popUpdateWorkingSetItems() as? [FileProviderItem]
		XCTAssertEqual(updatedItems.sorted(), actualItems?.sorted())
	}

	private func getCurrentSyncAnchorDate() throws -> Date {
		let syncAnchor = try JSONDecoder().decode(SyncAnchor.self, from: notificator.currentSyncAnchor)
		return syncAnchor.date
	}

	private func assertSyncAnchorHasBeenUpdated(oldSyncAnchor: Date) throws {
		let newSyncAnchor = try getCurrentSyncAnchorDate()
		XCTAssert(oldSyncAnchor < newSyncAnchor)
	}
}

extension FileProviderItem: Comparable {
	public static func < (lhs: FileProviderItem, rhs: FileProviderItem) -> Bool {
		return lhs.itemIdentifier < rhs.itemIdentifier
	}
}

extension NSFileProviderItemIdentifier: Comparable {
	public static func < (lhs: NSFileProviderItemIdentifier, rhs: NSFileProviderItemIdentifier) -> Bool {
		return lhs.rawValue < rhs.rawValue
	}
}
