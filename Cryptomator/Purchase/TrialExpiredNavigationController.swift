//
//  TrialExpiredNavigationController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 03.12.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Foundation

class TrialExpiredNavigationController: BaseNavigationController {
	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		CryptomatorUserDefaults.shared.showedTrialExpiredAtStartup = true
	}
}
