//
//  WebDAVAuthenticating.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 07.04.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation
import UIKit

protocol WebDAVAuthenticating: AnyObject {
	func authenticated(with credential: WebDAVCredential)
	func handleUntrustedCertificate(_ certificate: TLSCertificate, url: URL, for viewController: WebDAVAuthenticationViewController, viewModel: WebDAVAuthenticationViewModelProtocol)
	func handleInsecureConnection(for viewController: WebDAVAuthenticationViewController, viewModel: WebDAVAuthenticationViewModelProtocol)
	func cancel()
}
