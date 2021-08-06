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
		let viewModel = VaultDetailViewModel(vaultInfo: vaultInfo)
		let vaultDetailViewController = VaultDetailViewController(viewModel: viewModel)
		vaultDetailViewController.coordinator = self
		navigationController.pushViewController(vaultDetailViewController, animated: true)
	}

	func unlockVault(_ vault: VaultInfo, biometryTypeName: String) -> Promise<Void> {
		let modalNavigationController = BaseNavigationController()
		let pendingAuthentication = Promise<Void>.pending()
		let child = VaultDetailUnlockCoordinator(navigationController: modalNavigationController, vault: vault, biometryTypeName: biometryTypeName, pendingAuthentication: pendingAuthentication)
		child.parentCoordinator = self
		childCoordinators.append(child)
		navigationController.topViewController?.present(modalNavigationController, animated: true)
		child.start()
		return pendingAuthentication
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
