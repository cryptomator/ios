//
//  S3CredentialManager.swift
//
//
//  Created by Philipp Schmid on 29.06.22.
//

import CryptomatorCloudAccessCore
import Dependencies
import Foundation
import GRDB

public protocol S3CredentialManagerType {
	func save(credential: S3Credential, displayName: String) throws
	func removeCredential(with identifier: String) throws
	func getDisplayName(for identifier: String) throws -> String?
	func getCredential(with identifier: String) -> S3Credential?
}

public extension S3CredentialManagerType {
	func getDisplayName(for credential: S3Credential) throws -> String? {
		return try getDisplayName(for: credential.identifier)
	}

	func removeCredential(_ credential: S3Credential) throws {
		return try removeCredential(with: credential.identifier)
	}
}

public struct S3DisplayName: Codable {
	public let id: String
	public let displayName: String
}

extension S3DisplayName: FetchableRecord, PersistableRecord {
	public static let databaseTableName = "s3DisplayNames"
	static let accountForeignKey = ForeignKey(["id"])
}

public extension CloudProviderAccount {
	static let s3DisplayName = hasOne(S3DisplayName.self, using: S3DisplayName.accountForeignKey)
}

public struct S3CredentialManager: S3CredentialManagerType {
	@Dependency(\.database) var database
	public static let shared = S3CredentialManager(keychain: CryptomatorKeychain.s3)
	let keychain: CryptomatorKeychainType

	public func save(credential: S3Credential, displayName: String) throws {
		do {
			try database.write { db in
				let entry = S3DisplayName(id: credential.identifier, displayName: displayName)
				try entry.save(db)
				try keychain.saveS3Credential(credential)
			}
		}
	}

	public func removeCredential(with identifier: String) throws {
		try database.write { db in
			try S3DisplayName.deleteOne(db, key: ["id": identifier])
			try keychain.delete(identifier)
		}
	}

	public func getDisplayName(for identifier: String) throws -> String? {
		try database.read { db in
			let entry = try S3DisplayName.fetchOne(db, key: ["id": identifier])
			return entry?.displayName
		}
	}

	public func getCredential(with identifier: String) -> S3Credential? {
		keychain.getS3Credential(identifier)
	}
}

extension S3CredentialManager {
	private static var inMemoryDB: DatabaseQueue {
		var configuration = Configuration()
		// Workaround for a SQLite regression (see https://github.com/groue/GRDB.swift/issues/1171 for more details)
		configuration.acceptsDoubleQuotedStringLiterals = true
		let inMemoryDB = DatabaseQueue(configuration: configuration)
		try? CryptomatorDatabase.migrator.migrate(inMemoryDB)
		return inMemoryDB
	}

	public static let demo = S3CredentialManager(keychain: CryptomatorKeychain(service: "s3CredentialDemo"))
}
