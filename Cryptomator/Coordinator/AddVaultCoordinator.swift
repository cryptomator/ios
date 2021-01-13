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
	private let allowToCancel: Bool

	init(navigationController: UINavigationController, allowToCancel: Bool) {
		self.navigationController = navigationController
		self.allowToCancel = allowToCancel
	}

	func start() {
		let addVaultViewController = AddVaultViewController(allowToCancel: allowToCancel)
		addVaultViewController.coordinator = self
		navigationController.pushViewController(addVaultViewController, animated: false)
	}

	func createNewVault() {
		// TODO: Push to CreateNewVaultVC
	}

	func openExistingVault() {
		// TODO: Replace Prototype VC
		let webdavController = WebDAVLoginViewController()
		webdavController.coordinator = self
		navigationController.pushViewController(webdavController, animated: true)
	}

	func close() {
		navigationController.dismiss(animated: true)
		parentCoordinator?.childDidFinish(self)
	}
}
