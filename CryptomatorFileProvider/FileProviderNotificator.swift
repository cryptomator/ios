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

public protocol FileProviderNotificatorType: FileProviderItemUpdateDelegate {
	var currentSyncAnchor: Data { get }
	func invalidatedWorkingSet()
	func getItemIdentifiersToDeleteFromWorkingSet() -> [NSFileProviderItemIdentifier]
	func popDeleteContainerItemIdentifiers() -> [NSFileProviderItemIdentifier]
	func popUpdateWorkingSetItems() -> [NSFileProviderItem]
	func popUpdateContainerItems() -> [NSFileProviderItem]
}

public class FileProviderNotificator: FileProviderNotificatorType {
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
			let anchor = queue.sync {
				return currentAnchor
			}
			return try JSONEncoder().encode(anchor)
		} catch {
			return Data()
		}
	}

	private(set) var currentAnchor: SyncAnchor
	private let queue = DispatchQueue(label: "FileProviderNotificator", attributes: .concurrent)
	private let manager: EnumerationSignaling

	public init(manager: EnumerationSignaling) {
		self.manager = manager
		self.currentAnchor = .initial
	}

	public func invalidatedWorkingSet() {
		let anchor = SyncAnchor(invalidated: true, date: Date())
		DDLogDebug("Invalidated Working Set new anchor -> \(anchor)")
		setSyncAnchor(to: anchor)
		queue.sync(flags: .barrier) {
			signalDeleteWorkingSetItemIdentifier.removeAll()
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

	public func signalUpdate(for item: NSFileProviderItem) {
		appendItemToUpdateContainer(item)
		signalEnumerator(for: [item.parentItemIdentifier, item.itemIdentifier])
	}

	public func removeItemFromWorkingSet(with identifier: NSFileProviderItemIdentifier) {
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

	/**
	 Signal the enumerator with a small delay of 0.2 seconds, because otherwise some items in the `FileProvider` are not updated correctly.
	 */
	private func signalEnumerator(for containerItemIdentifiers: [NSFileProviderItemIdentifier]) {
		DDLogDebug("Signal enumerator for: \(containerItemIdentifiers)")
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
			self.setSyncAnchor(to: SyncAnchor(invalidated: false, date: Date()))
			for containerItemIdentifier in containerItemIdentifiers {
				self.manager.signalEnumerator(for: containerItemIdentifier) { error in
					if let error = error {
						DDLogDebug("SignalEnumerator for \(containerItemIdentifier) returned error: \(error)")
					}
				}
			}
		}
	}

	public func removeItemsFromWorkingSet(with identifiers: [NSFileProviderItemIdentifier]) {
		identifiers.forEach { appendIdentifierToDeleteWorkingSet($0) }
	}

	public func updateWorkingSetItems(_ items: [NSFileProviderItem]) {
		queue.sync(flags: .barrier) {
			for item in items {
				signalDeleteWorkingSetItemIdentifier.remove(item.itemIdentifier)
				signalUpdateWorkingSetItem[item.itemIdentifier] = item
			}
		}
	}

	private func setSyncAnchor(to updatedSyncAnchor: SyncAnchor) {
		queue.sync(flags: .barrier) {
			currentAnchor = updatedSyncAnchor
		}
	}
}

public protocol FileProviderItemUpdateDelegate: AnyObject {
	func signalUpdate(for item: NSFileProviderItem)
	func removeItemFromWorkingSet(with identifier: NSFileProviderItemIdentifier)
	func removeItemsFromWorkingSet(with identifiers: [NSFileProviderItemIdentifier])
	func refreshWorkingSet()
	func updateWorkingSetItems(_ items: [NSFileProviderItem])
}

public protocol EnumerationSignaling {
	func signalEnumerator(for containerItemIdentifier: NSFileProviderItemIdentifier, completionHandler completion: @escaping (Error?) -> Void)
}

extension NSFileProviderManager: EnumerationSignaling {}

public struct SyncAnchor: Codable {
	/// Indicates if since the last call of `enumerateChanges(for:from:)` the enumeration cache of the Files app was invalidated with a `.syncAnchorExpired` error.
	public let invalidated: Bool
	/// The creation date of the sync anchor
	public let date: Date
}

extension SyncAnchor {
	static var initial: SyncAnchor {
		return SyncAnchor(invalidated: false, date: Date())
	}
}
