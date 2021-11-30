//
//  VaultNaming.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 17.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import UIKit

protocol VaultNaming: AnyObject {
	func setVaultName(_ name: String)
}
