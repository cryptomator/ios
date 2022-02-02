//
//  FileProviderAdapterManagerTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 11.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import FileProvider
import Promises
import XCTest
@testable import CryptomatorCryptoLib
@testable import CryptomatorFileProvider

class FileProviderAdapterManagerTests: XCTestCase {
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
		fileProviderAdapterManager = FileProviderAdapterManager(masterkeyCacheManager: masterkeyCacheManagerMock, vaultKeepUnlockedHelper: vaultKeepUnlockedHelperMock, vaultKeepUnlockedSettings: vaultKeepUnlockedSettingsMock, vaultManager: vaultManagerMock, adapterCache: adapterCacheMock, notificatorManager: notificatorManagerMock, unlockMonitor: UnlockMonitor())
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
		XCTAssertThrowsError(try fileProviderAdapterManager.getAdapter(forDomain: domain, dbPath: dbPath, delegate: nil, notificator: fileProviderNotificatorMock)) { error in
			XCTAssertEqual(.defaultLock, error as? UnlockMonitorError)
		}
		XCTAssertEqual([vaultUID], vaultKeepUnlockedHelperMock.shouldAutoUnlockVaultWithVaultUIDReceivedInvocations)
		XCTAssertEqual([vaultUID], masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDReceivedInvocations)
	}

	func testGetAdapterNotCachedAutoUnlock() throws {
		vaultKeepUnlockedHelperMock.shouldAutoUnlockVaultWithVaultUIDReturnValue = true
		vaultManagerMock.createVaultProviderWithUIDMasterkeyReturnValue = CloudProviderMock()
		let masterkey = Masterkey.createFromRaw(aesMasterKey: [UInt8](repeating: 0x55, count: 32), macMasterKey: [UInt8](repeating: 0x77, count: 32))
		masterkeyCacheManagerMock.getMasterkeyForVaultUIDReturnValue = masterkey
		let adapter = try fileProviderAdapterManager.getAdapter(forDomain: domain, dbPath: dbPath, delegate: nil, notificator: fileProviderNotificatorMock)
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
		XCTAssertThrowsError(try fileProviderAdapterManager.getAdapter(forDomain: domain, dbPath: dbPath, delegate: nil, notificator: fileProviderNotificatorMock)) { error in
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
		XCTAssertThrowsError(try fileProviderAdapterManager.getAdapter(forDomain: domain, dbPath: dbPath, delegate: nil, notificator: fileProviderNotificatorMock)) { error in
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
		let adapter = try fileProviderAdapterManager.getAdapter(forDomain: domain, dbPath: dbPath, delegate: nil, notificator: fileProviderNotificatorMock)
		XCTAssert(adapter === fileProviderAdapterStub)
		try assertLastUsedDateSet()
	}

	func testGetAdapterCachedShouldAutoLock() throws {
		vaultKeepUnlockedHelperMock.shouldAutoLockVaultWithVaultUIDReturnValue = true
		let fileProviderAdapterStub = FileProviderAdapterTypeMock()
		let maintenanceManagerMock = MaintenanceManagerMock()
		notificatorManagerMock.getFileProviderNotificatorForReturnValue = fileProviderNotificatorMock
		adapterCacheMock.getItemIdentifierReturnValue = AdapterCacheItem(adapter: fileProviderAdapterStub, maintenanceManager: maintenanceManagerMock, workingSetObserver: workingSetObservationMock)
		XCTAssertThrowsError(try fileProviderAdapterManager.getAdapter(forDomain: domain, dbPath: dbPath, delegate: nil, notificator: fileProviderNotificatorMock)) { error in
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
		adapterCacheMock.getItemIdentifierReturnValue = AdapterCacheItem(adapter: fileProviderAdapterStub, maintenanceManager: maintenanceManagerMock, workingSetObserver: workingSetObservationMock)
		XCTAssertThrowsError(try fileProviderAdapterManager.getAdapter(forDomain: domain, dbPath: dbPath, delegate: nil, notificator: fileProviderNotificatorMock)) { error in
			XCTAssertEqual(.defaultLock, error as? UnlockMonitorError)
		}
		XCTAssertFalse(maintenanceManagerMock.disableMaintenanceModeCalled)
		XCTAssertFalse(adapterCacheMock.removeItemIdentifierCalled)
		XCTAssertFalse(masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDCalled)
	}

	// MARK: Lock Vault

	func testLockVault() throws {
		let notificactorMock = FileProviderNotificatorTypeMock()
		notificatorManagerMock.getFileProviderNotificatorForReturnValue = notificactorMock
		fileProviderAdapterManager.forceLockVault(with: domain.identifier)
		XCTAssertEqual([domain.identifier], adapterCacheMock.removeItemIdentifierReceivedInvocations)
		XCTAssertEqual([vaultUID], masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDReceivedInvocations)
		XCTAssertEqual(1, notificatorManagerMock.getFileProviderNotificatorForCallsCount)
		XCTAssertEqual(domain.identifier, notificatorManagerMock.getFileProviderNotificatorForReceivedDomain?.identifier)
		XCTAssertEqual(1, notificactorMock.refreshWorkingSetCallsCount)
	}

	private func assertLastUsedDateSet() throws {
		let passedLastUsedDate = try XCTUnwrap(vaultKeepUnlockedSettingsMock.setLastUsedDateForVaultUIDReceivedArguments?.date)
		XCTAssert(passedLastUsedDate <= Date())
		XCTAssert(passedLastUsedDate > Date().addingTimeInterval(-10))
	}

	// MARK: Unlock Vault

	func testUnlockVault() throws {
		let kek = [UInt8](repeating: 0x55, count: 32)
		vaultManagerMock.manualUnlockVaultWithUIDKekReturnValue = CloudProviderMock()
		notificatorManagerMock.getFileProviderNotificatorForReturnValue = fileProviderNotificatorMock
		try fileProviderAdapterManager.unlockVault(with: domain.identifier, kek: kek, dbPath: dbPath, delegate: nil, notificator: fileProviderNotificatorMock)

		XCTAssertEqual(1, vaultManagerMock.manualUnlockVaultWithUIDKekCallsCount)
		XCTAssertEqual(vaultUID, vaultManagerMock.manualUnlockVaultWithUIDKekReceivedArguments?.vaultUID)
		XCTAssertEqual(kek, vaultManagerMock.manualUnlockVaultWithUIDKekReceivedArguments?.kek)

		XCTAssertEqual(1, adapterCacheMock.cacheItemIdentifierCallsCount)
		let cacheItemIdentifierReceivedArguments = try XCTUnwrap(adapterCacheMock.cacheItemIdentifierReceivedArguments)
		XCTAssertEqual(domain.identifier, cacheItemIdentifierReceivedArguments.identifier)

		try assertLastUsedDateSet()
	}
}
