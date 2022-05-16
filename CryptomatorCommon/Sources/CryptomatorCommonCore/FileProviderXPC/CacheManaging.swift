//
//  CacheManaging.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 10.05.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import FileProvider
import Foundation
import Promises

@objc public protocol CacheManaging: NSFileProviderServiceSource {
	/**
	 Evicts the local file belonging to the given `identifier` from the cache.

	 A file gets evicted from the cache only if there is no pending (or failed) upload for that file.

	 `Reply` will be called with `nil` if the call was successful, otherwise the error will be passed as an `NSError`.
	 "Because communication over XPC is asynchronous, all methods in the protocol must have a return type of void. If you need to return data, you can define a reply block [...]" see: https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingXPCServices.html
	 */
	func evictFileFromCache(with identifier: NSFileProviderItemIdentifier, reply: @escaping (NSError?) -> Void)

	/**
	 Clears the entire cache of all FileProviderDomains.

	 Only files that do not have a pending or failed upload are removed from the cache.

	 `Reply` will be called with `nil` if the call was successful, otherwise the error will be passed as an `NSError`.
	 "Because communication over XPC is asynchronous, all methods in the protocol must have a return type of void. If you need to return data, you can define a reply block [...]" see: https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingXPCServices.html
	 */
	func clearCache(reply: @escaping (NSError?) -> Void)

	/**
	 Returns the total local cache size in bytes currently used by all FileProviderDomains.

	 - Note: Only files that do not have a pending or failed upload are counted towards the cache.

	 `Reply` will be called with the size of the local cache size in bytes if the call was successful, otherwise the error will be passed as an `NSError`.
	 "Because communication over XPC is asynchronous, all methods in the protocol must have a return type of void. If you need to return data, you can define a reply block [...]" see: https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingXPCServices.html
	 */
	func getLocalCacheSizeInBytes(reply: @escaping (NSNumber?, NSError?) -> Void)
}

public extension CacheManaging {
	/**
	 Evicts the local file belonging to the given `identifier` from the cache.

	 A file gets evicted from the cache only if there is no pending (or failed) upload for that file.
	 */
	func evictFileFromCache(with itemIdentifier: NSFileProviderItemIdentifier) -> Promise<Void> {
		return wrap {
			self.evictFileFromCache(with: itemIdentifier, reply: $0)
		}.then { error -> Void in
			if let error = error {
				throw error
			}
		}
	}

	func evictFilesFromCache(with itemIdentifiers: [NSFileProviderItemIdentifier]) -> Promise<Void> {
		guard let itemIdentifier = itemIdentifiers.first else {
			return Promise(())
		}
		return evictFileFromCache(with: itemIdentifier).then {
			self.evictFilesFromCache(with: Array(itemIdentifiers.dropFirst()))
		}
	}

	/**
	 Clears the entire cache of all FileProviderDomains.

	 Only files that do not have a pending or failed upload are removed from the cache.
	 */
	func clearCache() -> Promise<Void> {
		return wrap {
			self.clearCache(reply: $0)
		}.then { error -> Void in
			if let error = error {
				throw error
			}
		}
	}

	/**
	 Returns the total local cache size in bytes currently used by all FileProviderDomains.

	 - Note: Only files that do not have a pending or failed upload are counted towards the cache.
	 */
	func getLocalCacheSizeInBytes() -> Promise<NSNumber?> {
		return wrap {
			self.getLocalCacheSizeInBytes(reply: $0)
		}
	}
}

public extension NSFileProviderServiceName {
	static let cacheManaging = NSFileProviderServiceName("org.cryptomator.ios.cache-managing")
}
