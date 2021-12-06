//
//  OnboardingCoordinator.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 08.09.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation
import UIKit

class OnboardingCoordinator: Coordinator {
	var childCoordinators = [Coordinator]()
	var navigationController: UINavigationController

	init(navigationController: UINavigationController) {
		self.navigationController = navigationController
	}

	func start() {
		let onboardingViewController = OnboardingViewController(viewModel: OnboardingViewModel())
		onboardingViewController.coordinator = self
		navigationController.pushViewController(onboardingViewController, animated: false)
	}

	func showIAP() {
		let child = PurchaseCoordinator(navigationController: navigationController)
		childCoordinators.append(child) // TODO: remove missing?
		child.start()
	}
}
