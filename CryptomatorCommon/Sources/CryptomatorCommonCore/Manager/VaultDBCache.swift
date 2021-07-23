//
//  VaultDBCache.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 09.07.21.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCryptoLib
import Foundation
import GRDB

public protocol VaultCache {
	func cache(_ entry: CachedVault) throws
	func getCachedVault(withVaultUID vaultUID: String) throws -> CachedVault
	func invalidate(vaultUID: String) throws
}

public struct CachedVault: Codable {
	let vaultUID: String
	public let masterkeyFileData: Data
	let vaultConfigToken: String?
	let lastUpToDateCheck: Date
}

extension CachedVault: FetchableRecord, TableRecord, PersistableRecord {
	public static let databaseTableName = "cachedVaults"
	enum Columns: String, ColumnExpression {
		case vaultUID, masterkeyFileData, vaultConfigToken, lastUpToDateCheck
	}

	public func encode(to container: inout PersistenceContainer) {
		container[Columns.vaultUID] = vaultUID
		container[Columns.masterkeyFileData] = masterkeyFileData
		container[Columns.vaultConfigToken] = vaultConfigToken
		container[Columns.lastUpToDateCheck] = lastUpToDateCheck
	}
}

public enum VaultCacheError: Error {
	case vaultNotFound
}

public class VaultDBCache: VaultCache {
	private let dbWriter: DatabaseWriter

	public init(dbWriter: DatabaseWriter) {
		self.dbWriter = dbWriter
	}

	public func cache(_ entry: CachedVault) throws {
		try dbWriter.write({ db in
			try entry.save(db)
		})
	}

	public func getCachedVault(withVaultUID vaultUID: String) throws -> CachedVault {
		try dbWriter.read({ db in
			guard let cachedVault = try CachedVault.fetchOne(db, key: vaultUID) else {
				throw VaultCacheError.vaultNotFound
			}
			return cachedVault
		})
	}

	public func invalidate(vaultUID: String) throws {
		_ = try dbWriter.write({ db in
			try CachedVault.deleteOne(db, key: vaultUID)
		})
	}
}
