//
//  FileProviderEnumeratorTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 24.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import FileProvider
import Promises
import XCTest
@testable import CryptomatorFileProvider

class FileProviderEnumeratorTests: XCTestCase {
	var enumerationObserverMock: NSFileProviderEnumerationObserverMock!
	var changeObserverMock: NSFileProviderChangeObserverMock!
	var notificatorMock: FileProviderNotificatorTypeMock!
	var adapterProvidingMock: FileProviderAdapterProvidingMock!
	var adapterMock: FileProviderAdapterTypeMock!
	var localURLProviderMock: LocalURLProviderMock!
	let domain = NSFileProviderDomain(vaultUID: "VaultUID-12345", displayName: "Test Vault")
	let dbPath = FileManager.default.temporaryDirectory
	let items: [FileProviderItem] = [
		.init(metadata: ItemMetadata(id: 2, name: "Test.txt", type: .file, size: 100, parentID: 1, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/Test.txt"), isPlaceholderItem: false)),
		.init(metadata: ItemMetadata(id: 3, name: "TestFolder", type: .folder, size: nil, parentID: 1, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/TestFolder"), isPlaceholderItem: false))
	]
	let deleteItemIdentifiers = [1, 2, 3].map { NSFileProviderItemIdentifier("\($0)") }
	let currentSyncAnchorDate = Date.distantFuture

	override func setUpWithError() throws {
		enumerationObserverMock = NSFileProviderEnumerationObserverMock()
		changeObserverMock = NSFileProviderChangeObserverMock()
		notificatorMock = FileProviderNotificatorTypeMock()
		adapterProvidingMock = FileProviderAdapterProvidingMock()
		adapterMock = FileProviderAdapterTypeMock()
		adapterProvidingMock.unlockMonitor = UnlockMonitor()
		localURLProviderMock = LocalURLProviderMock()
	}

	// MARK: Enumerate Items

	func testEnumerateItemsFromScratch() {
		let expectation = XCTestExpectation()
		let enumerator = createEnumerator(for: .rootContainer)
		let page = NSFileProviderPage(NSFileProviderPage.initialPageSortedByName as Data)
		let itemList = FileProviderItemList(items: items, nextPageToken: nil)
		adapterProvidingMock.getAdapterForDomainDbPathDelegateNotificatorReturnValue = adapterMock
		adapterMock.enumerateItemsForWithPageTokenReturnValue = Promise(itemList)
		enumerationObserverMock.finishEnumeratingUpToClosure = { _ in
			expectation.fulfill()
		}
		enumerator.enumerateItems(for: enumerationObserverMock, startingAt: page)
		wait(for: [expectation], timeout: 1.0)
		assertWaitForSemaphoreCalled()
		assertEnumerateItemObserverSucceeded(itemList: itemList)
		assertEnumerateItemsCalled(for: .rootContainer, pageToken: nil)
	}

	func testEnumerateItemsFromScratchWithNextPageToken() {
		let expectation = XCTestExpectation()
		let enumerator = createEnumerator(for: .rootContainer)
		let page = NSFileProviderPage(NSFileProviderPage.initialPageSortedByName as Data)
		let nextPageToken = "Foo"
		let nextFileProviderPage = NSFileProviderPage(nextPageToken.data(using: .utf8)!)
		let itemList = FileProviderItemList(items: items, nextPageToken: nextFileProviderPage)
		adapterProvidingMock.getAdapterForDomainDbPathDelegateNotificatorReturnValue = adapterMock
		adapterMock.enumerateItemsForWithPageTokenReturnValue = Promise(itemList)
		enumerationObserverMock.finishEnumeratingUpToClosure = { _ in
			expectation.fulfill()
		}
		enumerator.enumerateItems(for: enumerationObserverMock, startingAt: page)
		wait(for: [expectation], timeout: 1.0)
		assertWaitForSemaphoreCalled()
		assertEnumerateItemObserverSucceeded(itemList: itemList)
		assertEnumerateItemsCalled(for: .rootContainer, pageToken: nil)
	}

	func testEnumerateItemsWithPageToken() {
		let expectation = XCTestExpectation()
		let enumerator = createEnumerator(for: .rootContainer)
		let pageToken = "Foo"
		let page = NSFileProviderPage(pageToken.data(using: .utf8)!)
		let itemList = FileProviderItemList(items: items, nextPageToken: nil)
		adapterProvidingMock.getAdapterForDomainDbPathDelegateNotificatorReturnValue = adapterMock
		adapterMock.enumerateItemsForWithPageTokenReturnValue = Promise(itemList)
		enumerationObserverMock.finishEnumeratingUpToClosure = { _ in
			expectation.fulfill()
		}
		enumerator.enumerateItems(for: enumerationObserverMock, startingAt: page)
		wait(for: [expectation], timeout: 1.0)
		assertWaitForSemaphoreCalled()
		assertEnumerateItemObserverSucceeded(itemList: itemList)
		assertEnumerateItemsCalled(for: .rootContainer, pageToken: pageToken)
	}

	func testEnumerateItemsFailed() {
		let expectation = XCTestExpectation()
		let enumerator = createEnumerator(for: .rootContainer)
		let page = NSFileProviderPage(NSFileProviderPage.initialPageSortedByName as Data)
		adapterProvidingMock.getAdapterForDomainDbPathDelegateNotificatorReturnValue = adapterMock
		adapterMock.enumerateItemsForWithPageTokenReturnValue = Promise(CloudProviderError.noInternetConnection)
		enumerationObserverMock.finishEnumeratingWithErrorClosure = { _ in
			expectation.fulfill()
		}
		enumerator.enumerateItems(for: enumerationObserverMock, startingAt: page)
		wait(for: [expectation], timeout: 1.0)
		assertWaitForSemaphoreCalled()
		assertEnumerateItemsObserverFailed(with: .noInternetConnection)
		assertEnumerateItemsCalled(for: .rootContainer, pageToken: nil)
	}

	func testEnumerateItemsFailedAdapterNotFound() {
		let expectation = XCTestExpectation()
		let enumerator = createEnumerator(for: .rootContainer)
		let page = NSFileProviderPage(NSFileProviderPage.initialPageSortedByName as Data)
		adapterProvidingMock.getAdapterForDomainDbPathDelegateNotificatorThrowableError = UnlockMonitorError.defaultLock
		enumerationObserverMock.finishEnumeratingWithErrorClosure = { _ in
			expectation.fulfill()
		}
		enumerator.enumerateItems(for: enumerationObserverMock, startingAt: page)
		wait(for: [expectation], timeout: 2.0)
		assertWaitForSemaphoreCalled()
		assertErrorWrapped(.defaultLock)
	}

	func testEnumerateItemsFailedAdapterNotFoundForWorkingSet() {
		let expectation = XCTestExpectation()
		let enumerator = createEnumerator(for: .workingSet)
		let page = NSFileProviderPage(NSFileProviderPage.initialPageSortedByName as Data)
		adapterProvidingMock.getAdapterForDomainDbPathDelegateNotificatorThrowableError = UnlockMonitorError.defaultLock
		enumerationObserverMock.finishEnumeratingWithErrorClosure = { _ in
			expectation.fulfill()
		}
		enumerator.enumerateItems(for: enumerationObserverMock, startingAt: page)
		wait(for: [expectation], timeout: 2.0)
		assertWaitForSemaphoreCalled()
		assertWorkingSetInvalidated()
	}

	// MARK: Enumerate Changes

	func testEnumerateChanges() throws {
		let expectation = XCTestExpectation()
		let enumerator = createEnumerator(for: .rootContainer)
		notificatorMock.popUpdateContainerItemsReturnValue = items
		let syncAnchor = try createSyncAnchor(from: .distantPast)
		notificatorMock.currentSyncAnchor = try JSONEncoder().encode(currentSyncAnchorDate)
		changeObserverMock.finishEnumeratingChangesUpToMoreComingClosure = { _, _ in
			expectation.fulfill()
		}
		enumerator.enumerateChanges(for: changeObserverMock, from: syncAnchor)
		wait(for: [expectation], timeout: 1.0)
		assertChangeObserverUpdated(deletedItems: [],
		                            updatedItems: items,
		                            currentSyncAnchor: try createSyncAnchor(from: currentSyncAnchorDate))
	}

	func testEnumerateWorkingSet() throws {
		let expectation = XCTestExpectation()
		let enumerator = createEnumerator(for: .workingSet)
		let lastUnlockedDate = Date()
		adapterMock.lastUnlockedDate = lastUnlockedDate
		adapterProvidingMock.getAdapterForDomainDbPathDelegateNotificatorReturnValue = adapterMock

		notificatorMock.getItemIdentifiersToDeleteFromWorkingSetReturnValue = deleteItemIdentifiers
		notificatorMock.popUpdateWorkingSetItemsReturnValue = items
		changeObserverMock.finishEnumeratingChangesUpToMoreComingClosure = { _, _ in
			expectation.fulfill()
		}
		let syncAnchor = try createSyncAnchor(from: lastUnlockedDate)
		notificatorMock.currentSyncAnchor = try JSONEncoder().encode(currentSyncAnchorDate)
		enumerator.enumerateChanges(for: changeObserverMock, from: syncAnchor)
		wait(for: [expectation], timeout: 1.0)
		assertChangeObserverUpdated(deletedItems: deleteItemIdentifiers,
		                            updatedItems: items,
		                            currentSyncAnchor: try createSyncAnchor(from: currentSyncAnchorDate))
	}

	func testEnumerateWorkingSetLastUnlockedDateDistantPast() throws {
		let expectation = XCTestExpectation()
		let enumerator = createEnumerator(for: .workingSet)
		let lastUnlockedDate = Date.distantPast
		adapterMock.lastUnlockedDate = lastUnlockedDate
		adapterProvidingMock.getAdapterForDomainDbPathDelegateNotificatorReturnValue = adapterMock

		notificatorMock.getItemIdentifiersToDeleteFromWorkingSetReturnValue = deleteItemIdentifiers
		notificatorMock.popUpdateWorkingSetItemsReturnValue = items
		changeObserverMock.finishEnumeratingChangesUpToMoreComingClosure = { _, _ in
			expectation.fulfill()
		}
		let syncAnchor = try createSyncAnchor(from: Date())

		notificatorMock.currentSyncAnchor = try JSONEncoder().encode(currentSyncAnchorDate)
		enumerator.enumerateChanges(for: changeObserverMock, from: syncAnchor)
		wait(for: [expectation], timeout: 1.0)
		assertChangeObserverUpdated(deletedItems: deleteItemIdentifiers,
		                            updatedItems: items,
		                            currentSyncAnchor: try createSyncAnchor(from: currentSyncAnchorDate))
	}

	func testEnumerateWorkingSetChangesFailedAdapterNotFound() throws {
		let expectation = XCTestExpectation()
		let enumerator = createEnumerator(for: .workingSet)
		adapterProvidingMock.getAdapterForDomainDbPathDelegateNotificatorThrowableError = UnlockMonitorError.defaultLock
		changeObserverMock.finishEnumeratingWithErrorClosure = { _ in
			expectation.fulfill()
		}
		let syncAnchor = try createSyncAnchor(from: .distantPast)
		notificatorMock.currentSyncAnchor = try JSONEncoder().encode(currentSyncAnchorDate)
		enumerator.enumerateChanges(for: changeObserverMock, from: syncAnchor)
		wait(for: [expectation], timeout: 1.0)
		assertWorkingSetInvalidatedForEnumerateChanges()
	}

	func testEnumerateWorkingSetUnlockedAfterLastUpdate() throws {
		let expectation = XCTestExpectation()
		let enumerator = createEnumerator(for: .workingSet)
		adapterMock.lastUnlockedDate = Date()
		adapterProvidingMock.getAdapterForDomainDbPathDelegateNotificatorReturnValue = adapterMock
		changeObserverMock.finishEnumeratingWithErrorClosure = { _ in
			expectation.fulfill()
		}
		let syncAnchor = try createSyncAnchor(from: Date.distantPast)
		notificatorMock.currentSyncAnchor = try JSONEncoder().encode(currentSyncAnchorDate)
		enumerator.enumerateChanges(for: changeObserverMock, from: syncAnchor)
		wait(for: [expectation], timeout: 1.0)
		assertWorkingSetInvalidatedForEnumerateChanges()
	}

	private func createEnumerator(for itemIdentifier: NSFileProviderItemIdentifier) -> FileProviderEnumerator {
		return FileProviderEnumerator(enumeratedItemIdentifier: itemIdentifier, notificator: notificatorMock, domain: domain, dbPath: dbPath, localURLProvider: localURLProviderMock, adapterProvider: adapterProvidingMock)
	}

	private func assertWaitForSemaphoreCalled() {
		XCTAssertEqual(1, adapterProvidingMock.unlockMonitorGetterCallsCount)
	}

	private func assertEnumerateItemsCalled(for identifier: NSFileProviderItemIdentifier, pageToken: String?) {
		XCTAssertEqual(1, adapterMock.enumerateItemsForWithPageTokenCallsCount)
		XCTAssertEqual(identifier, adapterMock.enumerateItemsForWithPageTokenReceivedArguments?.identifier)
		XCTAssertEqual(pageToken, adapterMock.enumerateItemsForWithPageTokenReceivedArguments?.pageToken)
	}

	private func assertEnumerateItemsNotCalled() {
		XCTAssertFalse(adapterMock.enumerateItemsForWithPageTokenCalled)
	}

	private func assertEnumerateItemObserverSucceeded(itemList: FileProviderItemList) {
		XCTAssertEqual([itemList.nextPageToken], enumerationObserverMock.finishEnumeratingUpToReceivedInvocations)
		let receivedInvocations = enumerationObserverMock.didEnumerateReceivedInvocations as? [[FileProviderItem]]
		XCTAssertEqual([items], receivedInvocations)
		XCTAssertFalse(enumerationObserverMock.finishEnumeratingWithErrorCalled)
	}

	private func assertEnumerateItemsObserverFailed(with error: CloudProviderError) {
		let receivedErrors = enumerationObserverMock.finishEnumeratingWithErrorReceivedInvocations as? [CloudProviderError]
		XCTAssertEqual([error], receivedErrors)
		XCTAssertFalse(enumerationObserverMock.finishEnumeratingUpToCalled)
		XCTAssertFalse(enumerationObserverMock.didEnumerateCalled)
	}

	private func assertErrorWrapped(_ error: UnlockMonitorError) {
		let receivedErrors = enumerationObserverMock.finishEnumeratingWithErrorReceivedInvocations as? [NSFileProviderError]
		let expectedWrappedError = ErrorWrapper.wrapError(error, domain: domain)
		XCTAssertEqual([expectedWrappedError], receivedErrors)
		XCTAssertFalse(enumerationObserverMock.finishEnumeratingUpToCalled)
		XCTAssertFalse(enumerationObserverMock.didEnumerateCalled)
	}

	private func assertWorkingSetInvalidated() {
		let receivedErrors = enumerationObserverMock.finishEnumeratingWithErrorReceivedInvocations as? [NSFileProviderError]
		XCTAssertEqual(1, notificatorMock.invalidatedWorkingSetCallsCount)
		XCTAssertEqual([NSFileProviderError(.syncAnchorExpired)], receivedErrors)
		XCTAssertFalse(enumerationObserverMock.finishEnumeratingUpToCalled)
		XCTAssertFalse(enumerationObserverMock.didEnumerateCalled)
	}

	private func createSyncAnchor(from date: Date) throws -> NSFileProviderSyncAnchor {
		return NSFileProviderSyncAnchor(try JSONEncoder().encode(date))
	}

	private func assertChangeObserverUpdated(deletedItems: [NSFileProviderItemIdentifier], updatedItems: [FileProviderItem], currentSyncAnchor: NSFileProviderSyncAnchor) {
		XCTAssertEqual([deletedItems], changeObserverMock.didDeleteItemsWithIdentifiersReceivedInvocations)
		let receivedUpdatedItems = changeObserverMock.didUpdateReceivedInvocations as? [[FileProviderItem]]
		XCTAssertEqual([updatedItems], receivedUpdatedItems)
		XCTAssertFalse(changeObserverMock.finishEnumeratingWithErrorCalled)
	}

	private func assertWorkingSetInvalidatedForEnumerateChanges() {
		let receivedErrors = changeObserverMock.finishEnumeratingWithErrorReceivedInvocations as? [NSFileProviderError]
		XCTAssertEqual(1, notificatorMock.invalidatedWorkingSetCallsCount)
		XCTAssertEqual([NSFileProviderError(.syncAnchorExpired)], receivedErrors)
		XCTAssertFalse(changeObserverMock.finishEnumeratingChangesUpToMoreComingCalled)
		XCTAssertFalse(changeObserverMock.didUpdateCalled)
	}
}
