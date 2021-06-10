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

	public static func getAdapter(for domain: NSFileProviderDomain, with manager: NSFileProviderManager, dbPath: URL, delegate: FileProviderAdapterDelegate?, notificator: FileProviderNotificator?) -> Promise<FileProviderAdapter> {
		return Promise<FileProviderAdapter> { fulfill, reject in
			queue.async(flags: .barrier) {
				if let cachedAdapter = cachedAdapters[domain.identifier] {
					fulfill(cachedAdapter)
					return
				}
				let adapter: FileProviderAdapter
				do {
					let database = try DatabaseHelper.getMigratedDB(at: dbPath)
					let itemMetadataManager = ItemMetadataDBManager(with: database)
					let cachedFileManager = CachedFileDBManager(with: database)
					let uploadTaskManager = UploadTaskDBManager(with: database)
					let reparentTaskManager = try ReparentTaskDBManager(with: database)
					let deletionTaskManager = try DeletionTaskDBManager(with: database)
					let provider = try VaultManager.shared.getDecorator(forVaultUID: domain.identifier.rawValue)
					adapter = FileProviderAdapter(uploadTaskManager: uploadTaskManager, cachedFileManager: cachedFileManager, itemMetadataManager: itemMetadataManager, reparentTaskManager: reparentTaskManager, deletionTaskManager: deletionTaskManager, scheduler: WorkflowScheduler(maxParallelUploads: 1, maxParallelDownloads: 2), provider: provider, notificator: notificator, localURLProvider: delegate)
				} catch {
					reject(error)
					return
				}
				cachedAdapters[domain.identifier] = adapter
				fulfill(adapter)
			}
		}
	}
}
