//
//  CachedFileManagerFactory.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 10.05.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import FileProvider
import Foundation

protocol CachedFileManagerFactory {
	func createCachedFileManager(for domain: NSFileProviderDomain) throws -> CachedFileManager
}

struct CachedFileDBManagerFactory: CachedFileManagerFactory {
	static let shared = CachedFileDBManagerFactory()
	private let databaseURLProvider: DatabaseURLProvider

	init(databaseURLProvider: DatabaseURLProvider = .shared) {
		self.databaseURLProvider = databaseURLProvider
	}

	func createCachedFileManager(for domain: NSFileProviderDomain) throws -> CachedFileManager {
		let databaseURL = databaseURLProvider.getDatabaseURL(for: domain)
		let database = try DatabaseHelper.getMigratedDB(at: databaseURL)
		return CachedFileDBManager(database: database)
	}
}
