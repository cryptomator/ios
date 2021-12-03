//
//  MainCoordinator.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 04.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Promises
import UIKit

class MainCoordinator: NSObject, Coordinator, UINavigationControllerDelegate {
	var navigationController: UINavigationController
	var childCoordinators = [Coordinator]()

	init(navigationController: UINavigationController) {
		self.navigationController = navigationController
	}

	func start() {
		let vaultListViewController = VaultListViewController(with: VaultListViewModel())
		vaultListViewController.coordinator = self
		navigationController.pushViewController(vaultListViewController, animated: false)
	}

	func showOnboarding() {
		let modalNavigationController = OnboardingNavigationController()
		modalNavigationController.isModalInPresentation = true
		let child = OnboardingCoordinator(navigationController: modalNavigationController)
		childCoordinators.append(child)
		navigationController.topViewController?.present(modalNavigationController, animated: true)
		child.start()
	}

	func showTrialExpired() {
		let modalNavigationController = TrialExpiredNavigationController()
		let child = TrialExpiredCoordinator(navigationController: modalNavigationController)
		childCoordinators.append(child)
		navigationController.topViewController?.present(modalNavigationController, animated: true)
		child.start()
	}

	func addVault() {
		let modalNavigationController = BaseNavigationController()
		let child = AddVaultCoordinator(navigationController: modalNavigationController)
		child.parentCoordinator = self
		childCoordinators.append(child)
		navigationController.topViewController?.present(modalNavigationController, animated: true)
		child.start()
	}

	func showSettings() {
		let modalNavigationController = BaseNavigationController()
		let child = SettingsCoordinator(navigationController: modalNavigationController)
		child.parentCoordinator = self
		childCoordinators.append(child)
		navigationController.topViewController?.present(modalNavigationController, animated: true)
		child.start()
	}

	func showVaultDetail(for vaultInfo: VaultInfo) {
		let child = VaultDetailCoordinator(vaultInfo: vaultInfo, navigationController: navigationController)
		childCoordinators.append(child)
		child.start()
	}

	// MARK: - UINavigationControllerDelegate

	func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
		// Read the view controller we’re moving from.
		guard let fromViewController = navigationController.transitionCoordinator?.viewController(forKey: .from) else {
			return
		}

		// Check whether our view controller array already contains that view controller. If it does it means we’re pushing a different view controller on top rather than popping it, so exit.
		if navigationController.viewControllers.contains(fromViewController) {
			return
		}
	}
}
