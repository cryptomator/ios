//
//  S3Authenticating.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 28.06.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation

protocol S3Authenticating {
	func authenticated(with credential: S3Credential)
	func cancel()
}
