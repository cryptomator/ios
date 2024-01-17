//
//  GetFolderIntentHandler.swift
//  CryptomatorIntents
//
//  Created by Philipp Schmid on 20.05.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Dependencies
import Foundation
import Intents
import Promises

class GetFolderIntentHandler: NSObject, GetFolderIntentHandling {
	let vaultOptionsProvider: VaultOptionsProvider
	@Dependency(\.fileProviderConnector) private var fileProviderConnector

	init(vaultOptionsProvider: VaultOptionsProvider) {
		self.vaultOptionsProvider = vaultOptionsProvider
	}

	func handle(intent: GetFolderIntent) async -> GetFolderIntentResponse {
		guard let path = intent.path else {
			return .failure(GetFolderIntentHandlerError.missingPath)
		}
		guard let vault = intent.vault, let vaultIdentifier = vault.identifier else {
			return .failure(GetFolderIntentHandlerError.noVaultSelected)
		}
		let cloudPath = CloudPath(path)
		let domainIdentifier = NSFileProviderDomainIdentifier(rawValue: vaultIdentifier)
		let folderIdentifier: String
		do {
			folderIdentifier = try await getIdentifierForFolder(at: cloudPath, domainIdentifier: domainIdentifier)
		} catch NSFileProviderError.notAuthenticated {
			return GetFolderIntentResponse(failureReason: LocalizedString.getValue("intents.saveFile.lockedVault"))
		} catch FileProviderXPCConnectorError.domainNotFound {
			return GetFolderIntentResponse(failureReason: LocalizedString.getValue("intents.saveFile.selectedVaultNotFound"))
		} catch {
			return .failure(error)
		}
		let vaultName = vault.displayString
		let displayName = "\(vaultName):\(cloudPath.path)"
		let vaultFolder = VaultFolder(identifier: folderIdentifier, display: displayName)
		vaultFolder.vaultIdentifier = vaultIdentifier
		return .success(vaultFolder: vaultFolder)
	}

	func confirm(intent: GetFolderIntent) async -> GetFolderIntentResponse {
		guard let path = intent.path, !path.isEmpty else {
			return .failure(GetFolderIntentHandlerError.missingPath)
		}
		if intent.vault == nil || intent.vault?.identifier == nil {
			return .failure(GetFolderIntentHandlerError.noVaultSelected)
		}
		return GetFolderIntentResponse(code: .success, userActivity: nil)
	}

	@available(iOSApplicationExtension 14.0, *)
	func provideVaultOptionsCollection(for intent: GetFolderIntent) async throws -> INObjectCollection<Vault> {
		return try await vaultOptionsProvider.provideVaultOptionsCollection()
	}

	@available(iOS, introduced: 13.0, deprecated: 14.0, message: "")
	func provideVaultOptions(for intent: GetFolderIntent, with completion: @escaping ([Vault]?, Error?) -> Void) {
		vaultOptionsProvider.provideVaultOptions(with: completion)
	}

	// MARK: Internal

	private func getIdentifierForFolder(at cloudPath: CloudPath, domainIdentifier: NSFileProviderDomainIdentifier) async throws -> String {
		let getXPCPromise: Promise<XPC<FileImporting>> = fileProviderConnector.getXPC(serviceName: .fileImporting, domainIdentifier: domainIdentifier)
		return try await withCheckedThrowingContinuation({ continuation in
			getXPCPromise.then { xpc in
				xpc.proxy.getIdentifierForItem(at: cloudPath.path)
			}.then {
				continuation.resume(returning: $0 as String)
			}.catch {
				continuation.resume(throwing: $0)
			}.always { [fileProviderConnector] in
				fileProviderConnector.invalidateXPC(getXPCPromise)
			}
		})
	}
}

extension GetFolderIntentResponse {
	static func success(vaultFolder: VaultFolder) -> GetFolderIntentResponse {
		let response = GetFolderIntentResponse(code: .success, userActivity: nil)
		response.vaultFolder = vaultFolder
		return response
	}

	static func failure(_ error: Error) -> GetFolderIntentResponse {
		return GetFolderIntentResponse(error: error)
	}

	convenience init(error: Error) {
		self.init(failureReason: error.localizedDescription)
	}

	convenience init(failureReason: String) {
		self.init(code: .failure, userActivity: nil)
		self.failureReason = failureReason
	}
}
