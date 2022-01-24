//
//  NSFileProviderChangeObserverMock.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 24.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import FileProvider
import Foundation

// swiftlint:disable all
final class NSFileProviderChangeObserverMock: NSObject, NSFileProviderChangeObserver {
	// MARK: - didUpdate

	var didUpdateCallsCount = 0
	var didUpdateCalled: Bool {
		didUpdateCallsCount > 0
	}

	var didUpdateReceivedUpdatedItems: [NSFileProviderItemProtocol]?
	var didUpdateReceivedInvocations: [[NSFileProviderItemProtocol]] = []
	var didUpdateClosure: (([NSFileProviderItemProtocol]) -> Void)?

	func didUpdate(_ updatedItems: [NSFileProviderItemProtocol]) {
		didUpdateCallsCount += 1
		didUpdateReceivedUpdatedItems = updatedItems
		didUpdateReceivedInvocations.append(updatedItems)
		didUpdateClosure?(updatedItems)
	}

	// MARK: - didDeleteItems

	var didDeleteItemsWithIdentifiersCallsCount = 0
	var didDeleteItemsWithIdentifiersCalled: Bool {
		didDeleteItemsWithIdentifiersCallsCount > 0
	}

	var didDeleteItemsWithIdentifiersReceivedDeletedItemIdentifiers: [NSFileProviderItemIdentifier]?
	var didDeleteItemsWithIdentifiersReceivedInvocations: [[NSFileProviderItemIdentifier]] = []
	var didDeleteItemsWithIdentifiersClosure: (([NSFileProviderItemIdentifier]) -> Void)?

	func didDeleteItems(withIdentifiers deletedItemIdentifiers: [NSFileProviderItemIdentifier]) {
		didDeleteItemsWithIdentifiersCallsCount += 1
		didDeleteItemsWithIdentifiersReceivedDeletedItemIdentifiers = deletedItemIdentifiers
		didDeleteItemsWithIdentifiersReceivedInvocations.append(deletedItemIdentifiers)
		didDeleteItemsWithIdentifiersClosure?(deletedItemIdentifiers)
	}

	// MARK: - finishEnumeratingChanges

	var finishEnumeratingChangesUpToMoreComingCallsCount = 0
	var finishEnumeratingChangesUpToMoreComingCalled: Bool {
		finishEnumeratingChangesUpToMoreComingCallsCount > 0
	}

	var finishEnumeratingChangesUpToMoreComingReceivedArguments: (anchor: NSFileProviderSyncAnchor, moreComing: Bool)?
	var finishEnumeratingChangesUpToMoreComingReceivedInvocations: [(anchor: NSFileProviderSyncAnchor, moreComing: Bool)] = []
	var finishEnumeratingChangesUpToMoreComingClosure: ((NSFileProviderSyncAnchor, Bool) -> Void)?

	func finishEnumeratingChanges(upTo anchor: NSFileProviderSyncAnchor, moreComing: Bool) {
		finishEnumeratingChangesUpToMoreComingCallsCount += 1
		finishEnumeratingChangesUpToMoreComingReceivedArguments = (anchor: anchor, moreComing: moreComing)
		finishEnumeratingChangesUpToMoreComingReceivedInvocations.append((anchor: anchor, moreComing: moreComing))
		finishEnumeratingChangesUpToMoreComingClosure?(anchor, moreComing)
	}

	// MARK: - finishEnumeratingWithError

	var finishEnumeratingWithErrorCallsCount = 0
	var finishEnumeratingWithErrorCalled: Bool {
		finishEnumeratingWithErrorCallsCount > 0
	}

	var finishEnumeratingWithErrorReceivedError: Error?
	var finishEnumeratingWithErrorReceivedInvocations: [Error] = []
	var finishEnumeratingWithErrorClosure: ((Error) -> Void)?

	func finishEnumeratingWithError(_ error: Error) {
		finishEnumeratingWithErrorCallsCount += 1
		finishEnumeratingWithErrorReceivedError = error
		finishEnumeratingWithErrorReceivedInvocations.append(error)
		finishEnumeratingWithErrorClosure?(error)
	}
}

// swiftlint:enable all
