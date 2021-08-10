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
	public static let semaphore = BiometricalUnlockSemaphore()

	public static func getAdapter(for domain: NSFileProviderDomain, dbPath: URL, delegate: FileProviderAdapterDelegate?, notificator: FileProviderNotificator?) throws -> FileProviderAdapter {
		return try queue.sync(flags: .barrier) {
			if let cachedAdapter = cachedAdapters[domain.identifier] {
				return cachedAdapter
			} else {
				throw VaultPasswordManagerError.passwordNotFound
			}
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

	public static func lockVault(with domainIdentifier: NSFileProviderDomainIdentifier) {
		queue.sync(flags: .barrier) {
			cachedAdapters[domainIdentifier] = nil
		}
	}

	public static func vaultIsUnLocked(domainIdentifier: NSFileProviderDomainIdentifier) -> Bool {
		queue.sync(flags: .barrier) {
			return cachedAdapters[domainIdentifier] != nil
		}
	}

	public static func getDomainIdentifiersOfUnlockedVaults() -> [NSFileProviderDomainIdentifier] {
		queue.sync(flags: .barrier) {
			return cachedAdapters.map { $0.key }
		}
	}
}

public class BiometricalUnlockSemaphore {
	public var runningBiometricalUnlock = false
	private let semaphore = DispatchSemaphore(value: 0)

	public func wait() {
		if runningBiometricalUnlock {
			semaphore.wait()
		}
	}

	public func signal() {
		semaphore.signal()
		runningBiometricalUnlock = false
	}
}
