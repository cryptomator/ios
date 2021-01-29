//
//  AddVaultCoordinator.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 12.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation
import UIKit

class AddVaultCoordinator: Coordinator {
	var childCoordinators = [Coordinator]()
	var navigationController: UINavigationController
	weak var parentCoordinator: MainCoordinator?

	init(navigationController: UINavigationController) {
		self.navigationController = navigationController
	}

	func start() {
		let addVaultViewController = AddVaultViewController()
		addVaultViewController.coordinator = self
		navigationController.pushViewController(addVaultViewController, animated: false)
	}

	func createNewVault() {
		// TODO: Push to CreateNewVaultVC
	}

	func openExistingVault() {
		let child = OpenExistingVaultCoordinator(navigationController: navigationController)
		child.parentCoordinator = self
		childCoordinators.append(child)
		child.start()
	}

	func close() {
		navigationController.dismiss(animated: true)
		parentCoordinator?.childDidFinish(self)
	}
}
