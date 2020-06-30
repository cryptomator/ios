//
//  FileProviderEnumerator.swift
//  File Provider Extension
//
//  Created by Philipp Schmid on 17.06.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorFileProvider
import FileProvider

class FileProviderEnumerator: NSObject, NSFileProviderEnumerator {
	var enumeratedItemIdentifier: NSFileProviderItemIdentifier
	let decorator: FileProviderDecorator
	init(enumeratedItemIdentifier: NSFileProviderItemIdentifier, decorator: FileProviderDecorator) {
		self.enumeratedItemIdentifier = enumeratedItemIdentifier
		self.decorator = decorator
		super.init()
	}

	func invalidate() {
		// TODO: perform invalidation of server connection if necessary
	}

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
			pageToken = String(data: page.rawValue, encoding: .utf8)!
		}
		decorator.fetchItemList(for: enumeratedItemIdentifier, withPageToken: pageToken).then { itemList in
			observer.didEnumerate(itemList.items)
			observer.finishEnumerating(upTo: itemList.nextPageToken)
		}.catch { error in
			observer.finishEnumeratingWithError(error)
		}
	}

	func enumerateChanges(for _: NSFileProviderChangeObserver, from _: NSFileProviderSyncAnchor) {
		/* TODO:
		 - query the server for updates since the passed-in sync anchor

		 If this is an enumerator for the active set:
		 - note the changes in your local database

		 - inform the observer about item deletions and updates (modifications + insertions)
		 - inform the observer when you have finished enumerating up to a subsequent sync anchor
		 */
	}
}
