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

	func testRefreshVaultCache() async throws {
		try vaultCache.cache(defaultCachedVault)
		cloudProviderMock.fetchItemMetadataAtClosure = defaultFetchItemMetadataMock()
		cloudProviderMock.downloadFileFromToClosure = downloadMock()
		try await vaultCache.refreshVaultCache(for: vaultAccount, with: cloudProviderMock)

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

	func testRefreshCacheUpdatedMasterkeyMissingVaultConfig() async throws {
		try vaultCache.cache(defaultCachedVault)
		let updatedMasterkeyFileLastModifiedDate = updatedMasterkeyFileLastModifiedDate
		let updatedMasterkeyFileData: Data = updatedMasterkeyFileData
		cloudProviderMock.fetchItemMetadataAtClosure = { cloudPath in
			if cloudPath.lastPathComponent == "masterkey.cryptomator" {
				return CloudItemMetadata(name: "masterkey.cryptomator", cloudPath: cloudPath, itemType: .file, lastModifiedDate: updatedMasterkeyFileLastModifiedDate, size: 100)
			} else {
				throw CloudProviderError.itemNotFound
			}
		}
		cloudProviderMock.downloadFileFromToClosure = { cloudPath, downloadDestination in
			if cloudPath.lastPathComponent == "masterkey.cryptomator" {
				do {
					try updatedMasterkeyFileData.write(to: downloadDestination)
				} catch {
					XCTFail("Write to downloadDestination \(downloadDestination) failed with error: \(error)")
				}
			}
			return CloudItemMetadata(name: cloudPath.lastPathComponent, cloudPath: cloudPath, itemType: .file, lastModifiedDate: nil, size: nil)
		}
		try await vaultCache.refreshVaultCache(for: vaultAccount, with: cloudProviderMock)
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

	func testRefreshVaultCacheOnlyMasterkeyUpdated() async throws {
		try vaultCache.cache(defaultCachedVault)
		let updatedMasterkeyFileLastModifiedDate = updatedMasterkeyFileLastModifiedDate
		let vaultConfigLastModifiedDate = try XCTUnwrap(defaultCachedVault.vaultConfigLastModifiedDate)
		cloudProviderMock.fetchItemMetadataAtClosure = { cloudPath in
			let metadata: CloudItemMetadata
			if cloudPath.lastPathComponent == "masterkey.cryptomator" {
				metadata = CloudItemMetadata(name: "masterkey.cryptomator", cloudPath: cloudPath, itemType: .file, lastModifiedDate: updatedMasterkeyFileLastModifiedDate, size: 100)
			} else {
				metadata = CloudItemMetadata(name: "vault.cryptomator", cloudPath: cloudPath, itemType: .file, lastModifiedDate: vaultConfigLastModifiedDate, size: 50)
			}
			return metadata
		}
		cloudProviderMock.downloadFileFromToClosure = downloadMock()
		try await vaultCache.refreshVaultCache(for: vaultAccount, with: cloudProviderMock)
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

	func testRefreshVaultCacheOnlyVaultConfigUpdated() async throws {
		let masterkeyFileLastModifiedDate = Date(timeIntervalSince1970: 0)
		let cachedVault = CachedVault(vaultUID: vaultUID, masterkeyFileData: masterkeyFileData, vaultConfigToken: vaultConfigData, lastUpToDateCheck: defaultCachedVault.lastUpToDateCheck, masterkeyFileLastModifiedDate: masterkeyFileLastModifiedDate, vaultConfigLastModifiedDate: defaultCachedVault.vaultConfigLastModifiedDate)
		try vaultCache.cache(cachedVault)
		let updatedVaultConfigLastModifiedDate = updatedVaultConfigLastModifiedDate
		let updatedVaultConfigData: Data = updatedVaultConfigData
		cloudProviderMock.fetchItemMetadataAtClosure = { cloudPath in
			let metadata: CloudItemMetadata
			if cloudPath.lastPathComponent == "masterkey.cryptomator" {
				metadata = CloudItemMetadata(name: "masterkey.cryptomator", cloudPath: cloudPath, itemType: .file, lastModifiedDate: masterkeyFileLastModifiedDate, size: 100)
			} else {
				metadata = CloudItemMetadata(name: "vault.cryptomator", cloudPath: cloudPath, itemType: .file, lastModifiedDate: updatedVaultConfigLastModifiedDate, size: 50)
			}
			return metadata
		}
		cloudProviderMock.downloadFileFromToClosure = { cloudPath, downloadDestination in
			do {
				try updatedVaultConfigData.write(to: downloadDestination)
			} catch {
				XCTFail("Write to downloadDestination \(downloadDestination) failed with error: \(error)")
			}
			return CloudItemMetadata(name: cloudPath.lastPathComponent, cloudPath: cloudPath, itemType: .file, lastModifiedDate: nil, size: nil)
		}
		try await vaultCache.refreshVaultCache(for: vaultAccount, with: cloudProviderMock)
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

	func testRefreshUpToDateCache() async throws {
		let upToDateCachedVault = CachedVault(vaultUID: vaultUID, masterkeyFileData: updatedMasterkeyFileData, vaultConfigToken: updatedVaultConfigData, lastUpToDateCheck: defaultCachedVault.lastUpToDateCheck, masterkeyFileLastModifiedDate: updatedMasterkeyFileLastModifiedDate, vaultConfigLastModifiedDate: updatedVaultConfigLastModifiedDate)
		try vaultCache.cache(upToDateCachedVault)
		cloudProviderMock.fetchItemMetadataAtClosure = defaultFetchItemMetadataMock()
		try await vaultCache.refreshVaultCache(for: vaultAccount, with: cloudProviderMock)
		let fetchedVault = try vaultCache.getCachedVault(withVaultUID: vaultUID)
		XCTAssertEqual(upToDateCachedVault, fetchedVault)
		assertFetchItemMetadataCalledForVaultConfigAndMasterkey()
		XCTAssertFalse(cloudProviderMock.downloadFileFromToCalled)
	}

	func testRefreshCacheLastModifiedDateNotSetInCache() async throws {
		let cachedVault = CachedVault(vaultUID: vaultUID, masterkeyFileData: masterkeyFileData, vaultConfigToken: vaultConfigData, lastUpToDateCheck: defaultCachedVault.lastUpToDateCheck, masterkeyFileLastModifiedDate: nil, vaultConfigLastModifiedDate: nil)
		try vaultCache.cache(cachedVault)
		cloudProviderMock.fetchItemMetadataAtClosure = defaultFetchItemMetadataMock()
		cloudProviderMock.downloadFileFromToClosure = downloadMock()
		try await vaultCache.refreshVaultCache(for: vaultAccount, with: cloudProviderMock)
		let actualCachedVault = try vaultCache.getCachedVault(withVaultUID: vaultUID)
		let upToDateCachedVault = CachedVault(vaultUID: vaultUID, masterkeyFileData: updatedMasterkeyFileData, vaultConfigToken: updatedVaultConfigData, lastUpToDateCheck: defaultCachedVault.lastUpToDateCheck, masterkeyFileLastModifiedDate: updatedMasterkeyFileLastModifiedDate, vaultConfigLastModifiedDate: updatedVaultConfigLastModifiedDate)
		XCTAssertEqual(upToDateCachedVault, actualCachedVault)
		assertFetchItemMetadataCalledForVaultConfigAndMasterkey()
		assertDownloadedVaultConfigAndMasterkey()
	}

	func testRefreshCacheMissingVaultConfigAndMasterkey() async throws {
		cloudProviderMock.fetchItemMetadataAtThrowableError = CloudProviderError.itemNotFound
		try vaultCache.cache(defaultCachedVault)
		await XCTAssertThrowsAsyncError(try await vaultCache.refreshVaultCache(for: vaultAccount, with: cloudProviderMock)) { error in
			XCTAssertEqual(.itemNotFound, error as? CloudProviderError)
		}
		let actualCachedVault = try vaultCache.getCachedVault(withVaultUID: vaultUID)
		let expectedCachedVault = CachedVault(vaultUID: vaultUID, masterkeyFileData: defaultCachedVault.masterkeyFileData, vaultConfigToken: nil, lastUpToDateCheck: defaultCachedVault.lastUpToDateCheck, masterkeyFileLastModifiedDate: defaultCachedVault.masterkeyFileLastModifiedDate, vaultConfigLastModifiedDate: nil)
		XCTAssertEqual(expectedCachedVault, actualCachedVault)
		XCTAssertFalse(cloudProviderMock.downloadFileFromToCalled)
	}

	func testRefreshCacheMissingMasterkeyUpdatedVaultConfig() async throws {
		let updatedVaultConfigLastModifiedDate = updatedVaultConfigLastModifiedDate
		cloudProviderMock.fetchItemMetadataAtClosure = { cloudPath in
			let metadata: CloudItemMetadata
			if cloudPath.lastPathComponent == "masterkey.cryptomator" {
				throw CloudProviderError.itemNotFound
			} else {
				metadata = CloudItemMetadata(name: "vault.cryptomator", cloudPath: cloudPath, itemType: .file, lastModifiedDate: updatedVaultConfigLastModifiedDate, size: 50)
			}
			return metadata
		}
		cloudProviderMock.downloadFileFromToClosure = downloadMock()
		try vaultCache.cache(defaultCachedVault)
		await XCTAssertThrowsAsyncError(try await vaultCache.refreshVaultCache(for: vaultAccount, with: cloudProviderMock)) { error in
			XCTAssertEqual(.itemNotFound, error as? CloudProviderError)
		}
		let actualCachedVault = try vaultCache.getCachedVault(withVaultUID: vaultUID)
		let expectedCachedVault = CachedVault(vaultUID: vaultUID, masterkeyFileData: defaultCachedVault.masterkeyFileData, vaultConfigToken: updatedVaultConfigData, lastUpToDateCheck: defaultCachedVault.lastUpToDateCheck, masterkeyFileLastModifiedDate: defaultCachedVault.masterkeyFileLastModifiedDate, vaultConfigLastModifiedDate: updatedVaultConfigLastModifiedDate)
		XCTAssertEqual(expectedCachedVault, actualCachedVault)
		assertFetchItemMetadataCalledForVaultConfigAndMasterkey()
		assertDownloadedOnlyVaultConfig()
	}

	func testRefreshForNonCachedVault() async {
		await XCTAssertThrowsAsyncError(try await vaultCache.refreshVaultCache(for: vaultAccount, with: cloudProviderMock)) { error in
			guard case VaultCacheError.vaultNotFound = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}
	}

	private func downloadMock() -> @Sendable (CloudPath, URL) async throws -> CloudItemMetadata {
		let updatedMasterkeyFileData: Data = updatedMasterkeyFileData
		let updatedVaultConfigData: Data = updatedVaultConfigData
		return { cloudPath, downloadDestination in
			let data: Data
			if cloudPath.lastPathComponent == "masterkey.cryptomator" {
				data = updatedMasterkeyFileData
			} else {
				data = updatedVaultConfigData
			}
			try data.write(to: downloadDestination)
			return CloudItemMetadata(name: cloudPath.lastPathComponent, cloudPath: cloudPath, itemType: .file, lastModifiedDate: nil, size: data.count)
		}
	}

	private func defaultFetchItemMetadataMock() -> @Sendable (CloudPath) async throws -> CloudItemMetadata {
		let updatedMasterkeyFileLastModifiedDate = updatedMasterkeyFileLastModifiedDate
		let updatedVaultConfigLastModifiedDate = updatedVaultConfigLastModifiedDate
		return { cloudPath in
			if cloudPath.lastPathComponent == "masterkey.cryptomator" {
				return CloudItemMetadata(name: "masterkey.cryptomator", cloudPath: cloudPath, itemType: .file, lastModifiedDate: updatedMasterkeyFileLastModifiedDate, size: 100)
			} else {
				return CloudItemMetadata(name: "vault.cryptomator", cloudPath: cloudPath, itemType: .file, lastModifiedDate: updatedVaultConfigLastModifiedDate, size: 50)
			}
		}
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
