//
//  VaultPasswordVerifying.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 04.08.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation

protocol VaultPasswordVerifying {
	func verifiedVaultPassword()
	func cancel()
}
