//
//  FileProviderAdapterManagerTests.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 11.01.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import CryptomatorCryptoLib
import FileProvider
import XCTest
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
	var vaultAutoLockingHelperMock: VaultAutoLockingHelperMock!
	var vaultAutoLockingSettingsMock: VaultAutoLockingSettingsMock!
	private enum ErrorMock: Error {
		case test
	}

	override func setUpWithError() throws {
		masterkeyCacheManagerMock = MasterkeyCacheManagerMock()
		vaultAutoLockingHelperMock = VaultAutoLockingHelperMock()
		vaultAutoLockingSettingsMock = VaultAutoLockingSettingsMock()
		vaultManagerMock = VaultManagerMock()
		adapterCacheMock = FileProviderAdapterCacheTypeMock()
		fileProviderAdapterManager = FileProviderAdapterManager(masterkeyCacheManager: masterkeyCacheManagerMock, vaultAutoLockingHelper: vaultAutoLockingHelperMock, vaultAutoLockingSettings: vaultAutoLockingSettingsMock, vaultManager: vaultManagerMock, adapterCache: adapterCacheMock)
		tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
		dbPath = tmpURL.appendingPathComponent("db.sqlite", isDirectory: false)
		try FileManager.default.createDirectory(at: tmpURL, withIntermediateDirectories: false)
	}

	override func tearDownWithError() throws {
		fileProviderAdapterManager = nil
		try FileManager.default.removeItem(at: tmpURL)
	}

	// MARK: Get Adapter - Auto Unlock

	func testGetAdapterNotCachedNoAutoUnlock() throws {
		vaultAutoLockingHelperMock.shouldAutoUnlockVaultWithVaultUIDReturnValue = false
		XCTAssertThrowsError(try fileProviderAdapterManager.getAdapter(forDomain: domain, dbPath: dbPath, delegate: nil, notificator: nil)) { error in
			XCTAssertEqual(.cachedAdapterNotFound, error as? FileProviderAdapterManagerError)
		}
		XCTAssertEqual([vaultUID], vaultAutoLockingHelperMock.shouldAutoUnlockVaultWithVaultUIDReceivedInvocations)
		XCTAssertEqual([vaultUID], masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDReceivedInvocations)
	}

	func testGetAdapterNotCachedAutoUnlock() throws {
		vaultAutoLockingHelperMock.shouldAutoUnlockVaultWithVaultUIDReturnValue = true
		vaultManagerMock.createVaultProviderWithUIDMasterkeyReturnValue = CloudProviderMock()
		let masterkey = Masterkey.createFromRaw(aesMasterKey: [UInt8](repeating: 0x55, count: 32), macMasterKey: [UInt8](repeating: 0x77, count: 32))
		masterkeyCacheManagerMock.getMasterkeyForVaultUIDReturnValue = masterkey
		let adapter = try fileProviderAdapterManager.getAdapter(forDomain: domain, dbPath: dbPath, delegate: nil, notificator: nil)
		XCTAssertEqual([vaultUID], vaultAutoLockingHelperMock.shouldAutoUnlockVaultWithVaultUIDReceivedInvocations)
		XCTAssertFalse(masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDCalled)

		XCTAssertEqual(1, adapterCacheMock.cacheItemIdentifierCallsCount)
		let cacheItemIdentifierReceivedArguments = try XCTUnwrap(adapterCacheMock.cacheItemIdentifierReceivedArguments)
		XCTAssertEqual(domain.identifier, cacheItemIdentifierReceivedArguments.identifier)
		XCTAssert(cacheItemIdentifierReceivedArguments.item.adapter === adapter)

		XCTAssertEqual(1, vaultAutoLockingSettingsMock.setLastUsedDateForVaultUIDCallsCount)
		XCTAssertEqual(vaultUID, vaultAutoLockingSettingsMock.setLastUsedDateForVaultUIDReceivedArguments?.vaultUID)
		try assertLastUsedDateSet()
	}

	func testGetAdapterNotCachedAutoUnlockVaultManagerFailed() throws {
		vaultAutoLockingHelperMock.shouldAutoUnlockVaultWithVaultUIDReturnValue = true
		vaultManagerMock.createVaultProviderWithUIDMasterkeyThrowableError = ErrorMock.test
		let masterkey = Masterkey.createFromRaw(aesMasterKey: [UInt8](repeating: 0x55, count: 32), macMasterKey: [UInt8](repeating: 0x77, count: 32))
		masterkeyCacheManagerMock.getMasterkeyForVaultUIDReturnValue = masterkey
		XCTAssertThrowsError(try fileProviderAdapterManager.getAdapter(forDomain: domain, dbPath: dbPath, delegate: nil, notificator: nil)) { error in
			XCTAssertEqual(.test, error as? ErrorMock)
		}
		XCTAssertEqual([vaultUID], vaultAutoLockingHelperMock.shouldAutoUnlockVaultWithVaultUIDReceivedInvocations)
		XCTAssertFalse(masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDCalled)
		XCTAssertFalse(adapterCacheMock.cacheItemIdentifierCalled)
		XCTAssertFalse(vaultAutoLockingSettingsMock.setLastUsedDateForVaultUIDCalled)
	}

	func testGetAdapterNotCachedAutoUnlockMissingMasterkey() throws {
		vaultAutoLockingHelperMock.shouldAutoUnlockVaultWithVaultUIDReturnValue = true
		masterkeyCacheManagerMock.getMasterkeyForVaultUIDReturnValue = nil
		XCTAssertThrowsError(try fileProviderAdapterManager.getAdapter(forDomain: domain, dbPath: dbPath, delegate: nil, notificator: nil)) { error in
			XCTAssertEqual(.cachedAdapterNotFound, error as? FileProviderAdapterManagerError)
		}
		XCTAssertEqual([vaultUID], vaultAutoLockingHelperMock.shouldAutoUnlockVaultWithVaultUIDReceivedInvocations)
		XCTAssertFalse(masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDCalled)
		XCTAssertFalse(adapterCacheMock.cacheItemIdentifierCalled)
		XCTAssertFalse(vaultAutoLockingSettingsMock.setLastUsedDateForVaultUIDCalled)
	}

	// MARK: Get Adapter - Cached

	func testGetAdapterCachedNoAutoLock() throws {
		vaultAutoLockingHelperMock.shouldAutoLockVaultWithVaultUIDReturnValue = false
		let fileProviderAdapterStub = FileProviderAdapterTypeMock()
		adapterCacheMock.getItemIdentifierReturnValue = AdapterCacheItem(adapter: fileProviderAdapterStub, maintenanceManager: MaintenanceManagerMock())
		let adapter = try fileProviderAdapterManager.getAdapter(forDomain: domain, dbPath: dbPath, delegate: nil, notificator: nil)
		XCTAssert(adapter === fileProviderAdapterStub)
		try assertLastUsedDateSet()
	}

	func testGetAdapterCachedShouldAutoLock() throws {
		vaultAutoLockingHelperMock.shouldAutoLockVaultWithVaultUIDReturnValue = true
		let fileProviderAdapterStub = FileProviderAdapterTypeMock()
		let maintenanceManagerMock = MaintenanceManagerMock()
		adapterCacheMock.getItemIdentifierReturnValue = AdapterCacheItem(adapter: fileProviderAdapterStub, maintenanceManager: maintenanceManagerMock)
		XCTAssertThrowsError(try fileProviderAdapterManager.getAdapter(forDomain: domain, dbPath: dbPath, delegate: nil, notificator: nil)) { error in
			XCTAssertEqual(.cachedAdapterNotFound, error as? FileProviderAdapterManagerError)
		}
		XCTAssertEqual(1, maintenanceManagerMock.enableMaintenanceModeCallsCount)
		XCTAssertEqual(1, maintenanceManagerMock.disableMaintenanceModeCallsCount)
		XCTAssertEqual([domain.identifier], adapterCacheMock.removeItemIdentifierReceivedInvocations)
		XCTAssertEqual([vaultUID], masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDReceivedInvocations)
	}

	func testGetAdapterCachedShouldAutoLockEnableMaintenanceModeFailed() throws {
		vaultAutoLockingHelperMock.shouldAutoLockVaultWithVaultUIDReturnValue = true
		let fileProviderAdapterStub = FileProviderAdapterTypeMock()
		let maintenanceManagerMock = MaintenanceManagerMock()
		maintenanceManagerMock.enableMaintenanceModeThrowableError = ErrorMock.test
		adapterCacheMock.getItemIdentifierReturnValue = AdapterCacheItem(adapter: fileProviderAdapterStub, maintenanceManager: maintenanceManagerMock)
		XCTAssertThrowsError(try fileProviderAdapterManager.getAdapter(forDomain: domain, dbPath: dbPath, delegate: nil, notificator: nil)) { error in
			XCTAssertEqual(.cachedAdapterNotFound, error as? FileProviderAdapterManagerError)
		}
		XCTAssertFalse(maintenanceManagerMock.disableMaintenanceModeCalled)
		XCTAssertFalse(adapterCacheMock.removeItemIdentifierCalled)
		XCTAssertEqual([vaultUID], masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDReceivedInvocations)
	}

	// MARK: Lock Vault

	func testLockVault() throws {
		fileProviderAdapterManager.lockVault(with: domain.identifier)
		XCTAssertEqual([domain.identifier], adapterCacheMock.removeItemIdentifierReceivedInvocations)
		XCTAssertEqual([vaultUID], masterkeyCacheManagerMock.removeCachedMasterkeyForVaultUIDReceivedInvocations)
	}

	private func assertLastUsedDateSet() throws {
		let passedLastUsedDate = try XCTUnwrap(vaultAutoLockingSettingsMock.setLastUsedDateForVaultUIDReceivedArguments?.date)
		XCTAssert(passedLastUsedDate <= Date())
		XCTAssert(passedLastUsedDate > Date().addingTimeInterval(-10))
	}

	// MARK: Unlock Vault

	func testUnlockVault() throws {
		let kek = [UInt8](repeating: 0x55, count: 32)
		vaultManagerMock.manualUnlockVaultWithUIDKekReturnValue = CloudProviderMock()
		try fileProviderAdapterManager.unlockVault(with: domain.identifier, kek: kek, dbPath: dbPath, delegate: nil, notificator: nil)

		XCTAssertEqual(1, vaultManagerMock.manualUnlockVaultWithUIDKekCallsCount)
		XCTAssertEqual(vaultUID, vaultManagerMock.manualUnlockVaultWithUIDKekReceivedArguments?.vaultUID)
		XCTAssertEqual(kek, vaultManagerMock.manualUnlockVaultWithUIDKekReceivedArguments?.kek)

		XCTAssertEqual(1, adapterCacheMock.cacheItemIdentifierCallsCount)
		let cacheItemIdentifierReceivedArguments = try XCTUnwrap(adapterCacheMock.cacheItemIdentifierReceivedArguments)
		XCTAssertEqual(domain.identifier, cacheItemIdentifierReceivedArguments.identifier)

		try assertLastUsedDateSet()
	}
}
