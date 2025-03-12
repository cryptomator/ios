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
	func sharePointURLSet(_ sharePointURL: URL, from viewController: UIViewController)
	func driveSelected(_ drive: MicrosoftGraphDrive, for sharePointURL: URL, with credential: MicrosoftGraphCredential) throws
	func cancel()
}
