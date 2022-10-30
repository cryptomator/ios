//
//  CachedFileManagerFactory.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 10.05.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
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

		let manager = NSFileProviderManager(for: domain)
		let fileCoordinator = NSFileCoordinator()
		if let providerIdentifier = manager?.providerIdentifier {
			fileCoordinator.purposeIdentifier = providerIdentifier
		} else {
			DDLogError("Failed to get providerIdentifier for domain \(domain.identifier.rawValue)")
		}
		let database = try DatabaseHelper.default.getMigratedDB(at: databaseURL, fileCoordinator: fileCoordinator)
		return CachedFileDBManager(database: database,
		                           fileManagerHelper: .init(fileCoordinator: fileCoordinator))
	}
}
