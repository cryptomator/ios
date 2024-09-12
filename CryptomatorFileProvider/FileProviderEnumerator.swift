//
//  FileProviderEnumerator.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 24.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import FileProvider

public class FileProviderEnumerator: NSObject, NSFileProviderEnumerator {
	private let enumeratedItemIdentifier: NSFileProviderItemIdentifier
	private let notificator: FileProviderNotificatorType
	private let domain: NSFileProviderDomain
	private let dbPath: URL
	private let adapterProvider: FileProviderAdapterProviding
	private let localURLProvider: LocalURLProviderType
	private let taskRegistrator: SessionTaskRegistrator

	public convenience init(enumeratedItemIdentifier: NSFileProviderItemIdentifier, notificator: FileProviderNotificatorType, domain: NSFileProviderDomain, dbPath: URL, localURLProvider: LocalURLProviderType, taskRegistrator: SessionTaskRegistrator) {
		self.init(enumeratedItemIdentifier: enumeratedItemIdentifier,
		          notificator: notificator,
		          domain: domain,
		          dbPath: dbPath,
		          localURLProvider: localURLProvider,
		          adapterProvider: FileProviderAdapterManager.shared,
		          taskRegistrator: taskRegistrator)
	}

	init(enumeratedItemIdentifier: NSFileProviderItemIdentifier, notificator: FileProviderNotificatorType, domain: NSFileProviderDomain, dbPath: URL, localURLProvider: LocalURLProviderType, adapterProvider: FileProviderAdapterProviding, taskRegistrator: SessionTaskRegistrator) {
		self.enumeratedItemIdentifier = enumeratedItemIdentifier
		self.notificator = notificator
		self.domain = domain
		self.dbPath = dbPath
		self.localURLProvider = localURLProvider
		self.adapterProvider = adapterProvider
		self.taskRegistrator = taskRegistrator
		super.init()
	}

	public func invalidate() {}

	/**
	 Since unexpected behavior can occur in combination with the FileProviderExtensionUI in the unauthenticated state, two special cases must be considered here:
	 1. Biometric Unlock:
	 Triggering the biometric unlock results in the FileProviderExtensionUI being closed too quickly, so that the FileProviderAdapter is not yet deposited and we would again report a notAuthenticated Error.
	 This is fixed by using the BiometricalUnlockSemaphore so that the adapter is not retrieved too soon.

	 2. Open in Files app:
	 From time to time the FileProviderExtensionUI is dismissed directly, so the user only sees the password input for a short moment and has to trigger it manually again.
	 This is fixed by notifying the Files App with a delay of 1s in case of an error. Apparently the Files app has problems with a too fast reporting of the notAuthenticated error.
	 */
	public func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
		/* TODO:
		 - inspect the page to determine whether this is an initial or a follow-up request

		 If this is an enumerator for a directory, the root container or all directories:
		 - perform a server request to fetch directory contents
		 If this is an enumerator for the active set:
		 - perform a server request to update your local database
		 - fetch the active set from your local database

		 - inform the observer about the items returned by the server (possibly multiple times)
		 - inform the observer that you are finished with this page
		 */

		var pageToken: String?
		if page != NSFileProviderPage.initialPageSortedByDate as NSFileProviderPage, page != NSFileProviderPage.initialPageSortedByName as NSFileProviderPage {
			pageToken = String(data: page.rawValue, encoding: .utf8)
		}
		DDLogDebug("enumerateItems called for identifier: \(enumeratedItemIdentifier) - initialPage \(pageToken == nil)")
		adapterProvider.unlockMonitor.execute {
			let adapter: FileProviderAdapterType
			do {
				adapter = try self.adapterProvider.getAdapter(forDomain: self.domain, dbPath: self.dbPath, delegate: self.localURLProvider, notificator: self.notificator, taskRegistrator: self.taskRegistrator)
			} catch {
				self.handleEnumerateItemsError(error, for: observer)
				return
			}
			adapter.enumerateItems(for: self.enumeratedItemIdentifier, withPageToken: pageToken).then { itemList in
				DDLogDebug("enumerateItems returned \(itemList.items.count) items for identifier: \(self.enumeratedItemIdentifier)")
				observer.didEnumerate(itemList.items)
				observer.finishEnumerating(upTo: itemList.nextPageToken)
			}.catch { error in
				DDLogError("enumerateItems failed with: \(error) for identifier: \(self.enumeratedItemIdentifier)")
				observer.finishEnumeratingWithError(error)
			}
		}
	}

	public func enumerateChanges(for observer: NSFileProviderChangeObserver, from anchor: NSFileProviderSyncAnchor) {
		/* TODO:
		 - query the server for updates since the passed-in sync anchor

		 If this is an enumerator for the active set:
		 - note the changes in your local database

		 - inform the observer about item deletions and updates (modifications + insertions)
		 - inform the observer when you have finished enumerating up to a subsequent sync anchor
		 */

		DDLogDebug("Enumerate changes for: \(enumeratedItemIdentifier.rawValue) anchor: \(String(describing: try? JSONDecoder().decode(SyncAnchor.self, from: anchor.rawValue)))")
		var itemsDelete = [NSFileProviderItemIdentifier]()
		var itemsUpdate = [NSFileProviderItem]()
		let currentSyncAnchor = NSFileProviderSyncAnchor(notificator.currentSyncAnchor)

		// Handle working set
		if enumeratedItemIdentifier == .workingSet {
			let workingSetSyncAnchor: SyncAnchor
			do {
				workingSetSyncAnchor = try JSONDecoder().decode(SyncAnchor.self, from: anchor.rawValue)
			} catch {
				DDLogDebug("Invalidate working set because the sync anchor for vault \(domain.displayName) is invalid")
				invalidateWorkingSet(observer: observer)
				return
			}

			let adapter: FileProviderAdapterType
			do {
				adapter = try adapterProvider.getAdapter(forDomain: domain, dbPath: dbPath, delegate: localURLProvider, notificator: notificator, taskRegistrator: taskRegistrator)
			} catch {
				if workingSetSyncAnchor.invalidated {
					DDLogDebug("Working set for \(domain.displayName) is already invalidated -> return empty array")
					observer.finishEnumeratingChanges(upTo: anchor, moreComing: false)
				} else {
					DDLogDebug("Invalidate working set because the vault \(domain.displayName) is locked")
					invalidateWorkingSet(observer: observer)
				}
				return
			}
			guard adapter.lastUnlockedDate <= workingSetSyncAnchor.date else {
				invalidateWorkingSet(observer: observer)
				return
			}
			itemsDelete.append(contentsOf: notificator.getItemIdentifiersToDeleteFromWorkingSet())
			DDLogDebug("Remove \(itemsDelete.count) items from the working set")

			itemsUpdate.append(contentsOf: notificator.popUpdateWorkingSetItems())
			DDLogDebug("Updated \(itemsUpdate.count) items from the working set")
		} else {
			itemsUpdate.append(contentsOf: notificator.popUpdateContainerItems())
		}
		observer.didDeleteItems(withIdentifiers: itemsDelete)
		observer.didUpdate(itemsUpdate)
		observer.finishEnumeratingChanges(upTo: currentSyncAnchor, moreComing: false)
	}

	public func currentSyncAnchor(completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
		DDLogDebug("currentSyncAnchor for \(enumeratedItemIdentifier.rawValue) called -> return: \(String(describing: try? JSONDecoder().decode(SyncAnchor.self, from: notificator.currentSyncAnchor))) ")
		let syncAnchor = NSFileProviderSyncAnchor(notificator.currentSyncAnchor)
		completionHandler(syncAnchor)
	}

	/**
	 Handle errors from `enumerateItems(for:, startingAt:)` calls.

	 If this gets called for a working set enumerator, the working set cache gets invalidated by calling `finishEnumeratingWithError` with `NSFileProviderErrorSyncAnchorExpired`.
	 Invalidating the working set cache is necessary as otherwise recently accessed items can be found in the global Siri search even if the vault is locked.

	 For all other enumerators the error gets wrapped and reported with 1s delay as the Files app has problems with too fast reporting of an `notAuthenticated` error.
	 */
	private func handleEnumerateItemsError(_ error: Error, for observer: NSFileProviderEnumerationObserver) {
		guard enumeratedItemIdentifier != .workingSet else {
			DDLogDebug("enumerateItems getAdapter failed with: \(error) -> return empty working set array")
			observer.didEnumerate([])
			observer.finishEnumerating(upTo: nil)
			return
		}
		DDLogError("enumerateItems getAdapter failed with: \(error) for identifier: \(enumeratedItemIdentifier)")
		DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
			let wrappedError = ErrorWrapper.wrapError(error, domain: self.domain)
			observer.finishEnumeratingWithError(wrappedError)
		}
	}

	private func invalidateWorkingSet(observer: NSFileProviderChangeObserver) {
		notificator.invalidatedWorkingSet()
		observer.finishEnumeratingWithError(NSFileProviderError(.syncAnchorExpired))
	}
}
