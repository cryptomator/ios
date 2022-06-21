//
//  LockVaultIntentHandler.swift
//  CryptomatorIntents
//
//  Created by Philipp Schmid on 17.06.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCommonCore
import Foundation
import Intents
import Promises

class LockVaultIntentHandler: NSObject, LockVaultIntentHandling {
	private let vaultAccountManager: VaultAccountManager
	private let cloudProviderAccountManager: CloudProviderAccountManager

	override convenience init() {
		LockVaultIntentHandler.oneTimeSetup()
		self.init(vaultAccountManager: VaultAccountDBManager.shared, cloudProviderAccountManager: CloudProviderAccountDBManager.shared)
	}

	init(vaultAccountManager: VaultAccountManager, cloudProviderAccountManager: CloudProviderAccountManager) {
		self.vaultAccountManager = vaultAccountManager
		self.cloudProviderAccountManager = cloudProviderAccountManager
	}

	func handle(intent: LockVaultIntent) async -> LockVaultIntentResponse {
		guard let vaultIdentifier = intent.vault?.identifier else {
			return .failure(GetFolderIntentHandlerError.noVaultSelected)
		}
		let domainIdentifier = NSFileProviderDomainIdentifier(rawValue: vaultIdentifier)
		do {
			try await lockVault(with: domainIdentifier)
		} catch {
			return .failure(error)
		}
		return .success()
	}

	@available(iOS, introduced: 13.0, deprecated: 14.0, message: "")
	func provideVaultOptions(for intent: LockVaultIntent, with completion: @escaping ([Vault]?, Error?) -> Void) {
		do {
			let vaultAccounts = try vaultAccountManager.getAllAccounts()
			let vaults: [Vault] = vaultAccounts.map {
				return Vault(identifier: $0.vaultUID, display: $0.vaultName)
			}
			completion(vaults, nil)
		} catch {
			completion(nil, error)
		}
	}

	@available(iOSApplicationExtension 14.0, *)
	func provideVaultOptionsCollection(for intent: LockVaultIntent) async throws -> INObjectCollection<Vault> {
		let vaultAccounts = try vaultAccountManager.getAllAccounts()
		let vaults: [Vault] = try vaultAccounts.map {
			let cloudProviderType = try cloudProviderAccountManager.getCloudProviderType(for: $0.delegateAccountUID)
			return Vault(identifier: $0.vaultUID,
			             display: $0.vaultName,
			             subtitle: $0.vaultPath.path,
			             image: .init(type: cloudProviderType))
		}
		return INObjectCollection(items: vaults)
	}

	// MARK: Internal

	private static var oneTimeSetup: () -> Void = {
		// Set up logger
		LoggerSetup.oneTimeSetup()
		if let dbURL = CryptomatorDatabase.sharedDBURL {
			do {
				let dbPool = try CryptomatorDatabase.openSharedDatabase(at: dbURL)
				CryptomatorDatabase.shared = try CryptomatorDatabase(dbPool)
			} catch {
				DDLogError("Open shared database at \(dbURL) failed with error: \(error)")
			}
		}
	}

	private func lockVault(with domainIdentifier: NSFileProviderDomainIdentifier) async throws {
		let getXPCPromise: Promise<XPC<VaultLocking>> = FileProviderXPCConnector.shared.getXPC(serviceName: .vaultLocking, domainIdentifier: domainIdentifier)
		return try await withCheckedThrowingContinuation({ continuation in
			getXPCPromise.then { xpc in
				xpc.proxy.gracefulLockVault(domainIdentifier: domainIdentifier)
			}.then {
				continuation.resume(returning: ())
			}.catch {
				continuation.resume(throwing: $0)
			}.always {
				FileProviderXPCConnector.shared.invalidateXPC(getXPCPromise)
			}
		})
	}
}

extension LockVaultIntentResponse {
	static func success() -> LockVaultIntentResponse {
		return LockVaultIntentResponse(code: .success, userActivity: nil)
	}

	static func failure(_ error: Error) -> LockVaultIntentResponse {
		return LockVaultIntentResponse(error: error)
	}

	convenience init(error: Error) {
		self.init(failureReason: error.localizedDescription)
	}

	convenience init(failureReason: String) {
		self.init(code: .failure, userActivity: nil)
		self.failureReason = failureReason
	}
}
