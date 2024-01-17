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
import Promises

public protocol VaultCache {
	func cache(_ entry: CachedVault) throws
	func getCachedVault(withVaultUID vaultUID: String) throws -> CachedVault
	func refreshVaultCache(for vault: VaultAccount, with provider: CloudProvider) -> Promise<Void>
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
	enum Columns: String, ColumnExpression {
		case vaultUID, masterkeyFileData, vaultConfigToken, lastUpToDateCheck, masterkeyFileLastModifiedDate, vaultConfigLastModifiedDate
	}

	public func encode(to container: inout PersistenceContainer) {
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

public class VaultDBCache: VaultCache {
	@Dependency(\.database) var database

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

	public func refreshVaultCache(for vault: VaultAccount, with provider: CloudProvider) -> Promise<Void> {
		let currentCachedVault: CachedVault
		do {
			currentCachedVault = try getCachedVault(withVaultUID: vault.vaultUID)
		} catch {
			return Promise(error)
		}
		return refreshVaultConfig(for: vault, provider: provider).then {
			self.refreshMasterkeyFileCache(for: vault, currentCachedVault: currentCachedVault, provider: provider)
		}
	}

	public func setMasterkeyFileData(_ data: Data, forVaultUID vaultUID: String, lastModifiedDate: Date?) throws {
		_ = try database.write { db in
			try CachedVault.filter(CachedVault.Columns.vaultUID == vaultUID).updateAll(db,
			                                                                           CachedVault.Columns.masterkeyFileData.set(to: data),
			                                                                           CachedVault.Columns.masterkeyFileLastModifiedDate.set(to: lastModifiedDate))
		}
	}

	private func refreshMasterkeyFileCache(for vault: VaultAccount, currentCachedVault: CachedVault, provider: CloudProvider) -> Promise<Void> {
		return fetchMasterkeyMetadataForVault(at: vault.vaultPath, provider: provider).then { metadata in
			if currentCachedVault.masterkeyFileLastModifiedDate != metadata.lastModifiedDate || metadata.lastModifiedDate == nil {
				return self.updateMasterkeyFileCacheForVault(at: vault.vaultPath, vaultUID: currentCachedVault.vaultUID, provider: provider, lastModifiedDate: metadata.lastModifiedDate)
			} else {
				return Promise(())
			}
		}
	}

	private func updateMasterkeyFileCacheForVault(at vaultPath: CloudPath, vaultUID: String, provider: CloudProvider, lastModifiedDate: Date?) -> Promise<Void> {
		let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		let masterkeyPath = vaultPath.appendingPathComponent("masterkey.cryptomator")
		return provider.downloadFile(from: masterkeyPath, to: tmpURL).then {
			let masterkeyFileData = try Data(contentsOf: tmpURL)
			try self.setMasterkeyFileData(masterkeyFileData, forVaultUID: vaultUID, lastModifiedDate: lastModifiedDate)
		}
	}

	private func fetchMasterkeyMetadataForVault(at vaultPath: CloudPath, provider: CloudProvider) -> Promise<CloudItemMetadata> {
		let masterkeyPath = vaultPath.appendingPathComponent("masterkey.cryptomator")
		return provider.fetchItemMetadata(at: masterkeyPath)
	}

	private func refreshVaultConfig(for vault: VaultAccount, provider: CloudProvider) -> Promise<Void> {
		let vaultConfigLastModifiedDate: Date?
		do {
			let cachedVault = try getCachedVault(withVaultUID: vault.vaultUID)
			vaultConfigLastModifiedDate = cachedVault.vaultConfigLastModifiedDate
		} catch {
			return Promise(error)
		}
		return fetchVaultConfigMetadataForVault(at: vault.vaultPath, provider: provider).then { metadata in
			if vaultConfigLastModifiedDate != metadata.lastModifiedDate || metadata.lastModifiedDate == nil {
				return self.updateVaultConfigCacheForVault(at: vault.vaultPath, vaultUID: vault.vaultUID, provider: provider, lastModifiedDate: metadata.lastModifiedDate)
			} else {
				return Promise(())
			}
		}.recover { error -> Void in
			switch error {
			case CloudProviderError.itemNotFound, LocalizedCloudProviderError.itemNotFound:
				try self.setVaultConfigData(nil, forVaultUID: vault.vaultUID, lastModifiedDate: nil)
			default:
				throw error
			}
		}
	}

	private func updateVaultConfigCacheForVault(at vaultPath: CloudPath, vaultUID: String, provider: CloudProvider, lastModifiedDate: Date?) -> Promise<Void> {
		let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		let vaultConfigPath = vaultPath.appendingPathComponent("vault.cryptomator")
		return provider.downloadFile(from: vaultConfigPath, to: tmpURL).then {
			let vaultConfigData = try Data(contentsOf: tmpURL)
			try self.setVaultConfigData(vaultConfigData, forVaultUID: vaultUID, lastModifiedDate: lastModifiedDate)
		}
	}

	private func fetchVaultConfigMetadataForVault(at vaultPath: CloudPath, provider: CloudProvider) -> Promise<CloudItemMetadata> {
		let vaultConfigPath = vaultPath.appendingPathComponent("vault.cryptomator")
		return provider.fetchItemMetadata(at: vaultConfigPath)
	}

	private func setVaultConfigData(_ data: Data?, forVaultUID vaultUID: String, lastModifiedDate: Date?) throws {
		_ = try database.write { db in
			try CachedVault.filter(CachedVault.Columns.vaultUID == vaultUID).updateAll(db,
			                                                                           CachedVault.Columns.vaultConfigToken.set(to: data),
			                                                                           CachedVault.Columns.vaultConfigLastModifiedDate.set(to: lastModifiedDate))
		}
	}
}
