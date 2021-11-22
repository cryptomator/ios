//
//  OpenExistingLegacyVaultPasswordViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 15.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Foundation
import Promises

class OpenExistingLegacyVaultPasswordViewModel: OpenExistingVaultPasswordViewModel {
	override func addVault() -> Promise<Void> {
		return VaultDBManager.shared.createLegacyFromExisting(withVaultUID: vaultUID, delegateAccountUID: account.accountUID, vaultItem: vault, password: password, storePasswordInKeychain: false)
	}
}
