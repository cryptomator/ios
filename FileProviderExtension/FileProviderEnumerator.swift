//
//  FileProviderEnumerator.swift
//  FileProviderExtension
//
//  Created by Philipp Schmid on 17.06.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorFileProvider
import FileProvider

class FileProviderEnumerator: NSObject, NSFileProviderEnumerator {
	private let enumeratedItemIdentifier: NSFileProviderItemIdentifier
	private let notificator: FileProviderNotificatorType
	private let domain: NSFileProviderDomain
	private let dbPath: URL
	private weak var localURLProvider: LocalURLProvider?

	init(enumeratedItemIdentifier: NSFileProviderItemIdentifier, notificator: FileProviderNotificatorType, domain: NSFileProviderDomain, dbPath: URL, localURLProvider: LocalURLProvider?) {
		self.enumeratedItemIdentifier = enumeratedItemIdentifier
		self.notificator = notificator
		self.domain = domain
		self.dbPath = dbPath
		self.localURLProvider = localURLProvider
		super.init()
	}

	func invalidate() {
		// TODO: perform invalidation of server connection if necessary
	}

	/**
	 Since unexpected behavior can occur in combination with the FileProviderExtensionUI in the unauthenticated state, two special cases must be considered here:
	 1. Biometric Unlock:
	 Triggering the biometric unlock results in the FileProviderExtensionUI being closed too quickly, so that the FileProviderAdapter is not yet deposited and we would again report a notAuthenticated Error.
	 This is fixed by using the BiometricalUnlockSemaphore so that the adapter is not retrieved too soon.

	 2. Open in Files app:
	 From time to time the FileProviderExtensionUI is dismissed directly, so the user only sees the password input for a short moment and has to trigger it manually again.
	 This is fixed by notifying the Files App with a delay of 1s in case of an error. Apparently the Files app has problems with a too fast reporting of the notAuthenticated error.
	 */
	func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
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
		DispatchQueue.global(qos: .userInitiated).async {
			FileProviderAdapterManager.shared.semaphore.wait()
			let adapter: FileProviderAdapterType
			do {
				adapter = try FileProviderAdapterManager.shared.getAdapter(forDomain: self.domain, dbPath: self.dbPath, delegate: self.localURLProvider, notificator: self.notificator)
			} catch {
				self.handleEnumerateItemsError(error, for: observer)
				return
			}
			adapter.enumerateItems(for: self.enumeratedItemIdentifier, withPageToken: pageToken).then { itemList in
				observer.didEnumerate(itemList.items)
				observer.finishEnumerating(upTo: itemList.nextPageToken)
			}.catch { error in
				DDLogError("enumerateItems failed with: \(error) for identifier: \(self.enumeratedItemIdentifier)")
				observer.finishEnumeratingWithError(error)
			}
		}
	}

	func enumerateChanges(for observer: NSFileProviderChangeObserver, from anchor: NSFileProviderSyncAnchor) {
		/* TODO:
		 - query the server for updates since the passed-in sync anchor

		 If this is an enumerator for the active set:
		 - note the changes in your local database

		 - inform the observer about item deletions and updates (modifications + insertions)
		 - inform the observer when you have finished enumerating up to a subsequent sync anchor
		 */

		DDLogDebug("Enumerate changes for: \(enumeratedItemIdentifier.rawValue)")
		var itemsDelete = [NSFileProviderItemIdentifier]()
		var itemsUpdate = [NSFileProviderItem]()

		// Report the deleted items
		if enumeratedItemIdentifier == .workingSet {
			do {
				_ = try FileProviderAdapterManager.shared.getAdapter(forDomain: domain, dbPath: dbPath, delegate: localURLProvider, notificator: notificator)
			} catch {
				DDLogDebug("Invalidate working set because the vault \(domain.displayName) is locked")
				observer.finishEnumeratingWithError(NSFileProviderError(.syncAnchorExpired))
				return
			}
			itemsDelete.append(contentsOf: notificator.getItemIdentifiersToDeleteFromWorkingSet())
			DDLogDebug("Remove \(itemsDelete.count) items from the working set")
		} else {
			itemsDelete.append(contentsOf: notificator.popDeleteContainerItemIdentifiers())
		}

		// Report the updated items
		if enumeratedItemIdentifier == .workingSet {
			itemsUpdate.append(contentsOf: notificator.popUpdateWorkingSetItems())
		} else {
			itemsUpdate.append(contentsOf: notificator.popUpdateContainerItems())
		}
		observer.didDeleteItems(withIdentifiers: itemsDelete)
		observer.didUpdate(itemsUpdate)

		let syncAnchor = NSFileProviderSyncAnchor(notificator.currentSyncAnchor)
		observer.finishEnumeratingChanges(upTo: syncAnchor, moreComing: false)
	}

	func currentSyncAnchor(completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
		let syncAnchor = NSFileProviderSyncAnchor(notificator.currentSyncAnchor)
		completionHandler(syncAnchor)
	}

	/**
	 Handle errors from `enumerateItems(for:, startingAt:)` calls.

	 If this gets called for an working set enumerator, the working set cache gets invalidated by calling `finishEnumeratingWithError` with `NSFileProviderErrorSyncAnchorExpired`.
	 Invalidating the working set cache is necessary as otherwise recently accessed items can be found in the global siri search even if the vault is locked.

	 For all other enumerators the error gets wrapped and reported with 1s delay as the Files app has problems with too fast reporting of an `notAuthenticated` error.
	 */
	private func handleEnumerateItemsError(_ error: Error, for observer: NSFileProviderEnumerationObserver) {
		DDLogError("enumerateItems getAdapter failed with: \(error) for identifier: \(enumeratedItemIdentifier)")
		guard enumeratedItemIdentifier != .workingSet else {
			observer.finishEnumeratingWithError(NSFileProviderError(.syncAnchorExpired))
			notificator.invalidatedWorkingSet()
			return
		}
		DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 1) {
			let wrappedError = ErrorWrapper.wrapError(error, domain: self.domain)
			observer.finishEnumeratingWithError(wrappedError)
		}
	}
}
