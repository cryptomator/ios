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
import Dependencies
import FileProvider
import Foundation
import GRDB
import Promises

protocol FileProviderAdapterProviding {
	var unlockMonitor: UnlockMonitorType { get }
	func getAdapter(forDomain domain: NSFileProviderDomain, dbPath: URL, delegate: LocalURLProviderType, notificator: FileProviderNotificatorType, taskRegistrator: SessionTaskRegistrator) throws -> FileProviderAdapterType
}

public class FileProviderAdapterManager: FileProviderAdapterProviding {
	public static let shared = FileProviderAdapterManager()
	public typealias FileProviderAdapterDelegate = LocalURLProviderType
	let unlockMonitor: UnlockMonitorType

	private let masterkeyCacheManager: MasterkeyCacheManager
	private let vaultKeepUnlockedHelper: VaultKeepUnlockedHelper
	private let vaultKeepUnlockedSettings: VaultKeepUnlockedSettings
	private let vaultManager: VaultManager
	private let adapterCache: FileProviderAdapterCacheType
	private let notificatorManager: FileProviderNotificatorManagerType
	private let queue = DispatchQueue(label: "FileProviderAdapterManager", qos: .userInitiated)
	private let providerIdentifier: String
	@Dependency(\.permissionProvider) private var permissionProvider

	convenience init() {
		self.init(masterkeyCacheManager: MasterkeyCacheKeychainManager.shared,
		          vaultKeepUnlockedHelper: VaultKeepUnlockedManager.shared,
		          vaultKeepUnlockedSettings: VaultKeepUnlockedManager.shared,
		          vaultManager: VaultDBManager.shared,
		          adapterCache: FileProviderAdapterCache(),
		          notificatorManager: FileProviderNotificatorManager.shared,
		          unlockMonitor: UnlockMonitor(),
		          providerIdentifier: NSFileProviderManager.default.providerIdentifier)
	}

	init(masterkeyCacheManager: MasterkeyCacheManager,
	     vaultKeepUnlockedHelper: VaultKeepUnlockedHelper,
	     vaultKeepUnlockedSettings: VaultKeepUnlockedSettings,
	     vaultManager: VaultManager,
	     adapterCache: FileProviderAdapterCacheType,
	     notificatorManager: FileProviderNotificatorManagerType,
	     unlockMonitor: UnlockMonitorType,
	     providerIdentifier: String) {
		self.masterkeyCacheManager = masterkeyCacheManager
		self.vaultKeepUnlockedHelper = vaultKeepUnlockedHelper
		self.vaultKeepUnlockedSettings = vaultKeepUnlockedSettings
		self.vaultManager = vaultManager
		self.adapterCache = adapterCache
		self.notificatorManager = notificatorManager
		self.unlockMonitor = unlockMonitor
		self.providerIdentifier = providerIdentifier
	}

	public func getAdapter(forDomain domain: NSFileProviderDomain, dbPath: URL, delegate: FileProviderAdapterDelegate, notificator: FileProviderNotificatorType, taskRegistrator: SessionTaskRegistrator) throws -> FileProviderAdapterType {
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
				let autoUnlockItem = try autoUnlockVault(withVaultUID: vaultUID, domainIdentifier: domain.identifier, dbPath: dbPath, delegate: delegate, notificator: notificator, taskRegistrator: taskRegistrator)
				adapterCache.cacheItem(autoUnlockItem, identifier: domain.identifier)
				adapter = autoUnlockItem.adapter
			}
			try vaultKeepUnlockedSettings.setLastUsedDate(Date(), forVaultUID: vaultUID)
			return adapter
		}
	}

	// swiftlint:disable:next function_parameter_count
	public func unlockVault(with domainIdentifier: NSFileProviderDomainIdentifier, kek: [UInt8], dbPath: URL?, delegate: FileProviderAdapterDelegate, notificator: FileProviderNotificatorType, taskRegistrator: SessionTaskRegistrator) throws {
		guard let dbPath = dbPath else {
			return
		}
		let provider = try vaultManager.manualUnlockVault(withUID: domainIdentifier.rawValue, kek: kek)
		try unlockVaultPostProcessing(provider: provider,
		                              domainIdentifier: domainIdentifier,
		                              dbPath: dbPath,
		                              delegate: delegate,
		                              notificator: notificator,
		                              taskRegistrator: taskRegistrator)
	}

	// swiftlint:disable:next function_parameter_count
	public func unlockVault(with domainIdentifier: NSFileProviderDomainIdentifier, rawKey: [UInt8], dbPath: URL?, delegate: FileProviderAdapterDelegate, notificator: FileProviderNotificatorType, taskRegistrator: SessionTaskRegistrator) throws {
		guard let dbPath = dbPath else {
			return
		}
		let provider = try vaultManager.manualUnlockVault(withUID: domainIdentifier.rawValue, rawKey: rawKey)
		try unlockVaultPostProcessing(provider: provider,
		                              domainIdentifier: domainIdentifier,
		                              dbPath: dbPath,
		                              delegate: delegate,
		                              notificator: notificator,
		                              taskRegistrator: taskRegistrator)
	}

	// swiftlint:disable:next function_parameter_count
	func unlockVaultPostProcessing(provider: CloudProvider, domainIdentifier: NSFileProviderDomainIdentifier, dbPath: URL, delegate: FileProviderAdapterDelegate, notificator: FileProviderNotificatorType, taskRegistrator: SessionTaskRegistrator) throws {
		let item = try createAdapterCacheItem(domainIdentifier: domainIdentifier, cloudProvider: provider, dbPath: dbPath, delegate: delegate, notificator: notificator, taskRegistrator: taskRegistrator)
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

	// swiftlint:disable:next function_parameter_count
	private func autoUnlockVault(withVaultUID vaultUID: String, domainIdentifier: NSFileProviderDomainIdentifier, dbPath: URL, delegate: FileProviderAdapterDelegate, notificator: FileProviderNotificatorType, taskRegistrator: SessionTaskRegistrator) throws -> AdapterCacheItem {
		guard vaultKeepUnlockedHelper.shouldAutoUnlockVault(withVaultUID: vaultUID) else {
			try masterkeyCacheManager.removeCachedMasterkey(forVaultUID: vaultUID)
			throw unlockMonitor.getUnlockError(forVaultUID: vaultUID)
		}
		guard let cachedMasterkey = try masterkeyCacheManager.getMasterkey(forVaultUID: vaultUID) else {
			throw unlockMonitor.getUnlockError(forVaultUID: vaultUID)
		}
		let provider = try vaultManager.createVaultProvider(withUID: vaultUID, masterkey: cachedMasterkey)
		let adapterCacheItem = try createAdapterCacheItem(domainIdentifier: domainIdentifier, cloudProvider: provider, dbPath: dbPath, delegate: delegate, notificator: notificator, taskRegistrator: taskRegistrator)
		notificator.refreshWorkingSet()
		return adapterCacheItem
	}

	// swiftlint:disable:next function_parameter_count
	private func createAdapterCacheItem(domainIdentifier: NSFileProviderDomainIdentifier, cloudProvider: CloudProvider, dbPath: URL, delegate: FileProviderAdapterDelegate, notificator: FileProviderNotificatorType, taskRegistrator: SessionTaskRegistrator) throws -> AdapterCacheItem {
		let fileCoordinator = NSFileCoordinator()
		fileCoordinator.purposeIdentifier = providerIdentifier
		let database = try DatabaseHelper.default.getMigratedDB(at: dbPath, purposeIdentifier: providerIdentifier)
		let itemMetadataManager = ItemMetadataDBManager(database: database)
		let cachedFileManager = CachedFileDBManager(database: database,
		                                            fileManagerHelper: .init(fileCoordinator: fileCoordinator))
		let uploadTaskManager = UploadTaskDBManager(database: database)
		let reparentTaskManager = try ReparentTaskDBManager(database: database)
		let deletionTaskManager = try DeletionTaskDBManager(database: database)
		let itemEnumerationTaskManager = try ItemEnumerationTaskDBManager(database: database)
		let downloadTaskManager = try DownloadTaskDBManager(database: database)
		let maintenanceManager = MaintenanceDBManager(database: database)

		let adapter = FileProviderAdapter(domainIdentifier: domainIdentifier,
		                                  uploadTaskManager: uploadTaskManager,
		                                  cachedFileManager: cachedFileManager,
		                                  itemMetadataManager: itemMetadataManager,
		                                  reparentTaskManager: reparentTaskManager,
		                                  deletionTaskManager: deletionTaskManager,
		                                  itemEnumerationTaskManager: itemEnumerationTaskManager,
		                                  downloadTaskManager: downloadTaskManager,
		                                  scheduler: WorkflowScheduler(maxParallelUploads: 1, maxParallelDownloads: 2),
		                                  provider: cloudProvider,
		                                  coordinator: fileCoordinator,
		                                  notificator: notificator,
		                                  localURLProvider: delegate,
		                                  taskRegistrator: taskRegistrator)

		let workingSetObserver = WorkingSetObserver(domainIdentifier: domainIdentifier,
		                                            database: database,
		                                            notificator: notificator,
		                                            uploadTaskManager: uploadTaskManager,
		                                            cachedFileManager: cachedFileManager)
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
