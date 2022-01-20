//
//  FileProviderNotificator.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 13.07.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import FileProvider
import Foundation

public class FileProviderNotificator: FileProviderItemUpdateDelegate {
	private var signalDeleteContainerItemIdentifier = Set<NSFileProviderItemIdentifier>()
	private var signalUpdateContainerItem = [NSFileProviderItemIdentifier: NSFileProviderItem]()
	private var signalDeleteWorkingSetItemIdentifier = Set<NSFileProviderItemIdentifier>()
	private var signalUpdateWorkingSetItem = [NSFileProviderItemIdentifier: NSFileProviderItem]()

	/**
	 The current sync anchor for all FileProviderEnumerators.

	 The current anchor is the date and time of the `signalEnumerator` call as this guarantees us a different sync anchor each time  `signalEnumerator` gets called.
	 This is necessary as `finishEnumeratingChanges(upTo:, moreComing:)` expects "[...] that the sync anchor passed here be different than the sync
	 anchor that the enumeration started at, unless the client was already up to
	 date on all the changes on the server, and didn't have any pending updates or deletions." (from the SDK documentation).
	 */
	public var currentSyncAnchor: Data {
		do {
			return try JSONEncoder().encode(currentAnchor)
		} catch {
			return Data()
		}
	}

	private(set) var currentAnchor: Date
	private var invalidateWorkingSetCount = 0

	private let queue = DispatchQueue(label: "FileProviderNotificator", attributes: .concurrent)

	private let manager: NSFileProviderManager

	public init(manager: NSFileProviderManager) {
		self.manager = manager
		self.currentAnchor = Date()
	}

	public func invalidatedWorkingSet() {
		queue.sync(flags: .barrier) {
			signalDeleteContainerItemIdentifier.removeAll()
			signalUpdateWorkingSetItem.removeAll()
		}
	}

	public func refreshWorkingSet() {
		signalEnumerator(for: [.workingSet])
	}

	public func getItemIdentifiersToDeleteFromWorkingSet() -> [NSFileProviderItemIdentifier] {
		return queue.sync {
			return Array(signalDeleteWorkingSetItemIdentifier)
		}
	}

	public func popDeleteContainerItemIdentifiers() -> [NSFileProviderItemIdentifier] {
		return queue.sync(flags: .barrier) {
			let identifiers = Array(signalDeleteContainerItemIdentifier)
			signalDeleteContainerItemIdentifier.removeAll()
			return identifiers
		}
	}

	public func popUpdateWorkingSetItems() -> [NSFileProviderItem] {
		return queue.sync(flags: .barrier) {
			let items = signalUpdateWorkingSetItem.map { $0.value }
			signalUpdateWorkingSetItem.removeAll()
			return items
		}
	}

	public func popUpdateContainerItems() -> [NSFileProviderItem] {
		return queue.sync(flags: .barrier) {
			let items = signalUpdateContainerItem.map { $0.value }
			signalUpdateContainerItem.removeAll()
			return items
		}
	}

	/**
	 Signal the enumerator with a small delay of 0.2 seconds, because otherwise some items in the `FileProvider` are not updated correctly.
	 */
	public func signalEnumerator(for containerItemIdentifiers: [NSFileProviderItemIdentifier]) {
		DDLogDebug("Signal enumerator for: \(containerItemIdentifiers)")
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
			self.currentAnchor = Date()
			for containerItemIdentifier in containerItemIdentifiers {
				self.manager.signalEnumerator(for: containerItemIdentifier) { error in
					if let error = error {
						DDLogDebug("SignalEnumerator for \(containerItemIdentifier) returned error: \(error)")
					}
				}
			}
		}
	}

	func signalUpdate(for item: NSFileProviderItem) {
		appendItemToUpdateContainer(item)
		signalEnumerator(for: [item.parentItemIdentifier, item.itemIdentifier])
	}

	func removeItemFromWorkingSet(with identifier: NSFileProviderItemIdentifier) {
		appendIdentifierToDeleteWorkingSet(identifier)
		signalEnumerator(for: [.workingSet])
	}

	private func appendIdentifierToDeleteWorkingSet(_ identifier: NSFileProviderItemIdentifier) {
		queue.sync(flags: .barrier) {
			_ = signalDeleteWorkingSetItemIdentifier.insert(identifier)
		}
	}

	private func appendItemToUpdateContainer(_ item: NSFileProviderItem) {
		queue.sync(flags: .barrier) {
			signalUpdateContainerItem[item.itemIdentifier] = item
		}
	}
}

protocol FileProviderItemUpdateDelegate: AnyObject {
	func signalUpdate(for item: NSFileProviderItem)
	func removeItemFromWorkingSet(with identifier: NSFileProviderItemIdentifier)
	func refreshWorkingSet()
}
