//
//  FileProviderCacheManager.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 05.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import FileProvider
import Foundation
import Promises

public class FileProviderCacheManager {
	private let documentStorageURLProvider: DocumentStorageURLProvider

	init(documentStorageURLProvider: DocumentStorageURLProvider = NSFileProviderManager.default) {
		self.documentStorageURLProvider = documentStorageURLProvider
	}

	public func getTotalLocalCacheSizeInBytes() -> Promise<Int> {
		return NSFileProviderManager.getDomains().then(getLocalCacheSizeInBytes)
	}

	public func clearCache() -> Promise<Void> {
		return NSFileProviderManager.getDomains().then(clearCache)
	}

	func getLocalCacheSizeInBytes(for domains: [NSFileProviderDomain]) throws -> Int {
		let dbURLs = getDatabaseURLs(for: domains)
		return try dbURLs.reduce(0) {
			let database = try DatabaseHelper.getMigratedDB(at: $1)
			let cachedFileManager = CachedFileDBManager(database: database)
			let cacheSizeInBytes = try cachedFileManager.getLocalCacheSizeInBytes()
			return $0 + cacheSizeInBytes
		}
	}

	func clearCache(for domains: [NSFileProviderDomain]) throws {
		let dbURLs = getDatabaseURLs(for: domains)
		try dbURLs.forEach {
			let database = try DatabaseHelper.getMigratedDB(at: $0)
			let cachedFileManager = CachedFileDBManager(database: database)
			try cachedFileManager.clearCache()
		}
	}

	private func getDatabaseURLs(for domains: [NSFileProviderDomain]) -> [URL] {
		return domains.map {
			let domainURL = documentStorageURLProvider.documentStorageURL.appendingPathComponent($0.pathRelativeToDocumentStorage, isDirectory: true)
			return domainURL.appendingPathComponent("db.sqlite")
		}
	}
}
