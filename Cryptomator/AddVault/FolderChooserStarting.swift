//
//  FolderChooserStarting.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 04.03.25.
//  Copyright © 2025 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore

protocol FolderChooserStarting: AnyObject {
	func startFolderChooser(with provider: CloudProvider, account: CloudProviderAccount)
}
