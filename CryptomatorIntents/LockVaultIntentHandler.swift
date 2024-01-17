//
//  LockVaultIntentHandler.swift
//  CryptomatorIntents
//
//  Created by Philipp Schmid on 17.06.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCommonCore
import Dependencies
import Foundation
import Intents
import Promises

class LockVaultIntentHandler: NSObject, LockVaultIntentHandling {
	let vaultOptionsProvider: VaultOptionsProvider
	@Dependency(\.fileProviderConnector) private var fileProviderConnector

	init(vaultOptionsProvider: VaultOptionsProvider) {
		self.vaultOptionsProvider = vaultOptionsProvider
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
		vaultOptionsProvider.provideVaultOptions(with: completion)
	}

	@available(iOSApplicationExtension 14.0, *)
	func provideVaultOptionsCollection(for intent: LockVaultIntent) async throws -> INObjectCollection<Vault> {
		return try await vaultOptionsProvider.provideVaultOptionsCollection()
	}

	// MARK: Internal

	private func lockVault(with domainIdentifier: NSFileProviderDomainIdentifier) async throws {
		let getXPCPromise: Promise<XPC<VaultLocking>> = fileProviderConnector.getXPC(serviceName: .vaultLocking, domainIdentifier: domainIdentifier)
		return try await withCheckedThrowingContinuation({ continuation in
			getXPCPromise.then { xpc in
				xpc.proxy.gracefulLockVault(domainIdentifier: domainIdentifier)
			}.then {
				continuation.resume(returning: ())
			}.catch {
				continuation.resume(throwing: $0)
			}.always { [fileProviderConnector] in
				fileProviderConnector.invalidateXPC(getXPCPromise)
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
