//
//  CreateNewLocalVaultCoordinator.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 28.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import UIKit

class CreateNewLocalVaultCoordinator: LocalVaultAdding, LocalFileSystemAuthenticating, Coordinator {
	var childCoordinators = [Coordinator]()
	var navigationController: UINavigationController
	weak var parentCoordinator: CreateNewVaultCoordinator?
	private let vaultName: String
	private let selectedLocalFileSystem: LocalFileSystemType

	init(vaultName: String, navigationController: UINavigationController, selectedLocalFileSystem: LocalFileSystemType) {
		self.vaultName = vaultName
		self.selectedLocalFileSystem = selectedLocalFileSystem
		self.navigationController = navigationController
	}

	func start() {
		let viewModel = CreateNewLocalVaultViewModel(vaultName: vaultName, selectedLocalFileSystemType: selectedLocalFileSystem)
		let localFSAuthVC = AddLocalVaultViewController(viewModel: viewModel)
		localFSAuthVC.coordinator = self
		navigationController.pushViewController(localFSAuthVC, animated: true)
	}

	// MARK: - LocalFileSystemAuthenticating

	func authenticated(credential: LocalFileSystemCredential) {
		// TODO: Show Progress-HUD
	}

	// MARK: - LocalVaultAdding

	func validationFailed(with error: Error, at viewController: UIViewController) {
		// TODO: Disable Progress-HUD
		if case CreateNewLocalVaultViewModelError.detectedExistingVault = error {
			let failureVC = DetectedVaultFailureViewController()
			failureVC.title = LocalizedString.getValue("addVault.createNewVault.title")
			navigationController.pushViewController(failureVC, animated: true)
		} else {
			handleError(error, for: viewController)
		}
	}

	func showPasswordScreen(for result: LocalFileSystemAuthenticationResult) {
		parentCoordinator?.startAuthenticatedLocalFileSystemCreateNewVaultFlow(credential: result.credential, account: result.account, item: result.item)
	}
}
