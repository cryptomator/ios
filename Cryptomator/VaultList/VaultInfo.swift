//
//  VaultInfo.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 07.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CloudAccessPrivateCore
import CryptomatorCloudAccess
import Foundation
import GRDB

public struct VaultInfo: Decodable, FetchableRecord {
	let vaultAccount: VaultAccount
	let cloudProviderAccount: CloudProviderAccount
	private(set) var vaultListPosition: VaultListPosition

	init(vaultAccount: VaultAccount, cloudProviderAccount: CloudProviderAccount, vaultListPosition: VaultListPosition) {
		self.vaultAccount = vaultAccount
		self.cloudProviderAccount = cloudProviderAccount
		self.vaultListPosition = vaultListPosition
	}

	var vaultPath: CloudPath {
		return vaultAccount.vaultPath
	}

	var vaultUID: String {
		return vaultAccount.vaultUID
	}

	var cloudProviderType: CloudProviderType {
		return cloudProviderAccount.cloudProviderType
	}

	var delegateAccountUID: String {
		return cloudProviderAccount.accountUID
	}

	var listPosition: Int {
		get {
			vaultListPosition.position!
		}
		set {
			vaultListPosition.position = newValue
		}
	}
}
