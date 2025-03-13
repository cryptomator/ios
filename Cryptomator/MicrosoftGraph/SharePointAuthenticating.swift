//
//  SharePointAuthenticating.swift
//  Cryptomator
//
//  Created by Majid Achhoud on 03.12.24.
//  Copyright © 2024 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import UIKit

protocol SharePointAuthenticating: AnyObject {
	func setSiteURL(_ siteURL: URL, from viewController: UIViewController)
	func authenticated(_ credential: SharePointCredential) throws
	func cancel()
}
