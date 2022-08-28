//
//  WebDAVAuthenticating.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 07.04.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation

protocol WebDAVAuthenticating: AnyObject {
	func authenticated(with credential: WebDAVCredential)
	func cancel()
}
