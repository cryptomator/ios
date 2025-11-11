//
//  ShareVaultCoordinator.swift
//  Cryptomator
//
//  Created by Majid Achhoud on 30.10.25.
//  Copyright © 2025 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import SafariServices
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

		if vaultInfo.vaultConfigType == .hub {
			guard let hubURL = extractHubVaultURL() else {
				showHubURLExtractionError()
				return
			}
			viewModel = ShareVaultViewModel(type: .hub(hubURL))
		} else {
			viewModel = ShareVaultViewModel(type: .normal)
		}

		let shareVaultViewController = ShareVaultViewController(viewModel: viewModel)
		shareVaultViewController.coordinator = self
		shareVaultViewController.onOpenURL = { [weak self] url in
			self?.openURL(url)
		}
		navigationController.pushViewController(shareVaultViewController, animated: true)
	}

	private func openURL(_ url: URL) {
		if vaultInfo.vaultConfigType == .hub {
			openInAppBrowser(url: url)
		} else {
			UIApplication.shared.open(url)
		}
	}

	private func openInAppBrowser(url: URL) {
		let safariViewController = SFSafariViewController(url: url)
		navigationController.present(safariViewController, animated: true)
	}

	private func showHubURLExtractionError() {
		let alert = UIAlertController(
			title: LocalizedString.getValue("shareVault.error.hubURLExtraction.title"),
			message: LocalizedString.getValue("shareVault.error.hubURLExtraction.message"),
			preferredStyle: .alert
		)
		alert.addAction(UIAlertAction(title: LocalizedString.getValue("common.button.ok"), style: .default))
		navigationController.present(alert, animated: true)
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
