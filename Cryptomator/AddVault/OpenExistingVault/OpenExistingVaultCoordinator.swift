//
//  OpenExistingVaultCoordinator.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 18.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
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
		if cloudProviderType == .localFileSystem {
			startLocalFileSystemAuthenticationFlow()
		} else {
			let viewModel = AccountListViewModel(with: cloudProviderType)
			let accountListVC = AccountListViewController(with: viewModel)
			accountListVC.coordinator = self
			navigationController.pushViewController(accountListVC, animated: true)
		}
	}

	func showAddAccount(for cloudProviderType: CloudProviderType, from viewController: UIViewController) {
		let authenticator = CloudAuthenticator(accountManager: CloudProviderAccountDBManager.shared)
		authenticator.authenticate(cloudProviderType, from: viewController).then { account in
			let provider = try CloudProviderDBManager.shared.getProvider(with: account.accountUID)
			self.startFolderChooser(with: provider, account: account)
		}
	}

	func selectedAccont(_ account: AccountInfo) throws {
		let provider = try CloudProviderDBManager.shared.getProvider(with: account.accountUID)
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

	// MARK: - LocalFileSystemProvider Flow

	private func startLocalFileSystemAuthenticationFlow() {
		LocalFileSystemAuthenticator.authenticateForOpenExistingVault(from: navigationController, onCompletion: { credential in
			let account = CloudProviderAccount(accountUID: credential.identifier, cloudProviderType: .localFileSystem)
			do {
				try CloudProviderAccountDBManager.shared.saveNewAccount(account)
			} catch {
				DDLogError("startLocalFileSystemAuthenticationFlow saveNewAccount failed with:\(error)")
			}
			self.startAuthenticatedLocalFileSystemOpenExistingVaultFlow(with: credential, account: account)
		})
	}

	private func startAuthenticatedLocalFileSystemOpenExistingVaultFlow(with credential: LocalFileSystemCredential, account: CloudProviderAccount) {
		let provider = LocalFileSystemProvider(rootURL: credential.rootURL)
		let child = AuthenticatedOpenExistingVaultCoordinator(navigationController: navigationController, provider: provider, account: account)
		childCoordinators.append(child)
		child.parentCoordinator = self

		let viewModel = OpenExistingLocalVaultViewModel(rootFolderName: credential.rootURL.lastPathComponent, provider: provider)
		let chooseFolderVC = OpenExistingVaultChooseFolderViewController(with: viewModel)
		chooseFolderVC.coordinator = child
		navigationController.pushViewController(chooseFolderVC, animated: true)
	}
}

private class AuthenticatedOpenExistingVaultCoordinator: VaultInstalling, FolderChoosing, Coordinator {
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
		guard let vaultItem = item as? VaultDetailItem else {
			handleError(VaultCoordinatorError.wrongItemType, for: navigationController)
			return
		}
		if vaultItem.isLegacyVault {
			viewModel = OpenExistingLegacyVaultPasswordViewModel(provider: provider, account: account, vault: vaultItem, vaultID: UUID().uuidString)
		} else {
			viewModel = OpenExistingVaultPasswordViewModel(provider: provider, account: account, vault: vaultItem, vaultUID: UUID().uuidString)
		}

		let passwordVC = OpenExistingVaultPasswordViewController(viewModel: viewModel)
		passwordVC.coordinator = self
		navigationController.pushViewController(passwordVC, animated: true)
	}

	func showCreateNewFolder(parentPath: CloudPath) {}

	func handleError(error: Error) {
		navigationController.popViewController(animated: true)
		if let topViewController = navigationController.topViewController {
			handleError(error, for: topViewController)
		}
	}

	// MARK: - VaultInstalling

	func showSuccessfullyAddedVault(withName name: String, vaultUID: String) {
		let child = AddVaultSuccessCoordinator(vaultName: name, vaultUID: vaultUID, navigationController: navigationController)
		child.parentCoordinator = self
		childCoordinators.append(child)
		child.start()
	}
}
