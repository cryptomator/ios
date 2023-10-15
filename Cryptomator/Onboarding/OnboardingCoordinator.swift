//
//  OnboardingCoordinator.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 08.09.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Dependencies
import Foundation
import UIKit

class OnboardingCoordinator: Coordinator {
	var childCoordinators = [Coordinator]()
	var navigationController: UINavigationController
	@Dependency(\.fullVersionChecker) private var fullVersionChecker

	init(navigationController: UINavigationController) {
		self.navigationController = navigationController
	}

	func start() {
		let onboardingViewController = OnboardingViewController(viewModel: OnboardingViewModel())
		onboardingViewController.coordinator = self
		navigationController.pushViewController(onboardingViewController, animated: false)
	}

	func showIAP() {
		guard !fullVersionChecker.isFullVersion else {
			navigationController.dismiss(animated: true)
			return
		}
		let child = PurchaseCoordinator(navigationController: navigationController)
		childCoordinators.append(child) // TODO: remove missing?
		child.start()
	}
}
