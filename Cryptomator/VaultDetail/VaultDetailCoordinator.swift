//
//  VaultDetailCoordinator.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 20.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import CryptomatorFileProvider
import GRDB
import Promises
import UIKit

class VaultDetailCoordinator: Coordinator {
	var childCoordinators = [Coordinator]()

	var navigationController: UINavigationController
	weak var removedVaultDelegate: RemoveVaultDelegate?
	private let vaultInfo: VaultInfo

	init(vaultInfo: VaultInfo, navigationController: UINavigationController) {
		self.vaultInfo = vaultInfo
		self.navigationController = navigationController
	}

	func start() {
		let viewModel = VaultDetailViewModel(vaultInfo: vaultInfo)
		let vaultDetailViewController = VaultDetailViewController(viewModel: viewModel)
		vaultDetailViewController.coordinator = self
		navigationController.pushViewController(vaultDetailViewController, animated: true)
	}

	func unlockVault(_ vault: VaultInfo, biometryTypeName: String) -> Promise<Void> {
		let modalNavigationController = BaseNavigationController()
		let pendingAuthentication = Promise<Void>.pending()
		let child = VaultDetailUnlockCoordinator(navigationController: modalNavigationController, vault: vault, biometryTypeName: biometryTypeName, pendingAuthentication: pendingAuthentication)
		child.parentCoordinator = self
		childCoordinators.append(child)
		navigationController.topViewController?.present(modalNavigationController, animated: true)
		child.start()
		return pendingAuthentication
	}

	func renameVault() {
		let configuration: VaultMoveConfiguration
		do {
			configuration = try createVaultMoveConfiguration()
		} catch {
			handleError(error, for: navigationController.topViewController ?? navigationController)
			return
		}
		let viewModel = RenameVaultViewModel(provider: configuration.provider, vaultInfo: vaultInfo, maintenanceManager: configuration.maintenanceManager)
		let renameVaultViewController = RenameVaultViewController(viewModel: viewModel)
		renameVaultViewController.coordinator = self
		navigationController.pushViewController(renameVaultViewController, animated: true)
	}

	func moveVault() {
		let configuration: VaultMoveConfiguration
		do {
			configuration = try createVaultMoveConfiguration()
		} catch {
			handleError(error, for: navigationController.topViewController ?? navigationController)
			return
		}
		let child = MoveVaultCoordinator(vaultInfo: vaultInfo, provider: configuration.provider, maintenanceManager: configuration.maintenanceManager, navigationController: navigationController)
		child.parentCoordinator = self
		childCoordinators.append(child)
		child.start()
	}

	func removedVault() {
		removedVaultDelegate?.removedVault(vaultInfo)
	}

	func changeVaultPassword() {
		let maintenanceManager: MaintenanceManager
		do {
			let database = try getFileProviderDatabase()
			maintenanceManager = MaintenanceDBManager(database: database)
		} catch {
			handleError(error, for: navigationController.topViewController ?? navigationController)
			return
		}
		let viewModel = ChangePasswordViewModel(vaultAccount: vaultInfo.vaultAccount, maintenanceManager: maintenanceManager)
		let changePasswordViewController = ChangePasswordViewController(viewModel: viewModel)
		changePasswordViewController.coordinator = self
		navigationController.pushViewController(changePasswordViewController, animated: true)
	}

	private func getFileProviderDatabase() throws -> DatabaseWriter {
		let domain = NSFileProviderDomain(vaultUID: vaultInfo.vaultUID, displayName: vaultInfo.vaultName)
		let fileproviderDatabaseURL = DatabaseHelper.getDatabaseURL(for: domain)
		return try DatabaseHelper.getMigratedDB(at: fileproviderDatabaseURL)
	}

	private func createVaultMoveConfiguration() throws -> VaultMoveConfiguration {
		let provider = try CloudProviderDBManager.shared.getProvider(with: vaultInfo.delegateAccountUID)
		let database = try getFileProviderDatabase()
		let maintenanceManager = MaintenanceDBManager(database: database)
		return VaultMoveConfiguration(provider: provider, maintenanceManager: maintenanceManager)
	}

	private struct VaultMoveConfiguration {
		let provider: CloudProvider
		let maintenanceManager: MaintenanceManager
	}
}

extension VaultDetailCoordinator: VaultNaming {
	func setVaultName(_ name: String) {
		guard let topViewController = navigationController.topViewController, topViewController is RenameVaultViewController else {
			return
		}
		navigationController.popViewController(animated: true)
	}
}

extension VaultDetailCoordinator: VaultPasswordChanging {
	func changedPassword() {
		guard let topViewController = navigationController.topViewController, topViewController is ChangePasswordViewController else {
			return
		}
		navigationController.popViewController(animated: true)
	}
}

protocol RemoveVaultDelegate: AnyObject {
	func removedVault(_ vault: VaultInfo)
}
