//
//  VaultDetailItem.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 24.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Foundation

struct VaultDetailItem: Item, VaultItem {
	var path: CloudPath {
		return vaultPath
	}

	let name: String
	let vaultPath: CloudPath
	let isLegacyVault: Bool
}
