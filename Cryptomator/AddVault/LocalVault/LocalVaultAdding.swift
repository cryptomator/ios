//
//  LocalVaultAdding.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 28.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import UIKit

protocol LocalVaultAdding {
	func validationFailed(with error: Error, at viewController: UIViewController)
	func showPasswordScreen(for result: LocalFileSystemAuthenticationResult)
}
