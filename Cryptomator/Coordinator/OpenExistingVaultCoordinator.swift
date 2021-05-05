//
//  OpenExistingVaultCoordinator.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 18.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Foundation
import UIKit
class OpenExistingVaultCoordinator: AccountListing, CloudChoosing, Coordinator {
	var childCoordinators = [Coordinator]()
	var navigationController: UINavigationController
	weak var parentCoordinator: AddVaultCoordinator?

	init(navigationController: UINavigationController) {
		self.navigationController = navigationController
	}

	func start() {
		let viewModel = ChooseCloudViewModel(clouds: [.dropbox, .googleDrive, .oneDrive, .webDAV, .localFileSystem],
		                                     headerTitle: NSLocalizedString("addVault.openExistingVault.chooseCloud.header", comment: ""))
		let chooseCloudVC = ChooseCloudViewController(viewModel: viewModel)
		chooseCloudVC.title = NSLocalizedString("addVault.openExistingVault.title", comment: "")
		chooseCloudVC.coordinator = self
		navigationController.pushViewController(chooseCloudVC, animated: true)
	}

	func showAccountList(for cloudProviderType: CloudProviderType) {
		let viewModel = AccountListViewModel(with: cloudProviderType)
		let accountListVC = AccountListViewController(with: viewModel)
		accountListVC.coordinator = self
		navigationController.pushViewController(accountListVC, animated: true)
	}

	func showAddAccount(for cloudProviderType: CloudProviderType, from viewController: UIViewController) {
		let authenticator = CloudAuthenticator(accountManager: CloudProviderAccountManager.shared)
		authenticator.authenticate(cloudProviderType, from: viewController).then { account in
			let provider = try CloudProviderManager.shared.getProvider(with: account.accountUID)
			self.startFolderChooser(with: provider, account: account)
		}
	}

	func selectedAccont(_ account: AccountInfo) throws {
		let provider = try CloudProviderManager.shared.getProvider(with: account.accountUID)
		startFolderChooser(with: provider, account: account.cloudProviderAccount)
	}

	private func startFolderChooser(with provider: CloudProvider, account: CloudProviderAccount) {
		let child = AuthenticatedOpenExistingVaultCoordinator(navigationController: navigationController, provider: provider, account: account)
		childCoordinators.append(child)
		child.parentCoordinator = self
		child.start()
	}

	func showEdit(for account: AccountInfo) {}

	func close() {
		navigationController.dismiss(animated: true)
		parentCoordinator?.close()
	}
}

private class AuthenticatedOpenExistingVaultCoordinator: FolderChoosing, VaultInstallationCoordinator, AddVaultSuccesing {
	var childCoordinators = [Coordinator]()
	weak var parentCoordinator: OpenExistingVaultCoordinator?
	var navigationController: UINavigationController
	let provider: CloudProvider
	let account: CloudProviderAccount

	init(navigationController: UINavigationController, provider: CloudProvider, account: CloudProviderAccount) {
		self.navigationController = navigationController
		self.provider = provider
		self.account = account
	}

	func start() {
		showItems(for: CloudPath("/"))
	}

	// MARK: FolderChoosing

	func showItems(for path: CloudPath) {
		let viewModel = ChooseFolderViewModel(canCreateFolder: false, cloudPath: path, provider: provider)
		let chooseFolderVC = OpenExistingVaultChooseFolderViewController(with: viewModel)
		chooseFolderVC.coordinator = self
		navigationController.pushViewController(chooseFolderVC, animated: true)
	}

	func close() {
		parentCoordinator?.close()
	}

	func chooseItem(at path: CloudPath) {
		let viewModel = OpenExistingVaultPasswordViewModel(provider: provider, account: account, masterkeyPath: path, vaultID: UUID().uuidString)
		let passwordVC = OpenExistingVaultPasswordViewController(viewModel: viewModel)
		passwordVC.coordinator = self
		navigationController.pushViewController(passwordVC, animated: true)
	}

	func showCreateNewFolder(parentPath: CloudPath) {}

	// MARK: VaultInstallationCoordinator

	func showSuccessfullyAddedVault(withName name: String) {
		let successVC = AddVaultSuccessViewController(vaultName: name)
		successVC.title = NSLocalizedString("addVault.openExistingVault.title", comment: "")
		successVC.coordinator = self
		navigationController.pushViewController(successVC, animated: true)
		// Remove the previous ViewControllers so that the user cannot navigate to the previous screens.
		navigationController.viewControllers = [successVC]
	}

	// MARK: AddVaultSuccesing

	func done() {
		parentCoordinator?.childDidFinish(self)
		parentCoordinator?.close()
	}

	func showFilesApp() {}
}
