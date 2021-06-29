//
//  LocalFileSystemAuthenticating.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 21.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Foundation

protocol LocalFileSystemAuthenticating {
	func authenticated(credential: LocalFileSystemCredential)
}
