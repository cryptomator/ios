//
//  VaultDBCacheTests.swift
//  CryptomatorCommonCoreTests
//
//  Created by Philipp Schmid on 10.07.21.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import Dependencies
import Foundation
import GRDB
import Promises
import XCTest
@testable import CryptomatorCloudAccessCore
@testable import CryptomatorCommonCore
@testable import CryptomatorCryptoLib

class VaultDBCacheTests: XCTestCase {
	private var vaultCache: VaultDBCache!
	private let vaultUID = UUID().uuidString
	private lazy var account: CloudProviderAccount = .init(accountUID: UUID().uuidString, cloudProviderType: .dropbox)
	private let vaultPath = CloudPath("/Vault")
	private lazy var vaultAccount: VaultAccount = .init(vaultUID: vaultUID, delegateAccountUID: account.accountUID, vaultPath: vaultPath, vaultName: "Vault")
	private let cloudProviderMock = CloudProviderMock()
	private var masterkeyFileData: Data!
	private var updatedMasterkeyFileData: Data!
	private let masterkey = Masterkey.createFromRaw(aesMasterKey: [UInt8](repeating: 0x55, count: 32), macMasterKey: [UInt8](repeating: 0x77, count: 32))
	private let updatedMasterkey = Masterkey.createFromRaw(aesMasterKey: [UInt8](repeating: 0x56, count: 32), macMasterKey: [UInt8](repeating: 0x78, count: 32))
	private var vaultConfigData: Data!
	private var updatedVaultConfigData: Data!
	private let vaultConfig = VaultConfig(id: "ABB9F673-F3E8-41A7-A43B-D29F5DA65068", format: 8, cipherCombo: .sivCtrMac, shorteningThreshold: 220)
	private var defaultCachedVault: CachedVault!
	private let updatedMasterkeyFileLastModifiedDate = Date(timeIntervalSince1970: 100)
	private let updatedVaultConfigLastModifiedDate = Date(timeIntervalSince1970: 200)

	override func setUpWithError() throws {
		let password = "PW"
		masterkeyFileData = try MasterkeyFile.lock(masterkey: masterkey, vaultVersion: 999, passphrase: password, scryptCostParam: 2)
		updatedMasterkeyFileData = try MasterkeyFile.lock(masterkey: updatedMasterkey, vaultVersion: 999, passphrase: password, scryptCostParam: 2)
		vaultConfigData = try vaultConfig.toToken(keyId: "masterkeyfile:masterkey.cryptomator", rawKey: masterkey.rawKey)
		updatedVaultConfigData = try vaultConfig.toToken(keyId: "masterkeyfile:masterkey.cryptomator", rawKey: updatedMasterkey.rawKey)
		defaultCachedVault = CachedVault(vaultUID: vaultUID, masterkeyFileData: masterkeyFileData, vaultConfigToken: vaultConfigData, lastUpToDateCheck: Date(timeIntervalSince1970: 0), masterkeyFileLastModifiedDate: Date(timeIntervalSince1970: 0), vaultConfigLastModifiedDate: Date(timeIntervalSince1970: 0))

		vaultCache = VaultDBCache()
		try prepareDatabase()
	}

	func testCacheVault() throws {
		try vaultCache.cache(defaultCachedVault)
		let fetchedCachedVault = try vaultCache.getCachedVault(withVaultUID: vaultUID)
		XCTAssertEqual(defaultCachedVault, fetchedCachedVault)
	}

	func testCacheVaultSettingVaultConfigLastModifiedDateWithoutVaultConfigData() throws {
		let invalidCachedVault = CachedVault(vaultUID: defaultCachedVault.vaultUID,
		                                     masterkeyFileData: defaultCachedVault.masterkeyFileData,
		                                     vaultConfigToken: nil,
		                                     lastUpToDateCheck: defaultCachedVault.lastUpToDateCheck,
		                                     masterkeyFileLastModifiedDate: nil,
		                                     vaultConfigLastModifiedDate: Date())
		XCTAssertThrowsError(try vaultCache.cache(invalidCachedVault)) { error in
			guard let error = error as? DatabaseError, error.message == "CHECK constraint failed: NOT (vaultConfigLastModifiedDate IS NOT NULL AND vaultConfigToken IS NULL)" else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}
	}

	func testCascadeOnVaultAccountDeletion() throws {
		@Dependency(\.database) var database

		try vaultCache.cache(defaultCachedVault)

		_ = try database.write { db in
			try vaultAccount.delete(db)
		}
		XCTAssertThrowsError(try vaultCache.getCachedVault(withVaultUID: vaultUID)) { error in
			guard case VaultCacheError.vaultNotFound = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}
	}

	// MARK: Refresh Vault Cache

	func testRefreshVaultCache() throws {
		try vaultCache.cache(defaultCachedVault)
		cloudProviderMock.fetchItemMetadataAtClosure = defaultFetchItemMetadataMock
		cloudProviderMock.downloadFileFromToClosure = downloadMock
		let promise = vaultCache.refreshVaultCache(for: vaultAccount, with: cloudProviderMock)
		wait(for: promise, timeout: 1.0)

		let expectedCachedVault = CachedVault(vaultUID: vaultUID,
		                                      masterkeyFileData: updatedMasterkeyFileData,
		                                      vaultConfigToken: updatedVaultConfigData,
		                                      lastUpToDateCheck: defaultCachedVault.lastUpToDateCheck,
		                                      masterkeyFileLastModifiedDate: updatedMasterkeyFileLastModifiedDate,
		                                      vaultConfigLastModifiedDate: updatedVaultConfigLastModifiedDate)
		let fetchedCachedVault = try vaultCache.getCachedVault(withVaultUID: vaultUID)
		XCTAssertEqual(expectedCachedVault, fetchedCachedVault)
		XCTAssertEqual(2, cloudProviderMock.downloadFileFromToCallsCount)
		assertFetchItemMetadataCalledForVaultConfigAndMasterkey()
		assertDownloadedVaultConfigAndMasterkey()
	}

	func testRefreshCacheUpdatedMasterkeyMissingVaultConfig() throws {
		try vaultCache.cache(defaultCachedVault)
		cloudProviderMock.fetchItemMetadataAtClosure = { cloudPath in
			if cloudPath.lastPathComponent == "masterkey.cryptomator" {
				return Promise(CloudItemMetadata(name: "masterkey.cryptomator", cloudPath: cloudPath, itemType: .file, lastModifiedDate: self.updatedMasterkeyFileLastModifiedDate, size: 100))
			} else {
				return Promise(CloudProviderError.itemNotFound)
			}
		}
		cloudProviderMock.downloadFileFromToClosure = { [self] cloudPath, downloadDestination in
			if cloudPath.lastPathComponent == "masterkey.cryptomator" {
				do {
					try updatedMasterkeyFileData.write(to: downloadDestination)
				} catch {
					XCTFail("Write to downloadDestination \(downloadDestination) failed with error: \(error)")
				}
			}
			return Promise(())
		}
		let promise = vaultCache.refreshVaultCache(for: vaultAccount, with: cloudProviderMock)
		wait(for: promise, timeout: 1.0)
		let fetchedVault = try vaultCache.getCachedVault(withVaultUID: vaultUID)
		let expectedCachedVault = CachedVault(vaultUID: vaultUID,
		                                      masterkeyFileData: updatedMasterkeyFileData,
		                                      vaultConfigToken: nil,
		                                      lastUpToDateCheck: defaultCachedVault.lastUpToDateCheck,
		                                      masterkeyFileLastModifiedDate: updatedMasterkeyFileLastModifiedDate,
		                                      vaultConfigLastModifiedDate: nil)
		XCTAssertEqual(expectedCachedVault, fetchedVault)
		assertFetchItemMetadataCalledForVaultConfigAndMasterkey()
		assertDownloadedOnlyMasterkey()
	}

	func testRefreshVaultCacheOnlyMasterkeyUpdated() throws {
		try vaultCache.cache(defaultCachedVault)
		cloudProviderMock.fetchItemMetadataAtClosure = { cloudPath in
			let metadata: CloudItemMetadata
			if cloudPath.lastPathComponent == "masterkey.cryptomator" {
				metadata = CloudItemMetadata(name: "masterkey.cryptomator", cloudPath: cloudPath, itemType: .file, lastModifiedDate: self.updatedMasterkeyFileLastModifiedDate, size: 100)
			} else {
				metadata = CloudItemMetadata(name: "vault.cryptomator", cloudPath: cloudPath, itemType: .file, lastModifiedDate: self.defaultCachedVault.vaultConfigLastModifiedDate!, size: 50)
			}
			return Promise(metadata)
		}
		cloudProviderMock.downloadFileFromToClosure = downloadMock
		wait(for: vaultCache.refreshVaultCache(for: vaultAccount, with: cloudProviderMock), timeout: 1.0)
		let actualCachedVault = try vaultCache.getCachedVault(withVaultUID: vaultUID)
		let expectedCachedVault = CachedVault(vaultUID: vaultUID,
		                                      masterkeyFileData: updatedMasterkeyFileData,
		                                      vaultConfigToken: vaultConfigData,
		                                      lastUpToDateCheck: defaultCachedVault.lastUpToDateCheck,
		                                      masterkeyFileLastModifiedDate: updatedMasterkeyFileLastModifiedDate,
		                                      vaultConfigLastModifiedDate: defaultCachedVault.vaultConfigLastModifiedDate)
		XCTAssertEqual(expectedCachedVault, actualCachedVault)
		assertFetchItemMetadataCalledForVaultConfigAndMasterkey()
		assertDownloadedOnlyMasterkey()
	}

	func testRefreshVaultCacheOnlyVaultConfigUpdated() throws {
		let masterkeyFileLastModifiedDate = Date(timeIntervalSince1970: 0)
		let cachedVault = CachedVault(vaultUID: vaultUID, masterkeyFileData: masterkeyFileData, vaultConfigToken: vaultConfigData, lastUpToDateCheck: defaultCachedVault.lastUpToDateCheck, masterkeyFileLastModifiedDate: masterkeyFileLastModifiedDate, vaultConfigLastModifiedDate: defaultCachedVault.vaultConfigLastModifiedDate)
		try vaultCache.cache(cachedVault)
		cloudProviderMock.fetchItemMetadataAtClosure = { cloudPath in
			let metadata: CloudItemMetadata
			if cloudPath.lastPathComponent == "masterkey.cryptomator" {
				metadata = CloudItemMetadata(name: "masterkey.cryptomator", cloudPath: cloudPath, itemType: .file, lastModifiedDate: masterkeyFileLastModifiedDate, size: 100)
			} else {
				metadata = CloudItemMetadata(name: "vault.cryptomator", cloudPath: cloudPath, itemType: .file, lastModifiedDate: self.updatedVaultConfigLastModifiedDate, size: 50)
			}
			return Promise(metadata)
		}
		cloudProviderMock.downloadFileFromToClosure = { [self] _, downloadDestination in
			do {
				try updatedVaultConfigData.write(to: downloadDestination)
			} catch {
				XCTFail("Write to downloadDestination \(downloadDestination) failed with error: \(error)")
			}
			return Promise(())
		}
		wait(for: vaultCache.refreshVaultCache(for: vaultAccount, with: cloudProviderMock), timeout: 1.0)
		let actualCachedVault = try vaultCache.getCachedVault(withVaultUID: vaultUID)
		let expectedCachedVault = CachedVault(vaultUID: vaultUID,
		                                      masterkeyFileData: masterkeyFileData,
		                                      vaultConfigToken: updatedVaultConfigData,
		                                      lastUpToDateCheck: defaultCachedVault.lastUpToDateCheck,
		                                      masterkeyFileLastModifiedDate: masterkeyFileLastModifiedDate,
		                                      vaultConfigLastModifiedDate: updatedVaultConfigLastModifiedDate)
		XCTAssertEqual(expectedCachedVault, actualCachedVault)
		assertFetchItemMetadataCalledForVaultConfigAndMasterkey()
		assertDownloadedOnlyVaultConfig()
	}

	func testRefreshUpToDateCache() throws {
		let upToDateCachedVault = CachedVault(vaultUID: vaultUID, masterkeyFileData: updatedMasterkeyFileData, vaultConfigToken: updatedVaultConfigData, lastUpToDateCheck: defaultCachedVault.lastUpToDateCheck, masterkeyFileLastModifiedDate: updatedMasterkeyFileLastModifiedDate, vaultConfigLastModifiedDate: updatedVaultConfigLastModifiedDate)
		try vaultCache.cache(upToDateCachedVault)
		cloudProviderMock.fetchItemMetadataAtClosure = { cloudPath in
			let metadata: CloudItemMetadata
			if cloudPath.lastPathComponent == "masterkey.cryptomator" {
				metadata = CloudItemMetadata(name: "masterkey.cryptomator", cloudPath: cloudPath, itemType: .file, lastModifiedDate: self.updatedMasterkeyFileLastModifiedDate, size: 100)
			} else {
				metadata = CloudItemMetadata(name: "vault.cryptomator", cloudPath: cloudPath, itemType: .file, lastModifiedDate: self.updatedVaultConfigLastModifiedDate, size: 50)
			}
			return Promise(metadata)
		}
		let promise = vaultCache.refreshVaultCache(for: vaultAccount, with: cloudProviderMock)
		wait(for: promise, timeout: 1.0)
		let fetchedVault = try vaultCache.getCachedVault(withVaultUID: vaultUID)
		XCTAssertEqual(upToDateCachedVault, fetchedVault)
		assertFetchItemMetadataCalledForVaultConfigAndMasterkey()
		XCTAssertFalse(cloudProviderMock.downloadFileFromToCalled)
	}

	func testRefreshCacheLastModifiedDateNotSetInCache() throws {
		let cachedVault = CachedVault(vaultUID: vaultUID, masterkeyFileData: masterkeyFileData, vaultConfigToken: vaultConfigData, lastUpToDateCheck: defaultCachedVault.lastUpToDateCheck, masterkeyFileLastModifiedDate: nil, vaultConfigLastModifiedDate: nil)
		try vaultCache.cache(cachedVault)
		cloudProviderMock.fetchItemMetadataAtClosure = defaultFetchItemMetadataMock
		cloudProviderMock.downloadFileFromToClosure = downloadMock
		let promise = vaultCache.refreshVaultCache(for: vaultAccount, with: cloudProviderMock)
		wait(for: promise, timeout: 1.0)
		let actualCachedVault = try vaultCache.getCachedVault(withVaultUID: vaultUID)
		let upToDateCachedVault = CachedVault(vaultUID: vaultUID, masterkeyFileData: updatedMasterkeyFileData, vaultConfigToken: updatedVaultConfigData, lastUpToDateCheck: defaultCachedVault.lastUpToDateCheck, masterkeyFileLastModifiedDate: updatedMasterkeyFileLastModifiedDate, vaultConfigLastModifiedDate: updatedVaultConfigLastModifiedDate)
		XCTAssertEqual(upToDateCachedVault, actualCachedVault)
		assertFetchItemMetadataCalledForVaultConfigAndMasterkey()
		assertDownloadedVaultConfigAndMasterkey()
	}

	func testRefreshCacheMissingVaultConfigAndMasterkey() throws {
		cloudProviderMock.fetchItemMetadataAtThrowableError = CloudProviderError.itemNotFound
		try vaultCache.cache(defaultCachedVault)
		XCTAssertRejects(vaultCache.refreshVaultCache(for: vaultAccount, with: cloudProviderMock), with: CloudProviderError.itemNotFound)
		let actualCachedVault = try vaultCache.getCachedVault(withVaultUID: vaultUID)
		let expectedCachedVault = CachedVault(vaultUID: vaultUID, masterkeyFileData: defaultCachedVault.masterkeyFileData, vaultConfigToken: nil, lastUpToDateCheck: defaultCachedVault.lastUpToDateCheck, masterkeyFileLastModifiedDate: defaultCachedVault.masterkeyFileLastModifiedDate, vaultConfigLastModifiedDate: nil)
		XCTAssertEqual(expectedCachedVault, actualCachedVault)
		XCTAssertFalse(cloudProviderMock.downloadFileFromToCalled)
	}

	func testRefreshCacheMissingMasterkeyUpdatedVaultConfig() throws {
		cloudProviderMock.fetchItemMetadataAtClosure = { cloudPath in
			let metadata: CloudItemMetadata
			if cloudPath.lastPathComponent == "masterkey.cryptomator" {
				return Promise(CloudProviderError.itemNotFound)
			} else {
				metadata = CloudItemMetadata(name: "vault.cryptomator", cloudPath: cloudPath, itemType: .file, lastModifiedDate: self.updatedVaultConfigLastModifiedDate, size: 50)
			}
			return Promise(metadata)
		}
		cloudProviderMock.downloadFileFromToClosure = downloadMock
		try vaultCache.cache(defaultCachedVault)
		XCTAssertRejects(vaultCache.refreshVaultCache(for: vaultAccount, with: cloudProviderMock), with: CloudProviderError.itemNotFound)
		let actualCachedVault = try vaultCache.getCachedVault(withVaultUID: vaultUID)
		let expectedCachedVault = CachedVault(vaultUID: vaultUID, masterkeyFileData: defaultCachedVault.masterkeyFileData, vaultConfigToken: updatedVaultConfigData, lastUpToDateCheck: defaultCachedVault.lastUpToDateCheck, masterkeyFileLastModifiedDate: defaultCachedVault.masterkeyFileLastModifiedDate, vaultConfigLastModifiedDate: updatedVaultConfigLastModifiedDate)
		XCTAssertEqual(expectedCachedVault, actualCachedVault)
		assertFetchItemMetadataCalledForVaultConfigAndMasterkey()
		assertDownloadedOnlyVaultConfig()
	}

	func testRefreshForNonCachedVault() throws {
		XCTAssertRejects(vaultCache.refreshVaultCache(for: vaultAccount, with: cloudProviderMock), with: VaultCacheError.vaultNotFound)
	}

	private func downloadMock(_ cloudPath: CloudPath, _ downloadDestination: URL) -> Promise<Void> {
		let data: Data
		if cloudPath.lastPathComponent == "masterkey.cryptomator" {
			data = updatedMasterkeyFileData
		} else {
			data = updatedVaultConfigData
		}
		return try Promise(data.write(to: downloadDestination))
	}

	private func defaultFetchItemMetadataMock(_ cloudPath: CloudPath) -> Promise<CloudItemMetadata> {
		let metadata: CloudItemMetadata
		if cloudPath.lastPathComponent == "masterkey.cryptomator" {
			metadata = CloudItemMetadata(name: "masterkey.cryptomator", cloudPath: cloudPath, itemType: .file, lastModifiedDate: updatedMasterkeyFileLastModifiedDate, size: 100)
		} else {
			metadata = CloudItemMetadata(name: "vault.cryptomator", cloudPath: cloudPath, itemType: .file, lastModifiedDate: updatedVaultConfigLastModifiedDate, size: 50)
		}
		return Promise(metadata)
	}

	private func assertFetchItemMetadataCalledForVaultConfigAndMasterkey() {
		XCTAssertEqual([CloudPath("/Vault/vault.cryptomator"), CloudPath("/Vault/masterkey.cryptomator")], cloudProviderMock.fetchItemMetadataAtReceivedInvocations)
	}

	private func assertDownloadedVaultConfigAndMasterkey() {
		XCTAssertEqual([CloudPath("/Vault/vault.cryptomator"), CloudPath("/Vault/masterkey.cryptomator")], cloudProviderMock.downloadFileFromToReceivedInvocations.map { $0.cloudPath })
	}

	private func assertDownloadedOnlyVaultConfig() {
		XCTAssertEqual([CloudPath("/Vault/vault.cryptomator")], cloudProviderMock.downloadFileFromToReceivedInvocations.map { $0.cloudPath })
	}

	private func assertDownloadedOnlyMasterkey() {
		XCTAssertEqual([CloudPath("/Vault/masterkey.cryptomator")], cloudProviderMock.downloadFileFromToReceivedInvocations.map { $0.cloudPath })
	}

	private func prepareDatabase() throws {
		@Dependency(\.database) var database
		try database.write { db in
			try account.save(db)
			try vaultAccount.save(db)
		}
	}
}
