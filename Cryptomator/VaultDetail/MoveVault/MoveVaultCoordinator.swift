//
//  MoveVaultCoordinator.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 25.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import CryptomatorFileProvider
import UIKit

class MoveVaultCoordinator: Coordinator {
	weak var parentCoordinator: Coordinator?
	lazy var childCoordinators = [Coordinator]()
	var navigationController: UINavigationController
	private let vaultInfo: VaultInfo
	private let maintenanceManager: MaintenanceManager
	private let provider: CloudProvider

	init(vaultInfo: VaultInfo, provider: CloudProvider, maintenanceManager: MaintenanceManager, navigationController: UINavigationController) {
		self.vaultInfo = vaultInfo
		self.provider = provider
		self.maintenanceManager = maintenanceManager
		self.navigationController = navigationController
	}

	func start() {
		pushMoveVaultViewController(for: CloudPath("/"))
	}

	private func pushMoveVaultViewController(for cloudPath: CloudPath) {
		let provider: CloudProvider
		do {
			provider = try CloudProviderDBManager.shared.getProvider(with: vaultInfo.delegateAccountUID)

		} catch {
			handleError(error, for: navigationController)
			return
		}
		let viewModel = MoveVaultViewModel(provider: provider, currentFolderChoosingCloudPath: cloudPath, vaultInfo: vaultInfo, maintenanceManager: maintenanceManager)
		let moveVaultViewController = MoveVaultViewController(viewModel: viewModel)
		moveVaultViewController.title = vaultInfo.vaultName
		moveVaultViewController.coordinator = self
		navigationController.pushViewController(moveVaultViewController, animated: true)
	}
}

extension MoveVaultCoordinator: FolderChoosing {
	func handleError(error: Error) {}

	func showItems(for path: CloudPath) {
		pushMoveVaultViewController(for: path)
	}

	func close() {
		popBackToFirstNonMoveVaultViewController()
		parentCoordinator?.childDidFinish(self)
	}

	func chooseItem(_ item: Item) {
		close()
	}

	func showCreateNewFolder(parentPath: CloudPath) {
		let modalNavigationController = BaseNavigationController()
		let child = AuthenticatedFolderCreationCoordinator(navigationController: modalNavigationController, provider: provider, parentPath: parentPath)
		child.parentCoordinator = self
		childCoordinators.append(child)
		navigationController.topViewController?.present(modalNavigationController, animated: true)
		child.start()
	}

	private func popBackToFirstNonMoveVaultViewController() {
		var viewControllers: [UIViewController] = navigationController.viewControllers
		viewControllers = viewControllers.reversed()
		for currentViewController in viewControllers where !currentViewController.isKind(of: MoveVaultViewController.self) {
			navigationController.popToViewController(currentViewController, animated: true)
			break
		}
	}
}
