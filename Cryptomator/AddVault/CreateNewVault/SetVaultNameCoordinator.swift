//
//  SetVaultNameCoordinator.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 17.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import UIKit

protocol VaultNaming: AnyObject {
	func setVaultName(_ name: String)
}

class SetVaultNameCoordinator: VaultNaming, Coordinator {
	var childCoordinators = [Coordinator]()
	var navigationController: UINavigationController

	init(navigationController: UINavigationController) {
		self.navigationController = navigationController
	}

	func start() {
		let viewModel = SetVaultNameViewModel()
		let setVaultNameVC = SetVaultNameViewController(viewModel: viewModel)
		setVaultNameVC.title = LocalizedString.getValue("addVault.createNewVault.title")
		setVaultNameVC.coordinator = self
		navigationController.pushViewController(setVaultNameVC, animated: true)
	}

	func setVaultName(_ name: String) {
		let createNewVaultCoordinator = CreateNewVaultCoordinator(navigationController: navigationController, vaultName: name)
		createNewVaultCoordinator.parentCoordinator = self
		childCoordinators.append(createNewVaultCoordinator)
		createNewVaultCoordinator.start()
	}
}
