//
//  FileProviderNotificatorMock.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 21.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorFileProvider
import FileProvider
import Foundation

// swiftlint:disable all
final class FileProviderNotificatorTypeMock: FileProviderNotificatorType {
	// MARK: - currentSyncAnchor

	var currentSyncAnchor: Data {
		get { underlyingCurrentSyncAnchor }
		set(value) { underlyingCurrentSyncAnchor = value }
	}

	private var underlyingCurrentSyncAnchor: Data!

	// MARK: - invalidatedWorkingSet

	var invalidatedWorkingSetCallsCount = 0
	var invalidatedWorkingSetCalled: Bool {
		invalidatedWorkingSetCallsCount > 0
	}

	var invalidatedWorkingSetClosure: (() -> Void)?

	func invalidatedWorkingSet() {
		invalidatedWorkingSetCallsCount += 1
		invalidatedWorkingSetClosure?()
	}

	// MARK: - getItemIdentifiersToDeleteFromWorkingSet

	var getItemIdentifiersToDeleteFromWorkingSetCallsCount = 0
	var getItemIdentifiersToDeleteFromWorkingSetCalled: Bool {
		getItemIdentifiersToDeleteFromWorkingSetCallsCount > 0
	}

	var getItemIdentifiersToDeleteFromWorkingSetReturnValue: [NSFileProviderItemIdentifier]!
	var getItemIdentifiersToDeleteFromWorkingSetClosure: (() -> [NSFileProviderItemIdentifier])?

	func getItemIdentifiersToDeleteFromWorkingSet() -> [NSFileProviderItemIdentifier] {
		getItemIdentifiersToDeleteFromWorkingSetCallsCount += 1
		return getItemIdentifiersToDeleteFromWorkingSetClosure.map({ $0() }) ?? getItemIdentifiersToDeleteFromWorkingSetReturnValue
	}

	// MARK: - popDeleteContainerItemIdentifiers

	var popDeleteContainerItemIdentifiersCallsCount = 0
	var popDeleteContainerItemIdentifiersCalled: Bool {
		popDeleteContainerItemIdentifiersCallsCount > 0
	}

	var popDeleteContainerItemIdentifiersReturnValue: [NSFileProviderItemIdentifier]!
	var popDeleteContainerItemIdentifiersClosure: (() -> [NSFileProviderItemIdentifier])?

	func popDeleteContainerItemIdentifiers() -> [NSFileProviderItemIdentifier] {
		popDeleteContainerItemIdentifiersCallsCount += 1
		return popDeleteContainerItemIdentifiersClosure.map({ $0() }) ?? popDeleteContainerItemIdentifiersReturnValue
	}

	// MARK: - popUpdateWorkingSetItems

	var popUpdateWorkingSetItemsCallsCount = 0
	var popUpdateWorkingSetItemsCalled: Bool {
		popUpdateWorkingSetItemsCallsCount > 0
	}

	var popUpdateWorkingSetItemsReturnValue: [NSFileProviderItem]!
	var popUpdateWorkingSetItemsClosure: (() -> [NSFileProviderItem])?

	func popUpdateWorkingSetItems() -> [NSFileProviderItem] {
		popUpdateWorkingSetItemsCallsCount += 1
		return popUpdateWorkingSetItemsClosure.map({ $0() }) ?? popUpdateWorkingSetItemsReturnValue
	}

	// MARK: - popUpdateContainerItems

	var popUpdateContainerItemsCallsCount = 0
	var popUpdateContainerItemsCalled: Bool {
		popUpdateContainerItemsCallsCount > 0
	}

	var popUpdateContainerItemsReturnValue: [NSFileProviderItem]!
	var popUpdateContainerItemsClosure: (() -> [NSFileProviderItem])?

	func popUpdateContainerItems() -> [NSFileProviderItem] {
		popUpdateContainerItemsCallsCount += 1
		return popUpdateContainerItemsClosure.map({ $0() }) ?? popUpdateContainerItemsReturnValue
	}

	// MARK: - signalUpdate

	var signalUpdateForCallsCount = 0
	var signalUpdateForCalled: Bool {
		signalUpdateForCallsCount > 0
	}

	var signalUpdateForReceivedItem: NSFileProviderItem?
	var signalUpdateForReceivedInvocations: [NSFileProviderItem] = []
	var signalUpdateForClosure: ((NSFileProviderItem) -> Void)?

	func signalUpdate(for item: NSFileProviderItem) {
		signalUpdateForCallsCount += 1
		signalUpdateForReceivedItem = item
		signalUpdateForReceivedInvocations.append(item)
		signalUpdateForClosure?(item)
	}

	// MARK: - removeItemFromWorkingSet

	var removeItemFromWorkingSetWithCallsCount = 0
	var removeItemFromWorkingSetWithCalled: Bool {
		removeItemFromWorkingSetWithCallsCount > 0
	}

	var removeItemFromWorkingSetWithReceivedIdentifier: NSFileProviderItemIdentifier?
	var removeItemFromWorkingSetWithReceivedInvocations: [NSFileProviderItemIdentifier] = []
	var removeItemFromWorkingSetWithClosure: ((NSFileProviderItemIdentifier) -> Void)?

	func removeItemFromWorkingSet(with identifier: NSFileProviderItemIdentifier) {
		removeItemFromWorkingSetWithCallsCount += 1
		removeItemFromWorkingSetWithReceivedIdentifier = identifier
		removeItemFromWorkingSetWithReceivedInvocations.append(identifier)
		removeItemFromWorkingSetWithClosure?(identifier)
	}

	// MARK: - removeItemsFromWorkingSet

	var removeItemsFromWorkingSetWithCallsCount = 0
	var removeItemsFromWorkingSetWithCalled: Bool {
		removeItemsFromWorkingSetWithCallsCount > 0
	}

	var removeItemsFromWorkingSetWithReceivedIdentifiers: [NSFileProviderItemIdentifier]?
	var removeItemsFromWorkingSetWithReceivedInvocations: [[NSFileProviderItemIdentifier]] = []
	var removeItemsFromWorkingSetWithClosure: (([NSFileProviderItemIdentifier]) -> Void)?

	func removeItemsFromWorkingSet(with identifiers: [NSFileProviderItemIdentifier]) {
		removeItemsFromWorkingSetWithCallsCount += 1
		removeItemsFromWorkingSetWithReceivedIdentifiers = identifiers
		removeItemsFromWorkingSetWithReceivedInvocations.append(identifiers)
		removeItemsFromWorkingSetWithClosure?(identifiers)
	}

	// MARK: - refreshWorkingSet

	var refreshWorkingSetCallsCount = 0
	var refreshWorkingSetCalled: Bool {
		refreshWorkingSetCallsCount > 0
	}

	var refreshWorkingSetClosure: (() -> Void)?

	func refreshWorkingSet() {
		refreshWorkingSetCallsCount += 1
		refreshWorkingSetClosure?()
	}

	// MARK: - updateWorkingSetItems

	var updateWorkingSetItemsCallsCount = 0
	var updateWorkingSetItemsCalled: Bool {
		updateWorkingSetItemsCallsCount > 0
	}

	var updateWorkingSetItemsReceivedItems: [NSFileProviderItem]?
	var updateWorkingSetItemsReceivedInvocations: [[NSFileProviderItem]] = []
	var updateWorkingSetItemsClosure: (([NSFileProviderItem]) -> Void)?

	func updateWorkingSetItems(_ items: [NSFileProviderItem]) {
		updateWorkingSetItemsCallsCount += 1
		updateWorkingSetItemsReceivedItems = items
		updateWorkingSetItemsReceivedInvocations.append(items)
		updateWorkingSetItemsClosure?(items)
	}
}

// swiftlint:enable all
