//
//  FileProviderAdapterManager.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 09.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import FileProvider
import Foundation
import GRDB
import Promises

public enum FileProviderAdapterManagerError: Error {
	case cachedAdapterNotFound
}

public class FileProviderAdapterManager {
	public static let shared = FileProviderAdapterManager()
	public typealias FileProviderAdapterDelegate = LocalURLProvider
	public let semaphore = BiometricalUnlockSemaphore()

	private let masterkeyCacheManager: MasterkeyCacheManager
	private let vaultAutoLockingHelper: VaultAutoLockingHelper
	private let vaultAutoLockingSettings: VaultAutoLockingSettings
	private let vaultManager: VaultManager
	private let adapterCache: FileProviderAdapterCacheType

	convenience init() {
		self.init(masterkeyCacheManager: MasterkeyCacheKeychainManager.shared, vaultAutoLockingHelper: VaultAutoLockingManager.shared, vaultAutoLockingSettings: VaultAutoLockingManager.shared, vaultManager: VaultDBManager.shared, adapterCache: FileProviderAdapterCache())
	}

	init(masterkeyCacheManager: MasterkeyCacheManager, vaultAutoLockingHelper: VaultAutoLockingHelper, vaultAutoLockingSettings: VaultAutoLockingSettings, vaultManager: VaultManager, adapterCache: FileProviderAdapterCacheType) {
		self.masterkeyCacheManager = masterkeyCacheManager
		self.vaultAutoLockingHelper = vaultAutoLockingHelper
		self.vaultAutoLockingSettings = vaultAutoLockingSettings
		self.vaultManager = vaultManager
		self.adapterCache = adapterCache
	}

	public func getAdapter(forDomain domain: NSFileProviderDomain, dbPath: URL, delegate: FileProviderAdapterDelegate?, notificator: FileProviderNotificator?) throws -> FileProviderAdapterType {
		let cachedAdapterItem = adapterCache.getItem(identifier: domain.identifier)
		let vaultUID = domain.identifier.rawValue
		let adapter: FileProviderAdapterType
		if let cachedAdapter = cachedAdapterItem?.adapter {
			if vaultAutoLockingHelper.shouldAutoLockVault(withVaultUID: vaultUID) {
				DDLogDebug("Try to automatically lock \(domain.displayName) - \(domain.identifier)")
				gracefulLockVault(with: domain.identifier)
				throw FileProviderAdapterManagerError.cachedAdapterNotFound
			}
			adapter = cachedAdapter
		} else {
			DDLogDebug("Try to automatically unlock \(domain.displayName) - \(domain.identifier)")
			let autoUnlockItem = try autoUnlockVault(withVaultUID: vaultUID, dbPath: dbPath, delegate: delegate, notificator: notificator)
			adapterCache.cacheItem(autoUnlockItem, identifier: domain.identifier)
			adapter = autoUnlockItem.adapter
		}
		try vaultAutoLockingSettings.setLastUsedDate(Date(), forVaultUID: vaultUID)
		return adapter
	}

	public func unlockVault(with domainIdentifier: NSFileProviderDomainIdentifier, kek: [UInt8], dbPath: URL?, delegate: FileProviderAdapterDelegate?, notificator: FileProviderNotificator?) throws {
		guard let dbPath = dbPath else {
			return
		}
		let provider = try vaultManager.manualUnlockVault(withUID: domainIdentifier.rawValue, kek: kek)
		let item = try createAdapterCacheItem(cloudProvider: provider, dbPath: dbPath, delegate: delegate, notificator: notificator)
		try vaultAutoLockingSettings.setLastUsedDate(Date(), forVaultUID: domainIdentifier.rawValue)
		adapterCache.cacheItem(item, identifier: domainIdentifier)
	}

	public func lockVault(with domainIdentifier: NSFileProviderDomainIdentifier) {
		adapterCache.removeItem(identifier: domainIdentifier)
		do {
			try masterkeyCacheManager.removeCachedMasterkey(forVaultUID: domainIdentifier.rawValue)
		} catch {
			DDLogError("Lock vault failed with error: \(error)")
		}
	}

	public func vaultIsUnlocked(domainIdentifier: NSFileProviderDomainIdentifier) -> Bool {
		return adapterCache.getItem(identifier: domainIdentifier) != nil
	}

	public func getDomainIdentifiersOfUnlockedVaults() -> [NSFileProviderDomainIdentifier] {
		return adapterCache.getAllCachedIdentifiers()
	}

	/**
	 Locks a vault gracefully.

	 A vault will be locked only if it is possible to enable the maintenance mode for the vault belonging to the passed `domainIdentifier`.
	 */
	private func gracefulLockVault(with domainIdentifier: NSFileProviderDomainIdentifier) {
		guard let cachedAdapter = adapterCache.getItem(identifier: domainIdentifier) else {
			return
		}
		let maintenanceManager = cachedAdapter.maintenanceManager
		do {
			try masterkeyCacheManager.removeCachedMasterkey(forVaultUID: domainIdentifier.rawValue)
			try maintenanceManager.enableMaintenanceMode()
			adapterCache.removeItem(identifier: domainIdentifier)
			try maintenanceManager.disableMaintenanceMode()
		} catch {
			return
		}
	}

	private func autoUnlockVault(withVaultUID vaultUID: String, dbPath: URL, delegate: FileProviderAdapterDelegate?, notificator: FileProviderNotificator?) throws -> AdapterCacheItem {
		guard vaultAutoLockingHelper.shouldAutoUnlockVault(withVaultUID: vaultUID) else {
			try masterkeyCacheManager.removeCachedMasterkey(forVaultUID: vaultUID)
			throw FileProviderAdapterManagerError.cachedAdapterNotFound
		}
		guard let cachedMasterkey = try masterkeyCacheManager.getMasterkey(forVaultUID: vaultUID) else {
			throw FileProviderAdapterManagerError.cachedAdapterNotFound
		}
		let provider = try vaultManager.createVaultProvider(withUID: vaultUID, masterkey: cachedMasterkey)
		return try createAdapterCacheItem(cloudProvider: provider, dbPath: dbPath, delegate: delegate, notificator: notificator)
	}

	private func createAdapterCacheItem(cloudProvider: CloudProvider, dbPath: URL, delegate: FileProviderAdapterDelegate?, notificator: FileProviderNotificator?) throws -> AdapterCacheItem {
		let database = try DatabaseHelper.getMigratedDB(at: dbPath)
		let itemMetadataManager = ItemMetadataDBManager(database: database)
		let cachedFileManager = CachedFileDBManager(database: database)
		let uploadTaskManager = UploadTaskDBManager(database: database)
		let reparentTaskManager = try ReparentTaskDBManager(database: database)
		let deletionTaskManager = try DeletionTaskDBManager(database: database)
		let itemEnumerationTaskManager = try ItemEnumerationTaskDBManager(database: database)
		let downloadTaskManager = try DownloadTaskDBManager(database: database)
		let maintenanceManager = MaintenanceDBManager(database: database)
		let adapter = FileProviderAdapter(uploadTaskManager: uploadTaskManager,
		                                  cachedFileManager: cachedFileManager,
		                                  itemMetadataManager: itemMetadataManager,
		                                  reparentTaskManager: reparentTaskManager,
		                                  deletionTaskManager: deletionTaskManager,
		                                  itemEnumerationTaskManager: itemEnumerationTaskManager,
		                                  downloadTaskManager: downloadTaskManager,
		                                  scheduler: WorkflowScheduler(maxParallelUploads: 1, maxParallelDownloads: 2),
		                                  provider: cloudProvider,
		                                  notificator: notificator,
		                                  localURLProvider: delegate)
		return AdapterCacheItem(adapter: adapter, maintenanceManager: maintenanceManager)
	}
}

struct AdapterCacheItem {
	let adapter: FileProviderAdapterType
	let maintenanceManager: MaintenanceManager
}

protocol FileProviderAdapterCacheType {
	func cacheItem(_ item: AdapterCacheItem, identifier: NSFileProviderDomainIdentifier)
	func removeItem(identifier: NSFileProviderDomainIdentifier)
	func getItem(identifier: NSFileProviderDomainIdentifier) -> AdapterCacheItem?
	func getAllCachedIdentifiers() -> [NSFileProviderDomainIdentifier]
}

class FileProviderAdapterCache: FileProviderAdapterCacheType {
	private let queue = DispatchQueue(label: "FileProviderAdapterManager")
	private var cachedAdapters = [NSFileProviderDomainIdentifier: AdapterCacheItem]()

	func cacheItem(_ item: AdapterCacheItem, identifier: NSFileProviderDomainIdentifier) {
		queue.sync(flags: .barrier) {
			cachedAdapters[identifier] = item
		}
	}

	func removeItem(identifier: NSFileProviderDomainIdentifier) {
		queue.sync(flags: .barrier) {
			cachedAdapters[identifier] = nil
		}
	}

	func getItem(identifier: NSFileProviderDomainIdentifier) -> AdapterCacheItem? {
		queue.sync {
			return cachedAdapters[identifier]
		}
	}

	func getAllCachedIdentifiers() -> [NSFileProviderDomainIdentifier] {
		queue.sync {
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
