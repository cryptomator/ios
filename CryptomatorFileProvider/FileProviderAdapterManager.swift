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

protocol FileProviderAdapterProviding {
	var unlockMonitor: UnlockMonitorType { get }
	func getAdapter(forDomain domain: NSFileProviderDomain, dbPath: URL, delegate: LocalURLProvider?, notificator: FileProviderNotificatorType) throws -> FileProviderAdapterType
}

public class FileProviderAdapterManager: FileProviderAdapterProviding {
	public static let shared = FileProviderAdapterManager()
	public typealias FileProviderAdapterDelegate = LocalURLProvider
	let unlockMonitor: UnlockMonitorType

	private let masterkeyCacheManager: MasterkeyCacheManager
	private let vaultKeepUnlockedHelper: VaultKeepUnlockedHelper
	private let vaultKeepUnlockedSettings: VaultKeepUnlockedSettings
	private let vaultManager: VaultManager
	private let adapterCache: FileProviderAdapterCacheType
	private let notificatorManager: FileProviderNotificatorManagerType
	private let queue = DispatchQueue(label: "FileProviderAdapterManager", qos: .userInitiated)

	convenience init() {
		self.init(masterkeyCacheManager: MasterkeyCacheKeychainManager.shared, vaultKeepUnlockedHelper: VaultKeepUnlockedManager.shared, vaultKeepUnlockedSettings: VaultKeepUnlockedManager.shared, vaultManager: VaultDBManager.shared, adapterCache: FileProviderAdapterCache(), notificatorManager: FileProviderNotificatorManager.shared, unlockMonitor: UnlockMonitor())
	}

	init(masterkeyCacheManager: MasterkeyCacheManager, vaultKeepUnlockedHelper: VaultKeepUnlockedHelper, vaultKeepUnlockedSettings: VaultKeepUnlockedSettings, vaultManager: VaultManager, adapterCache: FileProviderAdapterCacheType, notificatorManager: FileProviderNotificatorManagerType, unlockMonitor: UnlockMonitorType) {
		self.masterkeyCacheManager = masterkeyCacheManager
		self.vaultKeepUnlockedHelper = vaultKeepUnlockedHelper
		self.vaultKeepUnlockedSettings = vaultKeepUnlockedSettings
		self.vaultManager = vaultManager
		self.adapterCache = adapterCache
		self.notificatorManager = notificatorManager
		self.unlockMonitor = unlockMonitor
	}

	public func getAdapter(forDomain domain: NSFileProviderDomain, dbPath: URL, delegate: FileProviderAdapterDelegate?, notificator: FileProviderNotificatorType) throws -> FileProviderAdapterType {
		try queue.sync {
			let cachedAdapterItem = adapterCache.getItem(identifier: domain.identifier)
			let vaultUID = domain.identifier.rawValue
			let adapter: FileProviderAdapterType
			if let cachedAdapter = cachedAdapterItem?.adapter {
				if vaultKeepUnlockedHelper.shouldAutoLockVault(withVaultUID: vaultUID) {
					DDLogDebug("Try to automatically lock \(domain.displayName) - \(domain.identifier)")
					do {
						try gracefulLockVault(with: domain.identifier)
					} catch {
						DDLogDebug("Graceful locking vault \(domain.displayName) - \(domain.identifier) failed with error: \(error)")
					}
					throw unlockMonitor.getUnlockError(forVaultUID: vaultUID)
				}
				adapter = cachedAdapter
			} else {
				DDLogDebug("Try to automatically unlock \(domain.displayName) - \(domain.identifier)")
				let autoUnlockItem = try autoUnlockVault(withVaultUID: vaultUID, dbPath: dbPath, delegate: delegate, notificator: notificator)
				adapterCache.cacheItem(autoUnlockItem, identifier: domain.identifier)
				adapter = autoUnlockItem.adapter
			}
			try vaultKeepUnlockedSettings.setLastUsedDate(Date(), forVaultUID: vaultUID)
			return adapter
		}
	}

	public func unlockVault(with domainIdentifier: NSFileProviderDomainIdentifier, kek: [UInt8], dbPath: URL?, delegate: FileProviderAdapterDelegate?, notificator: FileProviderNotificatorType) throws {
		guard let dbPath = dbPath else {
			return
		}
		let provider = try vaultManager.manualUnlockVault(withUID: domainIdentifier.rawValue, kek: kek)
		let item = try createAdapterCacheItem(cloudProvider: provider, dbPath: dbPath, delegate: delegate, notificator: notificator)
		try vaultKeepUnlockedSettings.setLastUsedDate(Date(), forVaultUID: domainIdentifier.rawValue)
		adapterCache.cacheItem(item, identifier: domainIdentifier)
		let notificator = try notificatorManager.getFileProviderNotificator(for: NSFileProviderDomain(identifier: domainIdentifier, displayName: "", pathRelativeToDocumentStorage: ""))
		notificator.refreshWorkingSet()
	}

	public func forceLockVault(with domainIdentifier: NSFileProviderDomainIdentifier) {
		do {
			try lockVault(with: domainIdentifier)
		} catch {
			DDLogError("Lock vault failed with error: \(error)")
		}
	}

	public func vaultIsUnlocked(domainIdentifier: NSFileProviderDomainIdentifier) -> Bool {
		updateLockStatus(domainIdentifier: domainIdentifier)
		return adapterCache.getItem(identifier: domainIdentifier) != nil
	}

	public func getDomainIdentifiersOfUnlockedVaults() -> [NSFileProviderDomainIdentifier] {
		let cachedIdentifiers = adapterCache.getAllCachedIdentifiers()
		cachedIdentifiers.forEach { updateLockStatus(domainIdentifier: $0) }
		return adapterCache.getAllCachedIdentifiers()
	}

	/**
	 Locks a vault gracefully.

	 A vault will be locked only if it is possible to enable the maintenance mode for the vault belonging to the passed `domainIdentifier`.
	 */
	public func gracefulLockVault(with domainIdentifier: NSFileProviderDomainIdentifier) throws {
		guard let cachedAdapter = adapterCache.getItem(identifier: domainIdentifier) else {
			return
		}
		let maintenanceManager = cachedAdapter.maintenanceManager
		try maintenanceManager.enableMaintenanceMode()
		try lockVault(with: domainIdentifier)
		try maintenanceManager.disableMaintenanceMode()
	}

	private func autoUnlockVault(withVaultUID vaultUID: String, dbPath: URL, delegate: FileProviderAdapterDelegate?, notificator: FileProviderNotificatorType) throws -> AdapterCacheItem {
		guard vaultKeepUnlockedHelper.shouldAutoUnlockVault(withVaultUID: vaultUID) else {
			try masterkeyCacheManager.removeCachedMasterkey(forVaultUID: vaultUID)
			throw unlockMonitor.getUnlockError(forVaultUID: vaultUID)
		}
		guard let cachedMasterkey = try masterkeyCacheManager.getMasterkey(forVaultUID: vaultUID) else {
			throw unlockMonitor.getUnlockError(forVaultUID: vaultUID)
		}
		let provider = try vaultManager.createVaultProvider(withUID: vaultUID, masterkey: cachedMasterkey)
		let adapterCacheItem = try createAdapterCacheItem(cloudProvider: provider, dbPath: dbPath, delegate: delegate, notificator: notificator)
		notificator.refreshWorkingSet()
		return adapterCacheItem
	}

	private func createAdapterCacheItem(cloudProvider: CloudProvider, dbPath: URL, delegate: FileProviderAdapterDelegate?, notificator: FileProviderNotificatorType) throws -> AdapterCacheItem {
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
		let workingSetObserver = WorkingSetObserver(database: database, notificator: notificator, uploadTaskManager: uploadTaskManager, cachedFileManager: cachedFileManager)
		workingSetObserver.startObservation()
		return AdapterCacheItem(adapter: adapter, maintenanceManager: maintenanceManager, workingSetObserver: workingSetObserver)
	}

	/**
	 Locks the vault.

	 Locks the vault associated with the `domainIdentifier` by removing the adapter and, if present, the cached masterkey from the cache.
	 Additionally an update of the working set is triggered to invalidate the working set cache.
	 */
	private func lockVault(with domainIdentifier: NSFileProviderDomainIdentifier) throws {
		adapterCache.removeItem(identifier: domainIdentifier)
		try masterkeyCacheManager.removeCachedMasterkey(forVaultUID: domainIdentifier.rawValue)
		let notificator = try notificatorManager.getFileProviderNotificator(for: NSFileProviderDomain(identifier: domainIdentifier, displayName: "", pathRelativeToDocumentStorage: ""))
		notificator.refreshWorkingSet()
	}

	private func updateLockStatus(domainIdentifier: NSFileProviderDomainIdentifier) {
		if vaultKeepUnlockedHelper.shouldAutoLockVault(withVaultUID: domainIdentifier.rawValue) {
			do {
				try gracefulLockVault(with: domainIdentifier)
			} catch {
				DDLogDebug("Graceful locking vault (\(domainIdentifier.rawValue)) failed with error: \(error)")
			}
		}
	}
}

struct AdapterCacheItem {
	let adapter: FileProviderAdapterType
	let maintenanceManager: MaintenanceManager
	let workingSetObserver: WorkingSetObserving
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
