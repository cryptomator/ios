//
//  RunningDownloadCache.swift
//  CryptomatorFileProvider
//
//  Created by Tobias Hagemann on 28.05.26.
//  Copyright © 2026 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import FileProvider
import Foundation
import Promises

/**
 Coalesces concurrent in-flight downloads for the same identifier onto a single shared `Promise<Void>`.

 iOS Files.app can invoke `startProvidingItem` multiple times for the same identifier in rapid succession during a tap-burst.
 Without coalescing each call creates a fresh `DownloadTask`, consumes a scheduler slot and issues a duplicate GET, which
 contributes to the file provider extension exceeding its XPC budget.
 */
class RunningDownloadCache {
	private let queue = DispatchQueue(label: "RunningDownloadCache")
	private var inFlight = [NSFileProviderItemIdentifier: Promise<Void>]()

	func getOrCreate(for identifier: NSFileProviderItemIdentifier, factory: () -> Promise<Void>) -> Promise<Void> {
		return queue.sync {
			if let existing = inFlight[identifier] {
				DDLogDebug("RunningDownloadCache: coalesced hit for \(identifier)")
				return existing
			}
			DDLogDebug("RunningDownloadCache: miss for \(identifier)")
			let promise = factory()
			inFlight[identifier] = promise
			promise.always(on: queue) { [weak self] in
				self?.inFlight[identifier] = nil
			}
			return promise
		}
	}
}
