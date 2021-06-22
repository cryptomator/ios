//
//  CloudChoosing.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 25.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore

protocol CloudChoosing: AnyObject {
	func showAccountList(for cloudProviderType: CloudProviderType)
}
