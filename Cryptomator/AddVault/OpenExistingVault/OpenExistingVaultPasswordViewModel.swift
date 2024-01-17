//
//  OpenExistingVaultPasswordViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 29.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Foundation
import Promises

protocol OpenExistingVaultPasswordViewModelProtocol: SingleSectionTableViewModel, ReturnButtonSupport {
	var vaultName: String { get }
	var vaultUID: String { get }
	var enableVerifyButton: AnyPublisher<Bool, Never> { get }
	func addVault() -> Promise<Void>
}

class OpenExistingVaultPasswordViewModel: OpenExistingLegacyVaultPasswordViewModel {
	let downloadedVaultConfig: DownloadedVaultConfig

	init(provider: CloudProvider, account: CloudProviderAccount, vault: VaultItem, vaultUID: String, downloadedVaultConfig: DownloadedVaultConfig, downloadedMasterkeyFile: DownloadedMasterkeyFile) {
		self.downloadedVaultConfig = downloadedVaultConfig
		super.init(provider: provider,
		           account: account,
		           vault: vault,
		           vaultUID: vaultUID,
		           downloadedMasterkeyFile: downloadedMasterkeyFile)
	}

	override func addVault() -> Promise<Void> {
		return VaultDBManager.shared.createFromExisting(withVaultUID: vaultUID, delegateAccountUID: account.accountUID, downloadedVaultConfig: downloadedVaultConfig, downloadedMasterkey: downloadedMasterkeyFile, vaultItem: vault, password: password)
	}
}
