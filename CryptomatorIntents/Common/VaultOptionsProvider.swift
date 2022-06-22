//
//  VaultOptionsProvider.swift
//  CryptomatorIntents
//
//  Created by Philipp Schmid on 22.06.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Foundation
import Intents

struct VaultOptionsProvider {
	let vaultAccountManager: VaultAccountManager
	let cloudProviderAccountManager: CloudProviderAccountManager

	@available(iOS, introduced: 13.0, deprecated: 14.0, message: "")
	func provideVaultOptions(with completion: @escaping ([Vault]?, Error?) -> Void) {
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
	func provideVaultOptionsCollection() async throws -> INObjectCollection<Vault> {
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
}

extension VaultOptionsProvider {
	static let shared = VaultOptionsProvider(vaultAccountManager: VaultAccountDBManager.shared, cloudProviderAccountManager: CloudProviderAccountDBManager.shared)
}
