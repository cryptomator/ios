//
//  VaultItem.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 24.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation

public protocol VaultItem {
	var name: String { get }
	var vaultPath: CloudPath { get }
}
