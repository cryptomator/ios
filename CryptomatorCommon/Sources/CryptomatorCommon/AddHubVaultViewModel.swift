//
//  AddHubVaultViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 21.07.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import AppAuthCore
import CryptoKit
import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import CryptomatorCryptoLib
import FileProvider
import Foundation
import JOSESwift
import Promises

class AddHubVaultViewModel: HubVaultViewModel, HubVaultAdding {
	let downloadedVaultConfig: DownloadedVaultConfig
	let vaultItem: VaultItem
	let vaultManager: VaultManager
	let delegateAccountUID: String
	let vaultUID: String
	private weak var addHubVaultCoordinator: AddHubVaultCoordinator?

	init(downloadedVaultConfig: DownloadedVaultConfig, vaultItem: VaultItem, vaultUID: String, delegateAccountUID: String, vaultManager: VaultManager = VaultDBManager.shared, coordinator: (HubVaultCoordinator & AddHubVaultCoordinator)? = nil) {
		self.downloadedVaultConfig = downloadedVaultConfig
		self.vaultItem = vaultItem
		self.vaultUID = vaultUID
		self.delegateAccountUID = delegateAccountUID
		self.vaultManager = vaultManager
		self.addHubVaultCoordinator = coordinator
		super.init(initialState: .detectedVault, vaultConfig: downloadedVaultConfig.vaultConfig, coordinator: coordinator)
	}

	func login() {
		error = nil
		let vaultConfig = downloadedVaultConfig.vaultConfig
		guard let hubConfig = vaultConfig.hub else {
			error = AddHubVaultViewModelError.missingHubConfig
			return
		}
		Task {
			do {
				guard let authState = try await addHubVaultCoordinator?.authenticate(with: hubConfig) else {
					await setError(to: AddHubVaultViewModelError.missingAuthState)
					return
				}
				self.authState = authState
				await continueToAccessCheck()
			} catch {
				await setError(to: error)
			}
		}
	}

	override func receivedExistingKey(jwe: JWE, privateKey: P384.KeyAgreement.PrivateKey, hubAccount: HubAccount) async {
		addVault(jwe: jwe, privateKey: privateKey, hubAccount: hubAccount)
	}

	private func addVault(jwe: JWE, privateKey: P384.KeyAgreement.PrivateKey, hubAccount: HubAccount) {
		vaultManager.addExistingHubVault(vaultUID: vaultUID,
		                                 delegateAccountUID: delegateAccountUID,
		                                 hubUserID: hubAccount.userID,
		                                 jweData: jwe.compactSerializedData,
		                                 privateKey: privateKey,
		                                 vaultItem: vaultItem,
		                                 downloadedVaultConfig: downloadedVaultConfig).then {
			self.addHubVaultCoordinator?.addedVault(withName: self.vaultItem.name, vaultUID: self.vaultUID)
		}.catch { error in
			Task {
				await self.setError(to: error)
			}
		}
	}
}
