//
//  VaultDBCache.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 09.07.21.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCryptoLib
import Dependencies
import Foundation
import GRDB

public protocol VaultCache: Sendable {
	func cache(_ entry: CachedVault) throws
	func getCachedVault(withVaultUID vaultUID: String) throws -> CachedVault
	func refreshVaultCache(for vault: VaultAccount, with provider: CloudProvider) async throws
	func setMasterkeyFileData(_ data: Data, forVaultUID vaultUID: String, lastModifiedDate: Date?) throws
}

public struct CachedVault: Codable, Equatable {
	let vaultUID: String
	public let masterkeyFileData: Data
	public let vaultConfigToken: Data?
	let lastUpToDateCheck: Date
	var masterkeyFileLastModifiedDate: Date?
	var vaultConfigLastModifiedDate: Date?
}

extension CachedVault: FetchableRecord, TableRecord, PersistableRecord {
	public static let databaseTableName = "cachedVaults"
	public enum Columns: String, ColumnExpression {
		case vaultUID, masterkeyFileData, vaultConfigToken, lastUpToDateCheck, masterkeyFileLastModifiedDate, vaultConfigLastModifiedDate
	}

	public func encode(to container: inout PersistenceContainer) throws {
		container[Columns.vaultUID] = vaultUID
		container[Columns.masterkeyFileData] = masterkeyFileData
		container[Columns.vaultConfigToken] = vaultConfigToken
		container[Columns.lastUpToDateCheck] = lastUpToDateCheck
		container[Columns.masterkeyFileLastModifiedDate] = masterkeyFileLastModifiedDate
		container[Columns.vaultConfigLastModifiedDate] = vaultConfigLastModifiedDate
	}
}

public enum VaultCacheError: Error {
	case vaultNotFound
}

public final class VaultDBCache: VaultCache {
	private let databaseDependency = Dependency(\.database)
	private var database: DatabaseWriter {
		databaseDependency.wrappedValue
	}

	public init() {}

	public func cache(_ entry: CachedVault) throws {
		try database.write({ db in
			try entry.save(db)
		})
	}

	public func getCachedVault(withVaultUID vaultUID: String) throws -> CachedVault {
		try database.read({ db in
			guard let cachedVault = try CachedVault.fetchOne(db, key: vaultUID) else {
				throw VaultCacheError.vaultNotFound
			}
			return cachedVault
		})
	}

	public func refreshVaultCache(for vault: VaultAccount, with provider: CloudProvider) async throws {
		let currentCachedVault = try getCachedVault(withVaultUID: vault.vaultUID)
		try await refreshVaultConfig(for: vault, provider: provider)
		try await refreshMasterkeyFileCache(for: vault, currentCachedVault: currentCachedVault, provider: provider)
	}

	public func setMasterkeyFileData(_ data: Data, forVaultUID vaultUID: String, lastModifiedDate: Date?) throws {
		_ = try database.write { db in
			try CachedVault.filter(CachedVault.Columns.vaultUID == vaultUID).updateAll(db,
			                                                                           CachedVault.Columns.masterkeyFileData.set(to: data),
			                                                                           CachedVault.Columns.masterkeyFileLastModifiedDate.set(to: lastModifiedDate))
		}
	}

	private func refreshMasterkeyFileCache(for vault: VaultAccount, currentCachedVault: CachedVault, provider: CloudProvider) async throws {
		let metadata = try await fetchMasterkeyMetadataForVault(at: vault.vaultPath, provider: provider)
		if currentCachedVault.masterkeyFileLastModifiedDate != metadata.lastModifiedDate || metadata.lastModifiedDate == nil {
			try await updateMasterkeyFileCacheForVault(at: vault.vaultPath, vaultUID: currentCachedVault.vaultUID, provider: provider, lastModifiedDate: metadata.lastModifiedDate)
		}
	}

	private func updateMasterkeyFileCacheForVault(at vaultPath: CloudPath, vaultUID: String, provider: CloudProvider, lastModifiedDate: Date?) async throws {
		let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		let masterkeyPath = vaultPath.appendingPathComponent("masterkey.cryptomator")
		_ = try await provider.downloadFile(from: masterkeyPath, to: tmpURL)
		let masterkeyFileData = try Data(contentsOf: tmpURL)
		try setMasterkeyFileData(masterkeyFileData, forVaultUID: vaultUID, lastModifiedDate: lastModifiedDate)
	}

	private func fetchMasterkeyMetadataForVault(at vaultPath: CloudPath, provider: CloudProvider) async throws -> CloudItemMetadata {
		let masterkeyPath = vaultPath.appendingPathComponent("masterkey.cryptomator")
		return try await provider.fetchItemMetadata(at: masterkeyPath)
	}

	private func refreshVaultConfig(for vault: VaultAccount, provider: CloudProvider) async throws {
		let cachedVault = try getCachedVault(withVaultUID: vault.vaultUID)
		let vaultConfigLastModifiedDate = cachedVault.vaultConfigLastModifiedDate
		do {
			let metadata = try await fetchVaultConfigMetadataForVault(at: vault.vaultPath, provider: provider)
			if vaultConfigLastModifiedDate != metadata.lastModifiedDate || metadata.lastModifiedDate == nil {
				try await updateVaultConfigCacheForVault(at: vault.vaultPath, vaultUID: vault.vaultUID, provider: provider, lastModifiedDate: metadata.lastModifiedDate)
			}
		} catch CloudProviderError.itemNotFound, LocalizedCloudProviderError.itemNotFound {
			try setVaultConfigData(nil, forVaultUID: vault.vaultUID, lastModifiedDate: nil)
		}
	}

	private func updateVaultConfigCacheForVault(at vaultPath: CloudPath, vaultUID: String, provider: CloudProvider, lastModifiedDate: Date?) async throws {
		let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		let vaultConfigPath = vaultPath.appendingPathComponent("vault.cryptomator")
		_ = try await provider.downloadFile(from: vaultConfigPath, to: tmpURL)
		let vaultConfigData = try Data(contentsOf: tmpURL)
		try setVaultConfigData(vaultConfigData, forVaultUID: vaultUID, lastModifiedDate: lastModifiedDate)
	}

	private func fetchVaultConfigMetadataForVault(at vaultPath: CloudPath, provider: CloudProvider) async throws -> CloudItemMetadata {
		let vaultConfigPath = vaultPath.appendingPathComponent("vault.cryptomator")
		return try await provider.fetchItemMetadata(at: vaultConfigPath)
	}

	private func setVaultConfigData(_ data: Data?, forVaultUID vaultUID: String, lastModifiedDate: Date?) throws {
		_ = try database.write { db in
			try CachedVault.filter(CachedVault.Columns.vaultUID == vaultUID).updateAll(db,
			                                                                           CachedVault.Columns.vaultConfigToken.set(to: data),
			                                                                           CachedVault.Columns.vaultConfigLastModifiedDate.set(to: lastModifiedDate))
		}
	}
}
