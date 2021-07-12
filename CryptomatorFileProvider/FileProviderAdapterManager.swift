//
//  FileProviderAdapterManager.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 09.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import FileProvider
import Foundation
import Promises

public enum FileProviderAdapterManager {
	private static let queue = DispatchQueue(label: "FileProviderAdapterManager")
	private static var cachedAdapters = [NSFileProviderDomainIdentifier: FileProviderAdapter]()
	public typealias FileProviderAdapterDelegate = LocalURLProvider

	public static func getAdapter(for domain: NSFileProviderDomain, dbPath: URL, delegate: FileProviderAdapterDelegate?, notificator: FileProviderNotificator?) throws -> FileProviderAdapter {
		try queue.sync(flags: .barrier) {
			if let cachedAdapter = cachedAdapters[domain.identifier] {
				return cachedAdapter
			}
			let adapter: FileProviderAdapter

			let database = try DatabaseHelper.getMigratedDB(at: dbPath)
			let itemMetadataManager = ItemMetadataDBManager(with: database)
			let cachedFileManager = CachedFileDBManager(with: database)
			let uploadTaskManager = UploadTaskDBManager(with: database)
			let reparentTaskManager = try ReparentTaskDBManager(with: database)
			let deletionTaskManager = try DeletionTaskDBManager(with: database)
			let provider = try VaultDBManager.shared.getDecorator(forVaultUID: domain.identifier.rawValue)
			adapter = FileProviderAdapter(uploadTaskManager: uploadTaskManager, cachedFileManager: cachedFileManager, itemMetadataManager: itemMetadataManager, reparentTaskManager: reparentTaskManager, deletionTaskManager: deletionTaskManager, scheduler: WorkflowScheduler(maxParallelUploads: 1, maxParallelDownloads: 2), provider: provider, notificator: notificator, localURLProvider: delegate)

			cachedAdapters[domain.identifier] = adapter
			return adapter
		}
	}

	public static func unlockVault(for domain: NSFileProviderDomain?, kek: [UInt8], dbPath: URL?, delegate: FileProviderAdapterDelegate?, notificator: FileProviderNotificator?) throws {
		guard let domain = domain, let dbPath = dbPath else {
			return
		}
		let provider = try VaultDBManager.shared.manualUnlockVault(withUID: domain.identifier.rawValue, kek: kek)
		let database = try DatabaseHelper.getMigratedDB(at: dbPath)
		let itemMetadataManager = ItemMetadataDBManager(with: database)
		let cachedFileManager = CachedFileDBManager(with: database)
		let uploadTaskManager = UploadTaskDBManager(with: database)
		let reparentTaskManager = try ReparentTaskDBManager(with: database)
		let deletionTaskManager = try DeletionTaskDBManager(with: database)
		let adapter = FileProviderAdapter(uploadTaskManager: uploadTaskManager, cachedFileManager: cachedFileManager, itemMetadataManager: itemMetadataManager, reparentTaskManager: reparentTaskManager, deletionTaskManager: deletionTaskManager, scheduler: WorkflowScheduler(maxParallelUploads: 1, maxParallelDownloads: 2), provider: provider, notificator: notificator, localURLProvider: delegate)
		queue.sync(flags: .barrier) {
			cachedAdapters[domain.identifier] = adapter
		}
	}
}
