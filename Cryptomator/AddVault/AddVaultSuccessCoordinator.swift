//
//  AddVaultSuccessCoordinator.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 18.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCommonCore
import UIKit

class AddVaultSuccessCoordinator: AddVaultSuccesing, Coordinator {
	var childCoordinators = [Coordinator]()
	var navigationController: UINavigationController
	var parentCoordinator: Coordinator?

	private let vaultName: String
	private let vaultUID: String

	init(vaultName: String, vaultUID: String, navigationController: UINavigationController) {
		self.vaultName = vaultName
		self.vaultUID = vaultUID
		self.navigationController = navigationController
	}

	func start() {
		let viewModel = AddVaultSuccessViewModel(vaultName: vaultName, vaultUID: vaultUID)
		let successVC = AddVaultSuccessViewController(viewModel: viewModel)
		successVC.coordinator = self
		// Remove the previous ViewControllers so that the user cannot navigate to the previous screens.
		navigationController.setViewControllers([successVC], animated: true)
	}

	// MARK: - AddVaultSuccesing

	func done() {
		parentCoordinator?.childDidFinish(self)
		navigationController.dismiss(animated: true)
	}

	func showFilesApp(forVaultUID vaultUID: String) {
		FilesAppUtil.showFilesApp(forVaultUID: vaultUID)
		done()
	}
}
