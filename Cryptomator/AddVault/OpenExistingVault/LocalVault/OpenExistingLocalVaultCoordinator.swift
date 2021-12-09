//
//  OpenExistingLocalVaultCoordinator.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 29.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import UIKit

class OpenExistingLocalVaultCoordinator: LocalVaultAdding, LocalFileSystemAuthenticating, Coordinator {
	var childCoordinators = [Coordinator]()
	var navigationController: UINavigationController
	weak var parentCoordinator: OpenExistingVaultCoordinator?
	private let selectedLocalFileSystem: LocalFileSystemType

	init(navigationController: UINavigationController, selectedLocalFileSystem: LocalFileSystemType) {
		self.navigationController = navigationController
		self.selectedLocalFileSystem = selectedLocalFileSystem
	}

	func start() {
		let viewModel = OpenExistingLocalVaultViewModel(selectedLocalFileSystemType: selectedLocalFileSystem)
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
		handleError(error, for: viewController)
	}

	func showPasswordScreen(for result: LocalFileSystemAuthenticationResult) {
		parentCoordinator?.startAuthenticatedLocalFileSystemOpenExistingVaultFlow(credential: result.credential, account: result.account, item: result.item)
	}
}
