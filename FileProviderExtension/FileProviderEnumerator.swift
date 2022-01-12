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
	private let notificator: FileProviderNotificator
	private let domain: NSFileProviderDomain
	private let manager: NSFileProviderManager
	private let dbPath: URL
	private weak var localURLProvider: LocalURLProvider?

	init(enumeratedItemIdentifier: NSFileProviderItemIdentifier, notificator: FileProviderNotificator, domain: NSFileProviderDomain, manager: NSFileProviderManager, dbPath: URL, localURLProvider: LocalURLProvider?) {
		self.enumeratedItemIdentifier = enumeratedItemIdentifier
		self.notificator = notificator
		self.domain = domain
		self.manager = manager
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
		DDLogDebug("enumerateItems called for identifier: \(enumeratedItemIdentifier)")
		var pageToken: String?
		if page != NSFileProviderPage.initialPageSortedByDate as NSFileProviderPage, page != NSFileProviderPage.initialPageSortedByName as NSFileProviderPage {
			pageToken = String(data: page.rawValue, encoding: .utf8)!
		}
		DispatchQueue.global(qos: .userInitiated).async {
			FileProviderAdapterManager.shared.semaphore.wait()
			let adapter: FileProviderAdapterType
			do {
				adapter = try FileProviderAdapterManager.shared.getAdapter(forDomain: self.domain, dbPath: self.dbPath, delegate: self.localURLProvider, notificator: self.notificator)
			} catch {
				DDLogError("enumerateItems getAdapter failed with: \(error) for identifier: \(self.enumeratedItemIdentifier)")
				DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 1) {
					let wrappedError = ErrorWrapper.wrapError(error, domain: self.domain)
					observer.finishEnumeratingWithError(wrappedError)
				}
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

		DDLogDebug("FPExt: enumerate now changes for: \(enumeratedItemIdentifier)")
		var itemsDelete = [NSFileProviderItemIdentifier]()
		var itemsUpdate = [FileProviderItem]()

		// Report the deleted items
		if enumeratedItemIdentifier == .workingSet {
			for (itemIdentifier, _) in notificator.fileProviderSignalDeleteWorkingSetItemIdentifier {
				itemsDelete.append(itemIdentifier)
			}
			notificator.fileProviderSignalDeleteWorkingSetItemIdentifier.removeAll()
		} else {
			for (itemIdentifier, _) in notificator.fileProviderSignalDeleteContainerItemIdentifier {
				itemsDelete.append(itemIdentifier)
			}
			notificator.fileProviderSignalDeleteContainerItemIdentifier.removeAll()
		}

		// Report the updated items
		if enumeratedItemIdentifier == .workingSet {
			for (_, item) in notificator.fileProviderSignalUpdateWorkingSetItem {
				itemsUpdate.append(item)
			}
			notificator.fileProviderSignalUpdateWorkingSetItem.removeAll()
		} else {
			for (_, item) in notificator.fileProviderSignalUpdateContainerItem {
				itemsUpdate.append(item)
			}
			notificator.fileProviderSignalUpdateContainerItem.removeAll()
		}
		observer.didDeleteItems(withIdentifiers: itemsDelete)
		observer.didUpdate(itemsUpdate)

		let data = "\(notificator.currentAnchor)".data(using: .utf8)
		observer.finishEnumeratingChanges(upTo: NSFileProviderSyncAnchor(data!), moreComing: false)
	}

	func currentSyncAnchor(completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
		let data = "\(notificator.currentAnchor)".data(using: .utf8)
		completionHandler(NSFileProviderSyncAnchor(data!))
	}
}
