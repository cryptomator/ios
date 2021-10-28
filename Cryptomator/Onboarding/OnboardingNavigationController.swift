//
//  OnboardingNavigationController.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 23.09.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Foundation

class OnboardingNavigationController: BaseNavigationController {
	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		CryptomatorUserDefaults.shared.showOnboardingAtStartup = false
	}
}
