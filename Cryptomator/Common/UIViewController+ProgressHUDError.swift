//
//  UIViewController+ProgressHUDError.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 05.11.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import UIKit

extension UIViewController {
	func handleError(_ error: Error, coordinator: Coordinator?, progressHUD: ProgressHUD) {
		progressHUD.dismiss(animated: true).then {
			coordinator?.handleError(error, for: self)
		}
	}
}
