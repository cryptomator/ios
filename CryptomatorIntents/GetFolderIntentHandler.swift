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
import Foundation
import Intents
import Promises

class GetFolderIntentHandler: NSObject, GetFolderIntentHandling {
	private let vaultAccountManager: VaultAccountManager
	private let cloudProviderAccountManager: CloudProviderAccountManager

	override convenience init() {
		GetFolderIntentHandler.oneTimeSetup()
		self.init(vaultAccountManager: VaultAccountDBManager.shared, cloudProviderAccountManager: CloudProviderAccountDBManager.shared)
	}

	init(vaultAccountManager: VaultAccountManager, cloudProviderAccountManager: CloudProviderAccountManager) {
		self.vaultAccountManager = vaultAccountManager
		self.cloudProviderAccountManager = cloudProviderAccountManager
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

	@available(iOS, introduced: 13.0, deprecated: 14.0, message: "")
	func provideVaultOptions(for intent: GetFolderIntent, with completion: @escaping ([Vault]?, Error?) -> Void) {
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

	private func getIdentifierForFolder(at cloudPath: CloudPath, domainIdentifier: NSFileProviderDomainIdentifier) async throws -> String {
		let getXPCPromise: Promise<XPC<FileImporting>> = FileProviderXPCConnector.shared.getXPC(serviceName: .fileImporting, domainIdentifier: domainIdentifier)
		return try await withCheckedThrowingContinuation({ continuation in
			getXPCPromise.then { xpc in
				xpc.proxy.getIdentifierForItem(at: cloudPath.path)
			}.then {
				continuation.resume(returning: $0 as String)
			}.catch {
				continuation.resume(throwing: $0)
			}.always {
				FileProviderXPCConnector.shared.invalidateXPC(getXPCPromise)
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
