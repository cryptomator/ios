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
	var navigationController: UINavigationController
	var childCoordinators = [Coordinator]()
	weak var parentCoordinator: AddVaultCoordinator?

	init(navigationController: UINavigationController) {
		self.navigationController = navigationController
	}

	func start() {
		let viewModel = ChooseCloudViewModel(clouds: [.dropbox, .googleDrive, .oneDrive, .webDAV, .localFileSystem], headerTitle: NSLocalizedString("addVault.openExistingVault.chooseCloud.header", comment: ""))
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

private class AuthenticatedOpenExistingVaultCoordinator: VaultInstallationCoordinator, FolderChoosing, AddVaultSuccesing {
	var navigationController: UINavigationController
	var childCoordinators = [Coordinator]()
	weak var parentCoordinator: OpenExistingVaultCoordinator?

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

	// MARK: - FolderChoosing

	func showItems(for path: CloudPath) {
		let viewModel = ChooseFolderViewModel(canCreateFolder: false, cloudPath: path, provider: provider)
		let chooseFolderVC = OpenExistingVaultChooseFolderViewController(with: viewModel)
		chooseFolderVC.coordinator = self
		navigationController.pushViewController(chooseFolderVC, animated: true)
	}

	func close() {
		parentCoordinator?.close()
	}

	func chooseItem(_ item: Item) {
		let viewModel: OpenExistingVaultPasswordViewModelProtocol
		switch item.type {
		case .vaultConfig:
			viewModel = OpenExistingVaultPasswordViewModel(provider: provider, account: account, vaultConfigPath: item.path, vaultUID: UUID().uuidString)
		case .legacyMasterkey:
			viewModel = OpenExistingLegacyVaultPasswordViewModel(provider: provider, account: account, masterkeyPath: item.path, vaultID: UUID().uuidString)
		default:
			handleError(ExistingVaultCoordinatorError.wrongItemType, for: navigationController)
			return
		}
		let passwordVC = OpenExistingVaultPasswordViewController(viewModel: viewModel)
		passwordVC.coordinator = self
		navigationController.pushViewController(passwordVC, animated: true)
	}

	func showCreateNewFolder(parentPath: CloudPath) {}

	// MARK: - VaultInstallationCoordinator

	func showSuccessfullyAddedVault(withName name: String, vaultUID: String) {
		let viewModel = AddVaultSuccessViewModel(vaultName: name, vaultUID: vaultUID)
		let successVC = AddVaultSuccessViewController(viewModel: viewModel)
		successVC.title = NSLocalizedString("addVault.openExistingVault.title", comment: "")
		successVC.coordinator = self
		navigationController.pushViewController(successVC, animated: true)
		// Remove the previous ViewControllers so that the user cannot navigate to the previous screens.
		navigationController.viewControllers = [successVC]
	}

	// MARK: - AddVaultSuccesing

	func done() {
		parentCoordinator?.childDidFinish(self)
		parentCoordinator?.close()
	}

	func showFilesApp(forVaultUID vaultUID: String) {
		guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: CryptomatorConstants.appGroupName) else {
			print("containerURL is nil")
			return
		}
		let url = containerURL.appendingPathComponent("File Provider Storage").appendingPathComponent(vaultUID)
		guard let sharedDocumentsURL = changeSchemeToSharedDocuments(for: url) else {
			print("Conversion to shared documents url failed")
			return
		}
		UIApplication.shared.open(sharedDocumentsURL)
		parentCoordinator?.childDidFinish(self)
		parentCoordinator?.close()
	}

	private func changeSchemeToSharedDocuments(for url: URL) -> URL? {
		var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
		comps?.scheme = "shareddocuments"
		return comps?.url
	}
}

enum ExistingVaultCoordinatorError: Error {
	case wrongItemType
}
