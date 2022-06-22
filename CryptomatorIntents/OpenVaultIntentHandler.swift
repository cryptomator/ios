//
//  OpenVaultIntentHandler.swift
//  CryptomatorIntents
//
//  Created by Philipp Schmid on 21.06.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import Foundation
import Intents

class OpenVaultIntentHandler: NSObject, OpenVaultIntentHandling {
	let vaultOptionsProvider: VaultOptionsProvider

	init(vaultOptionsProvider: VaultOptionsProvider) {
		self.vaultOptionsProvider = vaultOptionsProvider
	}

	func handle(intent: OpenVaultIntent) async -> OpenVaultIntentResponse {
		guard let vaultIdentifier = intent.vault?.identifier else {
			return .failure(GetFolderIntentHandlerError.noVaultSelected)
		}
		let activity = NSUserActivity(activityType: "OpenVaultIntent")
		let userInfo = ["vaultUID": vaultIdentifier]
		activity.userInfo = userInfo
		return .init(code: .continueInApp, userActivity: activity)
	}

	@available(iOSApplicationExtension 14.0, *)
	func provideVaultOptionsCollection(for intent: OpenVaultIntent) async throws -> INObjectCollection<Vault> {
		return try await vaultOptionsProvider.provideVaultOptionsCollection()
	}

	@available(iOS, introduced: 13.0, deprecated: 14.0, message: "")
	func provideVaultOptions(for intent: OpenVaultIntent, with completion: @escaping ([Vault]?, Error?) -> Void) {
		vaultOptionsProvider.provideVaultOptions(with: completion)
	}
}

extension OpenVaultIntentResponse {
	static func success() -> OpenVaultIntentResponse {
		return OpenVaultIntentResponse(code: .success, userActivity: nil)
	}

	static func failure(_ error: Error) -> OpenVaultIntentResponse {
		return OpenVaultIntentResponse(error: error)
	}

	convenience init(error: Error) {
		self.init(failureReason: error.localizedDescription)
	}

	convenience init(failureReason: String) {
		self.init(code: .failure, userActivity: nil)
		self.failureReason = failureReason
	}
}
