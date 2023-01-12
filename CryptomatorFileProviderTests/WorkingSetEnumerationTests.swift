//
//  WorkingSetEnumerationTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 14.04.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import Foundation
import XCTest

@testable import CryptomatorFileProvider

class WorkingSetEnumerationTests: FileProviderEnumeratorTestCase {
	var lastKnownSyncAnchor: NSFileProviderSyncAnchor!
	var enumerator: FileProviderEnumerator!
	let defaultStartPage = NSFileProviderPage(NSFileProviderPage.initialPageSortedByDate as Data)

	override func setUpWithError() throws {
		try super.setUpWithError()
		lastKnownSyncAnchor = try createSyncAnchor(from: .distantPast, locked: false)
		enumerator = FileProviderEnumerator(enumeratedItemIdentifier: .workingSet, notificator: FileProviderNotificator(manager: EnumerationSignalingMock()), domain: domain, dbPath: dbPath, localURLProvider: localURLProviderMock, adapterProvider: adapterProvidingMock, taskRegistrator: taskRegistratorMock)

		setupEnumerateItemsObserver()
		setupEnumerateChangesObserver()
	}

	func testEnumerateChangesWithLockedVault() throws {
		let expectation = XCTestExpectation(description: "Invalidated working set eventually finishes without changing the set when calling enumerateChanges(for:from)")
		setupChangeObserverMockFinishEnumeratingChanges(with: expectation)
		simulateLockedVault()
		enumerator.enumerateChanges(for: changeObserverMock, from: lastKnownSyncAnchor)
		wait(for: [expectation], timeout: 1.0)
		XCTAssert(enumerationObserverMock.didEnumerateReceivedUpdatedItems?.isEmpty ?? false)
		assertWorkingSetInvalidated()
		XCTAssertEqual(1, enumerationObserverMock.didEnumerateCallsCount)
	}

	func testEnumerateItemWithLockedVault() throws {
		let expectation = XCTestExpectation(description: "Locked vault returns empty working set when calling enumerateItems(for:startingAt)")
		setupChangeObserverMockFinishEnumeratingChanges(with: expectation)
		simulateLockedVault()
		enumerator.enumerateItems(for: enumerationObserverMock, startingAt: defaultStartPage)
		wait(for: [expectation], timeout: 1.0)
		XCTAssert(enumerationObserverMock.didEnumerateReceivedUpdatedItems?.isEmpty ?? false)
		assertWorkingSetInvalidated()
		XCTAssertEqual(2, enumerationObserverMock.didEnumerateCallsCount)
	}

	func testEnumerateWorkingSet() throws {
		let expectation = XCTestExpectation()
		let enumerator = createFullyMockedEnumerator(for: .workingSet)
		let lastUnlockedDate = Date()
		adapterMock.lastUnlockedDate = lastUnlockedDate
		adapterProvidingMock.getAdapterForDomainDbPathDelegateNotificatorTaskRegistratorReturnValue = adapterMock

		notificatorMock.getItemIdentifiersToDeleteFromWorkingSetReturnValue = deleteItemIdentifiers
		notificatorMock.popUpdateWorkingSetItemsReturnValue = items
		setupChangeObserverMockFinishEnumeratingChanges(with: expectation)
		let syncAnchor = try createSyncAnchor(from: lastUnlockedDate)

		let updatedSyncAnchor = try createSyncAnchor(from: .distantFuture)
		notificatorMock.currentSyncAnchor = updatedSyncAnchor.rawValue
		enumerator.enumerateChanges(for: changeObserverMock, from: syncAnchor)
		wait(for: [expectation], timeout: 1.0)
		assertChangeObserverUpdated(deletedItems: deleteItemIdentifiers,
		                            updatedItems: items,
		                            currentSyncAnchor: updatedSyncAnchor)
	}

	func testEnumerateWorkingSetLastUnlockedDateDistantPast() throws {
		let expectation = XCTestExpectation()
		let enumerator = createFullyMockedEnumerator(for: .workingSet)
		let lastUnlockedDate = Date.distantPast
		adapterMock.lastUnlockedDate = lastUnlockedDate
		adapterProvidingMock.getAdapterForDomainDbPathDelegateNotificatorTaskRegistratorReturnValue = adapterMock

		notificatorMock.getItemIdentifiersToDeleteFromWorkingSetReturnValue = deleteItemIdentifiers
		notificatorMock.popUpdateWorkingSetItemsReturnValue = items
		setupChangeObserverMockFinishEnumeratingChanges(with: expectation)
		let syncAnchor = try createSyncAnchor(from: Date())

		let updatedSyncAnchor = try createSyncAnchor(from: .distantFuture)
		notificatorMock.currentSyncAnchor = updatedSyncAnchor.rawValue
		enumerator.enumerateChanges(for: changeObserverMock, from: syncAnchor)
		wait(for: [expectation], timeout: 1.0)
		assertChangeObserverUpdated(deletedItems: deleteItemIdentifiers,
		                            updatedItems: items,
		                            currentSyncAnchor: updatedSyncAnchor)
	}

	func testEnumerateWorkingSetUnlockedAfterLastUpdate() throws {
		let expectation = XCTestExpectation()
		let enumerator = createFullyMockedEnumerator(for: .workingSet)
		adapterMock.lastUnlockedDate = Date()
		adapterProvidingMock.getAdapterForDomainDbPathDelegateNotificatorTaskRegistratorReturnValue = adapterMock
		changeObserverMock.finishEnumeratingWithErrorClosure = { error in
			XCTAssertEqual(NSFileProviderError(.syncAnchorExpired), error as? NSFileProviderError)
			expectation.fulfill()
		}
		let syncAnchor = try createSyncAnchor(from: Date.distantPast)
		let updatedSyncAnchor = try createSyncAnchor(from: .distantFuture)
		notificatorMock.currentSyncAnchor = updatedSyncAnchor.rawValue
		enumerator.enumerateChanges(for: changeObserverMock, from: syncAnchor)
		wait(for: [expectation], timeout: 1.0)
		assertWorkingSetInvalidatedForEnumerateChanges()
	}

	private func setupChangeObserverMockFinishEnumeratingChanges(with expectation: XCTestExpectation) {
		changeObserverMock.finishEnumeratingChangesUpToMoreComingClosure = { _, moreComing in
			if !moreComing {
				expectation.fulfill()
			}
		}
	}

	private func simulateLockedVault() {
		adapterProvidingMock.getAdapterForDomainDbPathDelegateNotificatorTaskRegistratorThrowableError = UnlockMonitorError.defaultLock
	}

	private func assertWorkingSetDidNotChange() {
		XCTAssertFalse(changeObserverMock.didUpdateCalled)
		XCTAssertFalse(changeObserverMock.didDeleteItemsWithIdentifiersCalled)
	}

	private func assertWorkingSetInvalidated() {
		let receivedErrors = changeObserverMock.finishEnumeratingWithErrorReceivedInvocations as? [NSFileProviderError]
		XCTAssert(enumerationObserverMock.didEnumerateReceivedUpdatedItems?.isEmpty ?? false)
		XCTAssertFalse(enumerationObserverMock.finishEnumeratingWithErrorCalled)
		XCTAssertEqual([NSFileProviderError(.syncAnchorExpired)], receivedErrors)
		XCTAssertFalse(changeObserverMock.didUpdateCalled)
		XCTAssertFalse(changeObserverMock.didDeleteItemsWithIdentifiersCalled)
	}

	private func assertWorkingSetInvalidatedForEnumerateChanges() {
		let receivedErrors = changeObserverMock.finishEnumeratingWithErrorReceivedInvocations as? [NSFileProviderError]
		XCTAssertEqual([NSFileProviderError(.syncAnchorExpired)], receivedErrors)
	}

	/// Mimics the behavior of the Files app by calling `enumerateChanges(for:from:)` with the currently known sync anchor after a successful enumeration.
	private func setupEnumerateItemsObserver() {
		enumerationObserverMock.finishEnumeratingUpToClosure = { page in
			if let page = page {
				self.enumerator.enumerateItems(for: self.enumerationObserverMock, startingAt: page)
			} else {
				self.enumerator.enumerateChanges(for: self.changeObserverMock, from: self.lastKnownSyncAnchor)
			}
		}
	}

	/// Mimics the behavior of the Files app by triggering a new enumeration after a `.syncAnchorExpired` error. This means that first the current sync anchor is queried and then `enumerateItems(for:startingAt:)` is called on the enumerator.
	private func setupEnumerateChangesObserver() {
		changeObserverMock.finishEnumeratingWithErrorClosure = { error in
			XCTAssertEqual(NSFileProviderError(.syncAnchorExpired), error as? NSFileProviderError)
			let updatedSyncAnchorExpectation = XCTestExpectation()
			self.enumerator.currentSyncAnchor(completionHandler: { newSyncAnchor in
				if let newSyncAnchor = newSyncAnchor {
					self.lastKnownSyncAnchor = newSyncAnchor
				}
				updatedSyncAnchorExpectation.fulfill()
			})
			self.wait(for: [updatedSyncAnchorExpectation], timeout: 1.0)
			self.enumerator.enumerateItems(for: self.enumerationObserverMock, startingAt: NSFileProviderPage(NSFileProviderPage.initialPageSortedByDate as Data))
		}
	}
}
