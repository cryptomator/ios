//
//  AccountListing.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 20.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import UIKit

protocol AccountListing: AnyObject {
	func showAddAccount(for cloudProviderType: CloudProviderType, from viewController: UIViewController)
	func selectedAccont(_ account: AccountInfo)
	func showEdit(for account: AccountInfo)
}
