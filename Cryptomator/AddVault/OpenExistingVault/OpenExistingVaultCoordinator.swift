//
//  OpenExistingVaultCoordinator.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 18.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import AppAuth
import CocoaLumberjackSwift
import CryptomatorCloudAccessCore
import CryptomatorCommon
import CryptomatorCommonCore
import Foundation
import Promises
import UIKit

class OpenExistingVaultCoordinator: AccountListing, CloudChoosing, DefaultShowEditAccountBehavior, Coordinator {
	var navigationController: UINavigationController
	var childCoordinators = [Coordinator]()
	weak var parentCoordinator: AddVaultCoordinator?

	init(navigationController: UINavigationController) {
		self.navigationController = navigationController
	}

	func start() {
		let viewModel = ChooseCloudViewModel(clouds: [.localFileSystem(type: .iCloudDrive), .dropbox, .googleDrive, .oneDrive, .pCloud, .webDAV(type: .custom), .s3(type: .custom), .localFileSystem(type: .custom)], headerTitle: LocalizedString.getValue("addVault.openExistingVault.chooseCloud.header"))
		let chooseCloudVC = ChooseCloudViewController(viewModel: viewModel)
		chooseCloudVC.title = LocalizedString.getValue("addVault.openExistingVault.title")
		chooseCloudVC.coordinator = self
		navigationController.pushViewController(chooseCloudVC, animated: true)
	}

	func showAccountList(for cloudProviderType: CloudProviderType) {
		if case let CloudProviderType.localFileSystem(localFileSystemType) = cloudProviderType {
			startLocalFileSystemAuthenticationFlow(for: localFileSystemType)
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

	func close() {
		navigationController.dismiss(animated: true)
		parentCoordinator?.close()
	}

	// MARK: - LocalFileSystemProvider Flow

	private func startLocalFileSystemAuthenticationFlow(for localFileSystemType: LocalFileSystemType) {
		let child = OpenExistingLocalVaultCoordinator(navigationController: navigationController, selectedLocalFileSystem: localFileSystemType)
		childCoordinators.append(child)
		child.parentCoordinator = self
		child.start()
	}

	func startAuthenticatedLocalFileSystemOpenExistingVaultFlow(credential: LocalFileSystemCredential, account: CloudProviderAccount, item: Item) {
		let provider: CloudProvider
		do {
			provider = try LocalFileSystemProvider(rootURL: credential.rootURL)
		} catch {
			handleError(error, for: navigationController)
			return
		}
		let child = AuthenticatedOpenExistingVaultCoordinator(navigationController: navigationController, provider: provider, account: account)
		childCoordinators.append(child)
		child.parentCoordinator = self
		child.chooseItem(item)
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
		guard let vaultItem = item as? VaultDetailItem else {
			handleError(VaultCoordinatorError.wrongItemType, for: navigationController)
			return
		}
		if vaultItem.isLegacyVault {
			downloadAndProcessExistingLegacyVault(vaultItem)
		} else {
			downloadAndProcessExistingVault(vaultItem)
		}
	}

	private func downloadAndProcessExistingLegacyVault(_ vaultItem: VaultItem) {
		let hud = ProgressHUD()
		hud.text = LocalizedString.getValue("addVault.openExistingVault.downloadVault.progress")
		hud.show(presentingViewController: navigationController)
		VaultDBManager.shared.downloadMasterkeyFile(delegateAccountUID: account.accountUID, vaultItem: vaultItem).then { downloadedMasterkeyFile in
			all(hud.dismiss(animated: true), Promise(downloadedMasterkeyFile))
		}.then { _, downloadedMasterkeyFile in
			self.processDownloadedMasterkeyFile(downloadedMasterkeyFile, vaultItem: vaultItem)
		}.catch { error in
			hud.dismiss(animated: true).then {
				self.handleError(error, for: self.navigationController)
			}
		}
	}

	private func processDownloadedMasterkeyFile(_ downloadedMasterkeyFile: DownloadedMasterkeyFile, vaultItem: VaultItem) {
		let viewModel = OpenExistingLegacyVaultPasswordViewModel(provider: provider,
		                                                         account: account,
		                                                         vault: vaultItem,
		                                                         vaultUID: UUID().uuidString,
		                                                         downloadedMasterkeyFile: downloadedMasterkeyFile)
		let passwordVC = OpenExistingVaultPasswordViewController(viewModel: viewModel)
		passwordVC.coordinator = self
		navigationController.pushViewController(passwordVC, animated: true)
	}

	private func downloadAndProcessExistingVault(_ vaultItem: VaultItem) {
		let hud = ProgressHUD()
		hud.text = LocalizedString.getValue("addVault.openExistingVault.downloadVault.progress")
		hud.show(presentingViewController: navigationController)
		VaultDBManager.shared.getUnverifiedVaultConfig(delegateAccountUID: account.accountUID, vaultItem: vaultItem).then { downloadedVaultConfig in
			all(hud.dismiss(animated: true), Promise(downloadedVaultConfig))
		}.then { _, downloadedVaultConfig in
			self.processDownloadedVaultConfig(downloadedVaultConfig, vaultItem: vaultItem)
		}.catch { error in
			hud.dismiss(animated: true).then {
				self.handleError(error, for: self.navigationController)
			}
		}
	}

	private func processDownloadedVaultConfig(_ downloadedVaultConfig: DownloadedVaultConfig, vaultItem: VaultItem) {
		switch VaultConfigHelper.getType(for: downloadedVaultConfig.vaultConfig) {
		case .masterkeyFile:
			handleMasterkeyFileVaultConfig(downloadedVaultConfig, vaultItem: vaultItem)
		case .hub:
			handleHubVaultConfig(downloadedVaultConfig, vaultItem: vaultItem)
		case .unknown:
			handleError(error: VaultProviderFactoryError.unsupportedVaultConfig)
		}
	}

	private func handleMasterkeyFileVaultConfig(_ downloadedVaultConfig: DownloadedVaultConfig, vaultItem: VaultItem) {
		VaultDBManager.shared.downloadMasterkeyFile(delegateAccountUID: account.accountUID, vaultItem: vaultItem).then { downloadedMasterkeyFile in
			let viewModel = OpenExistingVaultPasswordViewModel(provider: self.provider, account: self.account, vault: vaultItem, vaultUID: UUID().uuidString, downloadedVaultConfig: downloadedVaultConfig, downloadedMasterkeyFile: downloadedMasterkeyFile)
			let passwordVC = OpenExistingVaultPasswordViewController(viewModel: viewModel)
			passwordVC.coordinator = self
			self.navigationController.pushViewController(passwordVC, animated: true)
		}
	}

	private func handleHubVaultConfig(_ downloadedVaultConfig: DownloadedVaultConfig, vaultItem: VaultItem) {
		let child = AddHubVaultCoordinator(navigationController: navigationController,
		                                   downloadedVaultConfig: downloadedVaultConfig,
		                                   vaultUID: UUID().uuidString,
		                                   accountUID: account.accountUID,
		                                   vaultItem: vaultItem)
		child.parentCoordinator = self
		child.delegate = self
		childCoordinators.append(child)
		child.start()
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
