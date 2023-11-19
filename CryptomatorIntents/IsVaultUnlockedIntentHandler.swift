//
//  IsVaultUnlockedIntentHandler.swift
//  CryptomatorIntents
//
//  Created by Philipp Schmid on 22.06.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Dependencies
import FileProvider
import Foundation
import Intents
import Promises

class IsVaultUnlockedIntentHandler: NSObject, IsVaultUnlockedIntentHandling {
	let vaultOptionsProvider: VaultOptionsProvider
	@Dependency(\.fileProviderConnector) private var fileProviderConnector

	init(vaultOptionsProvider: VaultOptionsProvider) {
		self.vaultOptionsProvider = vaultOptionsProvider
	}

	func handle(intent: IsVaultUnlockedIntent) async -> IsVaultUnlockedIntentResponse {
		guard let vaultIdentifier = intent.vault?.identifier else {
			return .failure(GetFolderIntentHandlerError.noVaultSelected)
		}
		let domainIdentifier = NSFileProviderDomainIdentifier(rawValue: vaultIdentifier)
		let isUnlocked: Bool
		do {
			isUnlocked = try await getIsUnlockedVault(domainIdentifier: domainIdentifier)
		} catch {
			return .failure(error)
		}
		return .success(isUnlocked: isUnlocked)
	}

	@available(iOSApplicationExtension 14.0, *)
	func provideVaultOptionsCollection(for intent: IsVaultUnlockedIntent) async throws -> INObjectCollection<Vault> {
		return try await vaultOptionsProvider.provideVaultOptionsCollection()
	}

	@available(iOS, introduced: 13.0, deprecated: 14.0, message: "")
	func provideVaultOptions(for intent: IsVaultUnlockedIntent, with completion: @escaping ([Vault]?, Error?) -> Void) {
		vaultOptionsProvider.provideVaultOptions(with: completion)
	}

	// MARK: Internal

	private func getIsUnlockedVault(domainIdentifier: NSFileProviderDomainIdentifier) async throws -> Bool {
		let getXPCPromise: Promise<XPC<VaultLocking>> = fileProviderConnector.getXPC(serviceName: .vaultLocking, domainIdentifier: domainIdentifier)
		return try await withCheckedThrowingContinuation({ continuation in
			getXPCPromise.then { xpc in
				xpc.proxy.getIsUnlockedVault(domainIdentifier: domainIdentifier)
			}.then {
				continuation.resume(returning: $0)
			}.catch {
				continuation.resume(throwing: $0)
			}.always { [fileProviderConnector] in
				fileProviderConnector.invalidateXPC(getXPCPromise)
			}
		})
	}
}

extension IsVaultUnlockedIntentResponse {
	static func success(isUnlocked: Bool) -> IsVaultUnlockedIntentResponse {
		let response = IsVaultUnlockedIntentResponse(code: .success, userActivity: nil)
		response.isUnlocked = isUnlocked as NSNumber
		return response
	}

	static func failure(_ error: Error) -> IsVaultUnlockedIntentResponse {
		return IsVaultUnlockedIntentResponse(error: error)
	}

	convenience init(error: Error) {
		self.init(failureReason: error.localizedDescription)
	}

	convenience init(failureReason: String) {
		self.init(code: .failure, userActivity: nil)
		self.failureReason = failureReason
	}
}
