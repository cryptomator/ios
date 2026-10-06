//
//  FileProviderAdapterManagerTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 11.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import FileProvider
import Promises
import XCTest
@testable import CryptomatorCommonCore
@testable import CryptomatorCryptoLib
@testable import CryptomatorFileProvider

class FileProviderAdapterManagerTests: XCTestCase {
	let providerIdentifier = UUID().uuidString
	let vaultUID = "VaultUID-12345"
	lazy var domain = NSFileProviderDomain(vaultUID: vaultUID, displayName: "TestVault")
	var fileProviderAdapterManager: FileProviderAdapterManager!
	var tmpURL: URL!
	var dbPath: URL!
	var vaultManagerMock: VaultManagerMock!
	var adapterCacheMock: FileProviderAdapterCacheTypeMock!
	var masterkeyCacheManagerMock: MasterkeyCacheManagerMock!
	var vaultKeepUnlockedHelperMock: VaultKeepUnlockedHelperMock!
	var vaultKeepUnlockedSettingsMock: VaultKeepUnlockedSettingsMock!
	var notificatorManagerMock: FileProviderNotificatorManagerTypeMock!
	var workingSetObservationMock: WorkingSetObservingMock!
	var fileProviderNotificatorMock: FileProviderNotificatorTypeMock!
	var localURLProviderMock: LocalURLProviderMock!
	var taskRegistratorMock: SessionTaskRegistratorMock!
	private enum ErrorMock: Error {
		case test
	}

	#warning("TODO: Replace unlockMonitor with mock")
	override func setUpWithError() throws {
		masterkeyCacheManagerMock = MasterkeyCacheManagerMock()
		vaultKeepUnlockedHelperMock = VaultKeepUnlockedHelperMock()
		vaultKeepUnlockedSettingsMock = VaultKeepUnlockedSettingsMock()
		vaultManagerMock = VaultManagerMock()
		adapterCacheMock = FileProviderAdapterCacheTypeMock()
		notificatorManagerMock = FileProviderNotificatorManagerTypeMock()
		workingSetObservationMock = WorkingSetObservingMock()
		fileProviderNotificatorMock = FileProviderNotificatorTypeMock()
		localURLProviderMock = LocalURLProviderMock()
		taskRegistratorMock = SessionTaskRegistratorMock()
		fileProviderAdapterManager = FileProviderAdapterManager(masterkeyCacheManager: masterkeyCacheManagerMock, vaultKeepUnlockedHelper: vaultKeepUnlockedHelperMock, vaultKeepUnlockedSettings: vaultKeepUnlockedSettingsMock, vaultManager: vaultManagerMock, adapterCache: adapterCacheMock, notificatorManager: notificatorManagerMock, unlockMonitor: UnlockMonitor(), providerIdentifier: providerIdentifier)
		tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		dbPath = tmpURL.appendingPathComponent("db.sqlite", isDirectory: false)
		try FileManager.default.createDirectory(at: tmpURL, withIntermediateDirectories: false)
	}

	override func tearDownWithError() throws {
		fileProviderAdapterManager = nil
		adapterCacheMock = nil
		try FileManager.default.removeItem(at: tmpURL)
	}

	// MARK: Get Adapter - Auto Unlock

	func testGetAdapterNotCachedNoAutoUnlock() throws {
		vaultKeepUnlockedHelperMock.shouldAutoUnlockVaultWithVaultUIDReturnValue = false
		XCTAssertThrowsError(try fileProviderAdapterManager.getAdapter(forDomain: domain, dbPath: dbPath, delegate: localURLProviderMock, notificator: fileProviderNotificatorMock, taskRegistrator: taskRegistratorMock)) { error in
			XCTAssertEqual(.defaultLock, error as? UnlockMonitorError)
		}
		XCTAssertEqual([vaultUID], vaultKeepUnlockedHelperMock.shouldAutoUnlockVaultWithVaultUIDReceivedInvocations)
		XCTAssertEqual([vaultUID], masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDReceivedInvocations)
	}

	func testGetAdapterNotCachedAutoUnlock() throws {
		vaultKeepUnlockedHelperMock.shouldAutoUnlockVaultWithVaultUIDReturnValue = true
		vaultManagerMock.createVaultProviderWithUIDMasterkeyReturnValue = CustomCloudProviderMock()
		let masterkey = Masterkey.createFromRaw(aesMasterKey: [UInt8](repeating: 0x55, count: 32), macMasterKey: [UInt8](repeating: 0x77, count: 32))
		masterkeyCacheManagerMock.getMasterkeyForVaultUIDReturnValue = masterkey
		let adapter = try fileProviderAdapterManager.getAdapter(forDomain: domain, dbPath: dbPath, delegate: localURLProviderMock, notificator: fileProviderNotificatorMock, taskRegistrator: taskRegistratorMock)
		XCTAssertEqual([vaultUID], vaultKeepUnlockedHelperMock.shouldAutoUnlockVaultWithVaultUIDReceivedInvocations)
		XCTAssertFalse(masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDCalled)

		XCTAssertEqual(1, adapterCacheMock.cacheItemIdentifierCallsCount)
		let cacheItemIdentifierReceivedArguments = try XCTUnwrap(adapterCacheMock.cacheItemIdentifierReceivedArguments)
		XCTAssertEqual(domain.identifier, cacheItemIdentifierReceivedArguments.identifier)
		XCTAssert(cacheItemIdentifierReceivedArguments.item.adapter === adapter)

		XCTAssertEqual(1, vaultKeepUnlockedSettingsMock.setLastUsedDateForVaultUIDCallsCount)
		XCTAssertEqual(vaultUID, vaultKeepUnlockedSettingsMock.setLastUsedDateForVaultUIDReceivedArguments?.vaultUID)
		try assertLastUsedDateSet()
	}

	func testGetAdapterNotCachedAutoUnlockVaultManagerFailed() throws {
		vaultKeepUnlockedHelperMock.shouldAutoUnlockVaultWithVaultUIDReturnValue = true
		vaultManagerMock.createVaultProviderWithUIDMasterkeyThrowableError = ErrorMock.test
		let masterkey = Masterkey.createFromRaw(aesMasterKey: [UInt8](repeating: 0x55, count: 32), macMasterKey: [UInt8](repeating: 0x77, count: 32))
		masterkeyCacheManagerMock.getMasterkeyForVaultUIDReturnValue = masterkey
		XCTAssertThrowsError(try fileProviderAdapterManager.getAdapter(forDomain: domain, dbPath: dbPath, delegate: localURLProviderMock, notificator: fileProviderNotificatorMock, taskRegistrator: taskRegistratorMock)) { error in
			XCTAssertEqual(.test, error as? ErrorMock)
		}
		XCTAssertEqual([vaultUID], vaultKeepUnlockedHelperMock.shouldAutoUnlockVaultWithVaultUIDReceivedInvocations)
		XCTAssertFalse(masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDCalled)
		XCTAssertFalse(adapterCacheMock.cacheItemIdentifierCalled)
		XCTAssertFalse(vaultKeepUnlockedSettingsMock.setLastUsedDateForVaultUIDCalled)
	}

	func testGetAdapterNotCachedAutoUnlockMissingMasterkey() throws {
		vaultKeepUnlockedHelperMock.shouldAutoUnlockVaultWithVaultUIDReturnValue = true
		masterkeyCacheManagerMock.getMasterkeyForVaultUIDReturnValue = nil
		XCTAssertThrowsError(try fileProviderAdapterManager.getAdapter(forDomain: domain, dbPath: dbPath, delegate: localURLProviderMock, notificator: fileProviderNotificatorMock, taskRegistrator: taskRegistratorMock)) { error in
			XCTAssertEqual(.defaultLock, error as? UnlockMonitorError)
		}
		XCTAssertEqual([vaultUID], vaultKeepUnlockedHelperMock.shouldAutoUnlockVaultWithVaultUIDReceivedInvocations)
		XCTAssertFalse(masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDCalled)
		XCTAssertFalse(adapterCacheMock.cacheItemIdentifierCalled)
		XCTAssertFalse(vaultKeepUnlockedSettingsMock.setLastUsedDateForVaultUIDCalled)
	}

	// MARK: Get Adapter - Cached

	func testGetAdapterCachedNoAutoLock() throws {
		vaultKeepUnlockedHelperMock.shouldAutoLockVaultWithVaultUIDReturnValue = false
		let fileProviderAdapterStub = FileProviderAdapterTypeMock()
		adapterCacheMock.getItemIdentifierReturnValue = AdapterCacheItem(adapter: fileProviderAdapterStub, maintenanceManager: MaintenanceManagerMock(), workingSetObserver: workingSetObservationMock)
		let adapter = try fileProviderAdapterManager.getAdapter(forDomain: domain, dbPath: dbPath, delegate: localURLProviderMock, notificator: fileProviderNotificatorMock, taskRegistrator: taskRegistratorMock)
		XCTAssert(adapter === fileProviderAdapterStub)
		try assertLastUsedDateSet()
	}

	func testGetAdapterCachedShouldAutoLock() throws {
		vaultKeepUnlockedHelperMock.shouldAutoLockVaultWithVaultUIDReturnValue = true
		let fileProviderAdapterStub = FileProviderAdapterTypeMock()
		let maintenanceManagerMock = MaintenanceManagerMock()
		notificatorManagerMock.getFileProviderNotificatorForReturnValue = fileProviderNotificatorMock
		adapterCacheMock.getItemIdentifierReturnValue = AdapterCacheItem(adapter: fileProviderAdapterStub, maintenanceManager: maintenanceManagerMock, workingSetObserver: workingSetObservationMock)
		XCTAssertThrowsError(try fileProviderAdapterManager.getAdapter(forDomain: domain, dbPath: dbPath, delegate: localURLProviderMock, notificator: fileProviderNotificatorMock, taskRegistrator: taskRegistratorMock)) { error in
			XCTAssertEqual(.defaultLock, error as? UnlockMonitorError)
		}
		XCTAssertEqual(1, maintenanceManagerMock.enableMaintenanceModeCallsCount)
		XCTAssertEqual(1, maintenanceManagerMock.disableMaintenanceModeCallsCount)
		XCTAssertEqual([domain.identifier], adapterCacheMock.removeItemIdentifierReceivedInvocations)
		XCTAssertEqual([vaultUID], masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDReceivedInvocations)
	}

	func testGetAdapterCachedShouldAutoLockEnableMaintenanceModeFailed() throws {
		vaultKeepUnlockedHelperMock.shouldAutoLockVaultWithVaultUIDReturnValue = true
		let fileProviderAdapterStub = FileProviderAdapterTypeMock()
		let maintenanceManagerMock = MaintenanceManagerMock()
		maintenanceManagerMock.enableMaintenanceModeThrowableError = ErrorMock.test
		notificatorManagerMock.getFileProviderNotificatorForReturnValue = fileProviderNotificatorMock
		adapterCacheMock.getItemIdentifierReturnValue = AdapterCacheItem(adapter: fileProviderAdapterStub, maintenanceManager: maintenanceManagerMock, workingSetObserver: workingSetObservationMock)
		XCTAssertThrowsError(try fileProviderAdapterManager.getAdapter(forDomain: domain, dbPath: dbPath, delegate: localURLProviderMock, notificator: fileProviderNotificatorMock, taskRegistrator: taskRegistratorMock)) { error in
			XCTAssertEqual(.defaultLock, error as? UnlockMonitorError)
		}
		XCTAssertFalse(maintenanceManagerMock.disableMaintenanceModeCalled)
		XCTAssertEqual([domain.identifier], adapterCacheMock.removeItemIdentifierReceivedInvocations)
		XCTAssertEqual([vaultUID], masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDReceivedInvocations)
	}

	// MARK: Lock Vault

	func testLockVault() {
		let notificactorMock = FileProviderNotificatorTypeMock()
		notificatorManagerMock.getFileProviderNotificatorForReturnValue = notificactorMock
		fileProviderAdapterManager.forceLockVault(with: domain.identifier)
		XCTAssertEqual([domain.identifier], adapterCacheMock.removeItemIdentifierReceivedInvocations)
		XCTAssertEqual([vaultUID], masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDReceivedInvocations)
		XCTAssertEqual(1, notificatorManagerMock.getFileProviderNotificatorForCallsCount)
		XCTAssertEqual(domain.identifier, notificatorManagerMock.getFileProviderNotificatorForReceivedDomain?.identifier)
		XCTAssertEqual(1, notificactorMock.refreshWorkingSetCallsCount)
	}

	func testGracefulLockVaultDisablesMaintenanceModeIfLockFailed() {
		let maintenanceManagerMock = MaintenanceManagerMock()
		masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDThrowableError = ErrorMock.test
		adapterCacheMock.getItemIdentifierReturnValue = AdapterCacheItem(adapter: FileProviderAdapterTypeMock(), maintenanceManager: maintenanceManagerMock, workingSetObserver: workingSetObservationMock)
		XCTAssertThrowsError(try fileProviderAdapterManager.gracefulLockVault(with: domain.identifier)) { error in
			XCTAssertEqual(.test, error as? ErrorMock)
		}
		XCTAssertEqual(1, maintenanceManagerMock.enableMaintenanceModeCallsCount)
		XCTAssertEqual(1, maintenanceManagerMock.disableMaintenanceModeCallsCount)
	}

	func testGracefulLockVaultAdapterNotCached() throws {
		adapterCacheMock.getItemIdentifierReturnValue = nil
		notificatorManagerMock.getFileProviderNotificatorForReturnValue = fileProviderNotificatorMock
		try fileProviderAdapterManager.gracefulLockVault(with: domain.identifier)
		XCTAssertEqual([vaultUID], masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDReceivedInvocations)
		XCTAssertEqual(1, fileProviderNotificatorMock.refreshWorkingSetCallsCount)
	}

	func testGracefulLockVaultWaitsForRunningAutoUnlock() {
		let cache = assertWaitsForRunningAutoUnlock {
			try self.fileProviderAdapterManager.gracefulLockVault(with: self.domain.identifier)
		}
		XCTAssert(cache.isEmpty)
		XCTAssertEqual([vaultUID], masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDReceivedInvocations)
	}

	func testForceLockVaultWaitsForRunningAutoUnlock() {
		let cache = assertWaitsForRunningAutoUnlock {
			self.fileProviderAdapterManager.forceLockVault(with: self.domain.identifier)
		}
		XCTAssert(cache.isEmpty)
		XCTAssertEqual([vaultUID], masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDReceivedInvocations)
	}

	@discardableResult
	private func assertWaitsForRunningAutoUnlock(_ operation: @escaping () throws -> Void) -> [NSFileProviderDomainIdentifier: AdapterCacheItem] {
		vaultKeepUnlockedHelperMock.shouldAutoUnlockVaultWithVaultUIDReturnValue = true
		masterkeyCacheManagerMock.getMasterkeyForVaultUIDReturnValue = Masterkey.createFromRaw(aesMasterKey: [UInt8](repeating: 0x55, count: 32), macMasterKey: [UInt8](repeating: 0x77, count: 32))
		notificatorManagerMock.getFileProviderNotificatorForReturnValue = fileProviderNotificatorMock
		var cache = [NSFileProviderDomainIdentifier: AdapterCacheItem]()
		adapterCacheMock.getItemIdentifierClosure = { return cache[$0] }
		adapterCacheMock.cacheItemIdentifierClosure = { cache[$1] = $0 }
		adapterCacheMock.removeItemIdentifierClosure = { cache[$0] = nil }
		let autoUnlockReadMasterkey = DispatchSemaphore(value: 0)
		let autoUnlockMayContinue = DispatchSemaphore(value: 0)
		vaultManagerMock.createVaultProviderWithUIDMasterkeyClosure = { _, _ in
			autoUnlockReadMasterkey.signal()
			autoUnlockMayContinue.wait()
			return CustomCloudProviderMock()
		}
		DispatchQueue.global().async {
			_ = try? self.fileProviderAdapterManager.getAdapter(forDomain: self.domain, dbPath: self.dbPath, delegate: self.localURLProviderMock, notificator: self.fileProviderNotificatorMock, taskRegistrator: self.taskRegistratorMock)
		}
		XCTAssertEqual(.success, autoUnlockReadMasterkey.wait(timeout: .now() + 5))
		let operationStarted = DispatchSemaphore(value: 0)
		let operationFinished = DispatchSemaphore(value: 0)
		var operationError: Error?
		DispatchQueue.global().async {
			operationStarted.signal()
			do {
				try operation()
			} catch {
				operationError = error
			}
			operationFinished.signal()
		}
		XCTAssertEqual(.success, operationStarted.wait(timeout: .now() + 5))
		XCTAssertEqual(.timedOut, operationFinished.wait(timeout: .now() + 0.5))
		autoUnlockMayContinue.signal()
		XCTAssertEqual(.success, operationFinished.wait(timeout: .now() + 5))
		XCTAssertNil(operationError)
		XCTAssertEqual(1, adapterCacheMock.cacheItemIdentifierCallsCount)
		return cache
	}

	private func assertLastUsedDateSet() throws {
		let passedLastUsedDate = try XCTUnwrap(vaultKeepUnlockedSettingsMock.setLastUsedDateForVaultUIDReceivedArguments?.date)
		XCTAssert(passedLastUsedDate <= Date())
		XCTAssert(passedLastUsedDate > Date().addingTimeInterval(-10))
	}

	// MARK: Unlock Vault

	func testUnlockVault() throws {
		let kek = [UInt8](repeating: 0x55, count: 32)
		vaultManagerMock.manualUnlockVaultWithUIDKekReturnValue = CustomCloudProviderMock()
		notificatorManagerMock.getFileProviderNotificatorForReturnValue = fileProviderNotificatorMock
		try fileProviderAdapterManager.unlockVault(with: domain.identifier, kek: kek, dbPath: dbPath, delegate: localURLProviderMock, notificator: fileProviderNotificatorMock, taskRegistrator: taskRegistratorMock)

		XCTAssertEqual(1, vaultManagerMock.manualUnlockVaultWithUIDKekCallsCount)
		XCTAssertEqual(vaultUID, vaultManagerMock.manualUnlockVaultWithUIDKekReceivedArguments?.vaultUID)
		XCTAssertEqual(kek, vaultManagerMock.manualUnlockVaultWithUIDKekReceivedArguments?.kek)

		XCTAssertEqual(1, adapterCacheMock.cacheItemIdentifierCallsCount)
		let cacheItemIdentifierReceivedArguments = try XCTUnwrap(adapterCacheMock.cacheItemIdentifierReceivedArguments)
		XCTAssertEqual(domain.identifier, cacheItemIdentifierReceivedArguments.identifier)

		try assertLastUsedDateSet()
	}

	// MARK: Vault Lock Status

	func testVaultIsUnlockedAdapterNotCached() {
		adapterCacheMock.getItemIdentifierReturnValue = nil
		vaultKeepUnlockedHelperMock.shouldAutoLockVaultWithVaultUIDReturnValue = false
		XCTAssertFalse(fileProviderAdapterManager.vaultIsUnlocked(domainIdentifier: domain.identifier))
		XCTAssertEqual([domain.identifier], adapterCacheMock.getItemIdentifierReceivedInvocations)
		XCTAssertEqual([vaultUID], vaultKeepUnlockedHelperMock.shouldAutoLockVaultWithVaultUIDReceivedInvocations)
		XCTAssertFalse(masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDCalled)
	}

	func testVaultIsUnlockedAdapterNotCachedShouldAutoLock() {
		adapterCacheMock.getItemIdentifierReturnValue = nil
		vaultKeepUnlockedHelperMock.shouldAutoLockVaultWithVaultUIDReturnValue = true
		notificatorManagerMock.getFileProviderNotificatorForReturnValue = fileProviderNotificatorMock
		XCTAssertFalse(fileProviderAdapterManager.vaultIsUnlocked(domainIdentifier: domain.identifier))
		XCTAssertEqual([vaultUID], masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDReceivedInvocations)
		XCTAssertEqual(1, fileProviderNotificatorMock.refreshWorkingSetCallsCount)
	}

	func testVaultIsUnlockedAdapterNotCachedShouldAutoLockRemoveCachedMasterkeyFailed() {
		adapterCacheMock.getItemIdentifierReturnValue = nil
		vaultKeepUnlockedHelperMock.shouldAutoLockVaultWithVaultUIDReturnValue = true
		masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDThrowableError = ErrorMock.test
		XCTAssertFalse(fileProviderAdapterManager.vaultIsUnlocked(domainIdentifier: domain.identifier))
	}

	func testVaultIsUnlockedWaitsForRunningAutoUnlock() {
		vaultKeepUnlockedHelperMock.shouldAutoLockVaultWithVaultUIDReturnValue = false
		var vaultIsUnlocked = false
		assertWaitsForRunningAutoUnlock {
			vaultIsUnlocked = self.fileProviderAdapterManager.vaultIsUnlocked(domainIdentifier: self.domain.identifier)
		}
		XCTAssert(vaultIsUnlocked)
	}

	func testVaultIsUnlockedAdapterCached() {
		let adapterCacheItem = AdapterCacheItem(adapter: FileProviderAdapterTypeMock(), maintenanceManager: MaintenanceManagerMock(), workingSetObserver: workingSetObservationMock)
		adapterCacheMock.getItemIdentifierReturnValue = adapterCacheItem
		vaultKeepUnlockedHelperMock.shouldAutoLockVaultWithVaultUIDReturnValue = false
		XCTAssert(fileProviderAdapterManager.vaultIsUnlocked(domainIdentifier: domain.identifier))
		XCTAssertEqual([domain.identifier], adapterCacheMock.getItemIdentifierReceivedInvocations)
		XCTAssertEqual([vaultUID], vaultKeepUnlockedHelperMock.shouldAutoLockVaultWithVaultUIDReceivedInvocations)
	}

	func testVaultIsUnlockedAutoLocks() {
		notificatorManagerMock.getFileProviderNotificatorForReturnValue = fileProviderNotificatorMock
		let maintenanceManagerMock = MaintenanceManagerMock()
		let adapterCacheItem = AdapterCacheItem(adapter: FileProviderAdapterTypeMock(), maintenanceManager: maintenanceManagerMock, workingSetObserver: workingSetObservationMock)
		var cache = [NSFileProviderDomainIdentifier: AdapterCacheItem]()
		cache[domain.identifier] = adapterCacheItem
		adapterCacheMock.getItemIdentifierClosure = { return cache[$0] }
		adapterCacheMock.removeItemIdentifierClosure = { cache[$0] = nil }
		vaultKeepUnlockedHelperMock.shouldAutoLockVaultWithVaultUIDReturnValue = true
		XCTAssertFalse(fileProviderAdapterManager.vaultIsUnlocked(domainIdentifier: domain.identifier))
		XCTAssertEqual([vaultUID], vaultKeepUnlockedHelperMock.shouldAutoLockVaultWithVaultUIDReceivedInvocations)
		XCTAssertEqual(1, maintenanceManagerMock.enableMaintenanceModeCallsCount)
		XCTAssertEqual(1, maintenanceManagerMock.disableMaintenanceModeCallsCount)
		XCTAssert(cache.isEmpty)
	}

	func testVaultIsUnlockedAutoLocksEnableMaintenanceModeFailed() {
		notificatorManagerMock.getFileProviderNotificatorForReturnValue = fileProviderNotificatorMock
		let maintenanceManagerMock = MaintenanceManagerMock()
		maintenanceManagerMock.enableMaintenanceModeThrowableError = ErrorMock.test
		let adapterCacheItem = AdapterCacheItem(adapter: FileProviderAdapterTypeMock(), maintenanceManager: maintenanceManagerMock, workingSetObserver: workingSetObservationMock)
		var cache = [NSFileProviderDomainIdentifier: AdapterCacheItem]()
		cache[domain.identifier] = adapterCacheItem
		adapterCacheMock.getItemIdentifierClosure = { return cache[$0] }
		adapterCacheMock.removeItemIdentifierClosure = { cache[$0] = nil }
		vaultKeepUnlockedHelperMock.shouldAutoLockVaultWithVaultUIDReturnValue = true
		XCTAssertFalse(fileProviderAdapterManager.vaultIsUnlocked(domainIdentifier: domain.identifier))
		XCTAssertFalse(maintenanceManagerMock.disableMaintenanceModeCalled)
		XCTAssertEqual([vaultUID], masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDReceivedInvocations)
		XCTAssert(cache.isEmpty)
	}
}
