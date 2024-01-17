//
//  HubAddVaultCoordinator.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 16.03.23.
//  Copyright © 2023 Skymatic GmbH. All rights reserved.
//

import AppAuthCore
import CocoaLumberjackSwift
import CryptoKit
import CryptomatorCloudAccessCore
import CryptomatorCommon
import CryptomatorCommonCore
import JOSESwift
import SwiftUI
import UIKit

class AddHubVaultCoordinator: Coordinator {
	var childCoordinators = [Coordinator]()
	var navigationController: UINavigationController
	let downloadedVaultConfig: DownloadedVaultConfig
	let vaultUID: String
	let accountUID: String
	let vaultItem: VaultItem
	let vaultManager: VaultManager
	weak var parentCoordinator: Coordinator?
	weak var delegate: (VaultInstalling & AnyObject)?

	init(navigationController: UINavigationController,
	     downloadedVaultConfig: DownloadedVaultConfig,
	     vaultUID: String,
	     accountUID: String,
	     vaultItem: VaultItem,
	     vaultManager: VaultManager = VaultDBManager.shared) {
		self.navigationController = navigationController
		self.downloadedVaultConfig = downloadedVaultConfig
		self.vaultUID = vaultUID
		self.accountUID = accountUID
		self.vaultItem = vaultItem
		self.vaultManager = vaultManager
	}

	func start() {
		let unlockHandler = AddHubVaultUnlockHandler(vaultUID: vaultUID,
		                                             accountUID: accountUID, vaultItem: vaultItem,
		                                             downloadedVaultConfig: downloadedVaultConfig,
		                                             vaultManager: vaultManager,
		                                             delegate: self)
		let child = HubAuthenticationCoordinator(navigationController: navigationController,
		                                         vaultConfig: downloadedVaultConfig.vaultConfig,
		                                         unlockHandler: unlockHandler,
		                                         parent: self,
		                                         delegate: self)
		childCoordinators.append(child)
		child.start()
	}
}

extension AddHubVaultCoordinator: HubVaultUnlockHandlerDelegate {
	func successfullyProcessedUnlockedVault() {
		delegate?.showSuccessfullyAddedVault(withName: vaultItem.name, vaultUID: vaultUID)
	}

	func failedToProcessUnlockedVault(error: Error) {
		handleError(error, for: navigationController, onOKTapped: { [weak self] in
			self?.parentCoordinator?.childDidFinish(self)
		})
	}
}

extension AddHubVaultCoordinator: HubAuthenticationCoordinatorDelegate {
	func userDidCancelHubAuthentication() {
		// do nothing as the user already sees the login screen again
	}

	func userDismissedHubAuthenticationErrorMessage() {
		// do nothing as the user already sees the login screen again
	}
}
