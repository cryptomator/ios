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
	let hubAuthenticator: HubAuthenticating
	let vaultManager: VaultManager
	weak var parentCoordinator: Coordinator?
	weak var delegate: (VaultInstalling & AnyObject)?

	init(navigationController: UINavigationController,
	     downloadedVaultConfig: DownloadedVaultConfig,
	     vaultUID: String,
	     accountUID: String,
	     vaultItem: VaultItem,
	     hubAuthenticator: HubAuthenticating,
	     vaultManager: VaultManager = VaultDBManager.shared) {
		self.navigationController = navigationController
		self.downloadedVaultConfig = downloadedVaultConfig
		self.vaultUID = vaultUID
		self.accountUID = accountUID
		self.vaultItem = vaultItem
		self.hubAuthenticator = hubAuthenticator
		self.vaultManager = vaultManager
	}

	func start() {
		let viewModel = HubAuthenticationViewModel(vaultConfig: downloadedVaultConfig.vaultConfig,
		                                           hubUserAuthenticator: self,
		                                           delegate: self)
		let viewController = HubAuthenticationViewController(viewModel: viewModel)
		navigationController.pushViewController(viewController, animated: true)
	}
}

extension AddHubVaultCoordinator: HubAuthenticationFlowDelegate {
	func didSuccessfullyRemoteUnlock(_ response: HubUnlockResponse) async {
		let jwe = response.jwe
		let privateKey = response.privateKey
		let hubVault = ExistingHubVault(vaultUID: vaultUID,
		                                delegateAccountUID: accountUID,
		                                jweData: jwe.compactSerializedData,
		                                privateKey: privateKey,
		                                vaultItem: vaultItem,
		                                downloadedVaultConfig: downloadedVaultConfig)
		do {
			try await vaultManager.addExistingHubVault(hubVault).getValue()
			childDidFinish(self)
			await showSuccessfullyAddedVault()
		} catch {
			DDLogError("Add existing Hub vault failed: \(error)")
			handleError(error, for: navigationController)
		}
	}

	@MainActor
	private func showSuccessfullyAddedVault() {
		delegate?.showSuccessfullyAddedVault(withName: vaultItem.name, vaultUID: vaultUID)
	}
}

extension AddHubVaultCoordinator: HubUserLogin {
	public func authenticate(with hubConfig: HubConfig) async throws -> OIDAuthState {
		try await hubAuthenticator.authenticate(with: hubConfig, from: navigationController)
	}
}
