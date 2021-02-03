//
//  MainCoordinator.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 04.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation
import UIKit

class MainCoordinator: NSObject, Coordinator, UINavigationControllerDelegate {
	var childCoordinators = [Coordinator]()

	var navigationController: UINavigationController

	init(navigationController: UINavigationController) {
		self.navigationController = navigationController
	}

	func start() {
		let vaultListViewController = VaultListViewController(with: VaultListViewModel())
		vaultListViewController.coordinator = self
		navigationController.pushViewController(vaultListViewController, animated: false)
	}

	func addVault() {
		let modalNavigationController = UINavigationController()
		let child = AddVaultCoordinator(navigationController: modalNavigationController)
		child.parentCoordinator = self
		childCoordinators.append(child)
		navigationController.topViewController?.present(modalNavigationController, animated: true)
		child.start()
	}

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
