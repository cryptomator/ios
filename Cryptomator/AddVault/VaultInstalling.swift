//
//  VaultInstalling.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 18.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation

protocol VaultInstalling {
	func showSuccessfullyAddedVault(withName name: String, vaultUID: String)
}
