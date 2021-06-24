//
//  CreateNewVaultCoordinator.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 17.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import UIKit

class CreateNewVaultCoordinator: AccountListing, CloudChoosing, Coordinator {
	var navigationController: UINavigationController
	var childCoordinators = [Coordinator]()
	weak var parentCoordinator: Coordinator?

	private let vaultName: String

	init(navigationController: UINavigationController, vaultName: String) {
		self.navigationController = navigationController
		self.vaultName = vaultName
	}

	func start() {
		let viewModel = ChooseCloudViewModel(clouds: [.dropbox, .googleDrive, .oneDrive, .webDAV, .localFileSystem], headerTitle: NSLocalizedString("addVault.createNewVault.chooseCloud.header", comment: ""))
		let chooseCloudVC = ChooseCloudViewController(viewModel: viewModel)
		chooseCloudVC.title = NSLocalizedString("addVault.createNewVault.title", comment: "")
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
		let child = AuthenticatedCreateNewVaultCoordinator(navigationController: navigationController, provider: provider, account: account, vaultName: vaultName)
		childCoordinators.append(child)
		child.parentCoordinator = self
		child.start()
	}

	func showEdit(for account: AccountInfo) {}

	func close() {
		navigationController.dismiss(animated: true)
		parentCoordinator?.childDidFinish(self)
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
		let child = AuthenticatedCreateNewVaultCoordinator(navigationController: navigationController, provider: provider, account: account, vaultName: vaultName)
		childCoordinators.append(child)
		child.parentCoordinator = self

		let viewModel = CreateNewLocalVaultViewModel(rootFolderName: credential.rootURL.lastPathComponent, vaultName: vaultName, provider: provider)
		let chooseFolderVC = CreateNewLocalVaultViewController(with: viewModel)
		chooseFolderVC.coordinator = child
		navigationController.pushViewController(chooseFolderVC, animated: true)
	}
}

private class AuthenticatedCreateNewVaultCoordinator: FolderChoosing, VaultInstalling, Coordinator {
	var navigationController: UINavigationController
	var childCoordinators = [Coordinator]()
	weak var parentCoordinator: CreateNewVaultCoordinator?

	let provider: CloudProvider
	let account: CloudProviderAccount
	let vaultName: String

	init(navigationController: UINavigationController, provider: CloudProvider, account: CloudProviderAccount, vaultName: String) {
		self.navigationController = navigationController
		self.provider = provider
		self.account = account
		self.vaultName = vaultName
	}

	func start() {
		showItems(for: CloudPath("/"))
	}

	// MARK: - FolderChoosing

	func showItems(for path: CloudPath) {
		let viewModel = CreateNewVaultChooseFolderViewModel(vaultName: vaultName, cloudPath: path, provider: provider)
		let chooseFolderVC = CreateNewVaultChooseFolderViewController(with: viewModel)
		chooseFolderVC.coordinator = self
		navigationController.pushViewController(chooseFolderVC, animated: true)
	}

	func close() {
		parentCoordinator?.close()
	}

	func chooseItem(_ item: Item) {
		guard let vaultFolder = item as? Folder else {
			handleError(VaultCoordinatorError.wrongItemType, for: navigationController)
			return
		}
		let viewModel = CreateNewVaultPasswordViewModel(vaultPath: vaultFolder.path, account: account, vaultUID: UUID().uuidString)
		let passwordVC = CreateNewVaultPasswordViewController(viewModel: viewModel)
		passwordVC.coordinator = self
		navigationController.pushViewController(passwordVC, animated: true)
	}

	func showCreateNewFolder(parentPath: CloudPath) {
		let modalNavigationController = UINavigationController()
		let child = AuthenticatedFolderCreationCoordinator(navigationController: modalNavigationController, provider: provider, parentPath: parentPath)
		child.parentCoordinator = self
		childCoordinators.append(child)
		navigationController.topViewController?.present(modalNavigationController, animated: true)
		child.start()
	}

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

private class AuthenticatedFolderCreationCoordinator: FolderCreating, ChildCoordinator {
	weak var parentCoordinator: Coordinator?
	var childCoordinators = [Coordinator]()
	var navigationController: UINavigationController
	private let provider: CloudProvider
	private let parentPath: CloudPath

	init(navigationController: UINavigationController, provider: CloudProvider, parentPath: CloudPath) {
		self.navigationController = navigationController
		self.provider = provider
		self.parentPath = parentPath
	}

	func start() {
		let viewModel = CreateNewFolderViewModel(parentPath: parentPath, provider: provider)
		let createNewFolderVC = CreateNewFolderViewController(viewModel: viewModel)
		createNewFolderVC.title = NSLocalizedString("common.button.createFolder", comment: "")
		createNewFolderVC.coordinator = self
		navigationController.pushViewController(createNewFolderVC, animated: false)
	}

	func createdNewFolder(at folderPath: CloudPath) {
		navigationController.dismiss(animated: true)
		if let folderChoosingParentCoordinator = parentCoordinator as? FolderChoosing {
			folderChoosingParentCoordinator.showItems(for: folderPath)
		}
		parentCoordinator?.childDidFinish(self)
	}

	func stop() {
		navigationController.dismiss(animated: true)
		parentCoordinator?.childDidFinish(self)
	}
}
