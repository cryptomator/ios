//
//  FileProviderEnumeratorTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 24.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCloudAccessCore
import FileProvider
import Promises
import XCTest
@testable import CryptomatorCommonCore
@testable import CryptomatorFileProvider
@testable import Dependencies

class FileProviderEnumeratorTestCase: XCTestCase {
	var enumerationObserverMock: NSFileProviderEnumerationObserverMock!
	var changeObserverMock: NSFileProviderChangeObserverMock!
	var notificatorMock: FileProviderNotificatorTypeMock!
	var adapterProvidingMock: FileProviderAdapterProvidingMock!
	var adapterMock: FileProviderAdapterTypeMock!
	var localURLProviderMock: LocalURLProviderMock!
	var taskRegistratorMock: SessionTaskRegistratorMock!
	let dbPath = FileManager.default.temporaryDirectory
	let domain = NSFileProviderDomain(vaultUID: "VaultUID-12345", displayName: "Test Vault")
	let items: [FileProviderItem] = [
		.init(metadata: ItemMetadata(id: 2, name: "Test.txt", type: .file, size: 100, parentID: 1, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/Test.txt"), isPlaceholderItem: false), domainIdentifier: .test),
		.init(metadata: ItemMetadata(id: 3, name: "TestFolder", type: .folder, size: nil, parentID: 1, lastModifiedDate: nil, statusCode: .isUploaded, cloudPath: CloudPath("/TestFolder"), isPlaceholderItem: false), domainIdentifier: .test)
	]
	let deleteItemIdentifiers = [1, 2, 3].map { NSFileProviderItemIdentifier("\($0)") }

	override func setUpWithError() throws {
		enumerationObserverMock = NSFileProviderEnumerationObserverMock()
		changeObserverMock = NSFileProviderChangeObserverMock()
		notificatorMock = FileProviderNotificatorTypeMock()
		adapterProvidingMock = FileProviderAdapterProvidingMock()
		adapterMock = FileProviderAdapterTypeMock()
		adapterProvidingMock.unlockMonitor = UnlockMonitor()
		localURLProviderMock = LocalURLProviderMock()
		taskRegistratorMock = SessionTaskRegistratorMock()
	}

	func createSyncAnchor(from date: Date, locked: Bool = false) throws -> NSFileProviderSyncAnchor {
		return try NSFileProviderSyncAnchor(JSONEncoder().encode(SyncAnchor(invalidated: locked, date: date)))
	}

	func createFullyMockedEnumerator(for itemIdentifier: NSFileProviderItemIdentifier) -> FileProviderEnumerator {
		return FileProviderEnumerator(enumeratedItemIdentifier: itemIdentifier, notificator: notificatorMock, domain: domain, dbPath: dbPath, localURLProvider: localURLProviderMock, adapterProvider: adapterProvidingMock, taskRegistrator: taskRegistratorMock)
	}

	func assertChangeObserverUpdated(deletedItems: [NSFileProviderItemIdentifier], updatedItems: [FileProviderItem], currentSyncAnchor: NSFileProviderSyncAnchor) {
		let permissionProviderMock = PermissionProviderMock()
		DependencyValues.mockDependency(\.permissionProvider, with: permissionProviderMock)
		permissionProviderMock.getPermissionsForAtReturnValue = .allowsReading

		XCTAssertEqual([deletedItems], changeObserverMock.didDeleteItemsWithIdentifiersReceivedInvocations)
		let receivedUpdatedItems = changeObserverMock.didUpdateReceivedInvocations as? [[FileProviderItem]]
		XCTAssertEqual([updatedItems], receivedUpdatedItems)
		XCTAssertFalse(changeObserverMock.finishEnumeratingWithErrorCalled)
	}
}

class FileProviderEnumeratorTests: FileProviderEnumeratorTestCase {
	let currentSyncAnchorDate = Date.distantFuture

	// MARK: Enumerate Items

	func testEnumerateItemsFromScratch() {
		let expectation = XCTestExpectation()
		let enumerator = createFullyMockedEnumerator(for: .rootContainer)
		let page = NSFileProviderPage(NSFileProviderPage.initialPageSortedByName as Data)
		let itemList = FileProviderItemList(items: items, nextPageToken: nil)
		adapterProvidingMock.getAdapterForDomainDbPathDelegateNotificatorTaskRegistratorReturnValue = adapterMock
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
		let enumerator = createFullyMockedEnumerator(for: .rootContainer)
		let page = NSFileProviderPage(NSFileProviderPage.initialPageSortedByName as Data)
		let nextPageToken = "Foo"
		let nextFileProviderPage = NSFileProviderPage(nextPageToken.data(using: .utf8)!)
		let itemList = FileProviderItemList(items: items, nextPageToken: nextFileProviderPage)
		adapterProvidingMock.getAdapterForDomainDbPathDelegateNotificatorTaskRegistratorReturnValue = adapterMock
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
		let enumerator = createFullyMockedEnumerator(for: .rootContainer)
		let pageToken = "Foo"
		let page = NSFileProviderPage(pageToken.data(using: .utf8)!)
		let itemList = FileProviderItemList(items: items, nextPageToken: nil)
		adapterProvidingMock.getAdapterForDomainDbPathDelegateNotificatorTaskRegistratorReturnValue = adapterMock
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
		let enumerator = createFullyMockedEnumerator(for: .rootContainer)
		let page = NSFileProviderPage(NSFileProviderPage.initialPageSortedByName as Data)
		adapterProvidingMock.getAdapterForDomainDbPathDelegateNotificatorTaskRegistratorReturnValue = adapterMock
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
		let enumerator = createFullyMockedEnumerator(for: .rootContainer)
		let page = NSFileProviderPage(NSFileProviderPage.initialPageSortedByName as Data)
		adapterProvidingMock.getAdapterForDomainDbPathDelegateNotificatorTaskRegistratorThrowableError = UnlockMonitorError.defaultLock
		enumerationObserverMock.finishEnumeratingWithErrorClosure = { _ in
			expectation.fulfill()
		}
		enumerator.enumerateItems(for: enumerationObserverMock, startingAt: page)
		wait(for: [expectation], timeout: 2.0)
		assertWaitForSemaphoreCalled()
		assertErrorWrapped(.defaultLock)
	}

	// MARK: Enumerate Changes

	func testEnumerateChanges() throws {
		let expectation = XCTestExpectation()
		let enumerator = createFullyMockedEnumerator(for: .rootContainer)
		notificatorMock.popUpdateContainerItemsReturnValue = items
		let syncAnchor = try createSyncAnchor(from: .distantPast)
		notificatorMock.currentSyncAnchor = try JSONEncoder().encode(currentSyncAnchorDate)
		changeObserverMock.finishEnumeratingChangesUpToMoreComingClosure = { _, _ in
			expectation.fulfill()
		}
		enumerator.enumerateChanges(for: changeObserverMock, from: syncAnchor)
		wait(for: [expectation], timeout: 1.0)
		try assertChangeObserverUpdated(deletedItems: [],
		                                updatedItems: items,
		                                currentSyncAnchor: createSyncAnchor(from: currentSyncAnchorDate))
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
		let permissionProviderMock = PermissionProviderMock()
		DependencyValues.mockDependency(\.permissionProvider, with: permissionProviderMock)
		permissionProviderMock.getPermissionsForAtReturnValue = .allowsReading

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
}
