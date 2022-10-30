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
	private var domain: NSFileProviderDomain {
		NSFileProviderDomain(vaultUID: vaultInfo.vaultUID, displayName: vaultInfo.vaultName)
	}

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

	func showKeepUnlockedSettings(currentKeepUnlockedDuration: Bindable<KeepUnlockedDuration>) {
		let viewModel = VaultKeepUnlockedViewModel(currentKeepUnlockedDuration: currentKeepUnlockedDuration, vaultInfo: vaultInfo)
		let keepUnlockedViewController = VaultKeepUnlockedViewController(viewModel: viewModel)
		keepUnlockedViewController.coordinator = self
		navigationController.pushViewController(keepUnlockedViewController, animated: true)
	}

	func renameVault() {
		let provider: CloudProvider
		do {
			provider = try CloudProviderDBManager.shared.getProvider(with: vaultInfo.delegateAccountUID)
		} catch {
			handleError(error, for: navigationController.topViewController ?? navigationController)
			return
		}
		let viewModel = RenameVaultViewModel(provider: provider,
		                                     vaultInfo: vaultInfo,
		                                     domain: domain)
		let renameVaultViewController = RenameVaultViewController(viewModel: viewModel)
		renameVaultViewController.coordinator = self
		navigationController.pushViewController(renameVaultViewController, animated: true)
	}

	func moveVault() {
		let provider: CloudProvider
		do {
			provider = try CloudProviderDBManager.shared.getProvider(with: vaultInfo.delegateAccountUID)
		} catch {
			handleError(error, for: navigationController.topViewController ?? navigationController)
			return
		}
		let child = MoveVaultCoordinator(vaultInfo: vaultInfo,
		                                 provider: provider,
		                                 navigationController: navigationController)
		child.parentCoordinator = self
		childCoordinators.append(child)
		child.start()
	}

	func removedVault() {
		removedVaultDelegate?.removedVault(vaultInfo)
	}

	func changeVaultPassword() {
		let domain = NSFileProviderDomain(vaultUID: vaultInfo.vaultUID, displayName: vaultInfo.vaultName)
		let viewModel = ChangePasswordViewModel(vaultAccount: vaultInfo.vaultAccount, domain: domain)
		let changePasswordViewController = ChangePasswordViewController(viewModel: viewModel)
		changePasswordViewController.coordinator = self
		navigationController.pushViewController(changePasswordViewController, animated: true)
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
