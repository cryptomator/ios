//
//  CacheManagingServiceSource.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 10.05.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCommonCore
import FileProvider
import Foundation

public class CacheManagingServiceSource: ServiceSource, CacheManaging {
	let domainProvider: NSFileProviderDomainProvider
	let cachedManagerFactory: CachedFileManagerFactory
	let notificator: FileProviderNotificatorType?
	public var getItem: ((NSFileProviderItemIdentifier) -> NSFileProviderItem?)?

	public convenience init(notificator: FileProviderNotificatorType?) {
		self.init(notificator: notificator, cachedManagerFactory: CachedFileDBManagerFactory.shared, domainProvider: NSFileProviderManager.default)
	}

	init(notificator: FileProviderNotificatorType?, cachedManagerFactory: CachedFileManagerFactory, domainProvider: NSFileProviderDomainProvider) {
		self.notificator = notificator
		self.cachedManagerFactory = cachedManagerFactory
		self.domainProvider = domainProvider
		super.init(serviceName: .cacheManaging, exportedInterface: NSXPCInterface(with: CacheManaging.self))
	}

	public func evictFileFromCache(with identifier: NSFileProviderItemIdentifier, reply: @escaping (NSError?) -> Void) {
		guard let domainIdentifier = identifier.domainIdentifier else {
			DDLogError("Evict file from cache no domainIdentifier found for itemIdentifier: \(identifier)")
			reply(FileProviderXPCConnectorError.domainNotFound as NSError)
			return
		}
		let domain = NSFileProviderDomain(identifier: domainIdentifier)
		do {
			let cacheManager = try cachedManagerFactory.createCachedFileManager(for: domain)
			try cacheManager.removeCachedFile(for: identifier)
			if let item = getItem?(identifier) {
				notificator?.signalUpdate(for: item)
			}
			reply(nil)
		} catch {
			DDLogError("Evict file from cache failed with error: \(error)")
			reply(error as NSError)
		}
	}

	public func clearCache(reply: @escaping (NSError?) -> Void) {
		domainProvider.getDomains().then { domains in
			try self.clearCache(for: domains)
			reply(nil)
		}.catch {
			reply($0 as NSError)
		}
	}

	public func getLocalCacheSizeInBytes(reply: @escaping (NSNumber?, NSError?) -> Void) {
		domainProvider.getDomains().then { domains in
			let totalCacheSize = try self.getLocalCacheSizeInBytes(for: domains)
			reply(totalCacheSize as NSNumber, nil)
		}.catch {
			reply(nil, $0 as NSError)
		}
	}

	private func clearCache(for domains: [NSFileProviderDomain]) throws {
		for domain in domains {
			let cacheManager = try cachedManagerFactory.createCachedFileManager(for: domain)
			try cacheManager.clearCache()
		}
	}

	private func getLocalCacheSizeInBytes(for domains: [NSFileProviderDomain]) throws -> Int {
		return try domains.reduce(0) {
			let cacheManager = try cachedManagerFactory.createCachedFileManager(for: $1)
			let cacheSizeInBytes = try cacheManager.getLocalCacheSizeInBytes()
			return $0 + cacheSizeInBytes
		}
	}
}
