//
//  ShareVaultCoordinator.swift
//  Cryptomator
//
//  Created by Majid Achhoud on 30.10.25.
//  Copyright © 2025 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import UIKit

class ShareVaultCoordinator: Coordinator {
	weak var parentCoordinator: Coordinator?
	lazy var childCoordinators = [Coordinator]()
	var navigationController: UINavigationController
	private let vaultInfo: VaultInfo

	init(vaultInfo: VaultInfo, navigationController: UINavigationController) {
		self.vaultInfo = vaultInfo
		self.navigationController = navigationController
	}

	func start() {
		let viewModel: ShareVaultViewModel
		if vaultInfo.vaultConfigType == .hub, let hubURL = extractHubVaultURL() {
			viewModel = ShareVaultViewModel(type: .hub(hubURL))
		} else {
			viewModel = ShareVaultViewModel(type: .normal)
		}
		let shareVaultViewController = ShareVaultViewController(viewModel: viewModel)
		shareVaultViewController.coordinator = self
		navigationController.pushViewController(shareVaultViewController, animated: true)
	}

	private func extractHubVaultURL() -> URL? {
		guard let cachedVault = try? VaultDBCache().getCachedVault(withVaultUID: vaultInfo.vaultUID),
		      let vaultConfigToken = cachedVault.vaultConfigToken,
		      let vaultConfig = try? UnverifiedVaultConfig(token: vaultConfigToken),
		      let hubConfig = vaultConfig.allegedHubConfig else {
			return nil
		}

		return hubConfig.getWebAppURL()
	}
}
