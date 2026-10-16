//
//  DefaultAccountSelectionBehavior.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 04.03.26.
//  Copyright © 2026 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Foundation
import UIKit

protocol DefaultAccountSelectionBehavior: DefaultAccountReauthenticationBehavior {
	func proceedWithValidatedAccount(provider: CloudProvider, account: CloudProviderAccount)
}

extension Coordinator where Self: DefaultAccountSelectionBehavior & AccountListing {
	func selectedAccount(_ account: AccountInfo) {
		switch account.cloudProviderType.accountRecoveryMode {
		case .editExisting, .unsupported:
			do {
				let provider = try CloudProviderDBManager.shared.getProvider(with: account.accountUID)
				proceedWithValidatedAccount(provider: provider, account: account.cloudProviderAccount)
			} catch {
				handleError(error, for: navigationController)
			}
		case .reauthenticate:
			validateAndProceed(with: account)
		}
	}

	private func validateAndProceed(with account: AccountInfo) {
		let hud = ProgressHUD()
		hud.text = nil
		hud.show(presentingViewController: navigationController)

		Task {
			let provider: CloudProvider
			do {
				provider = try CloudProviderDBManager.shared.getProvider(with: account.accountUID)
			} catch {
				await hud.dismiss(animated: true)
				handleError(error, for: navigationController)
				return
			}

			do {
				_ = try await provider.fetchItemList(forFolderAt: CloudPath("/"), withPageToken: nil)
				await hud.dismiss(animated: true)
				proceedWithValidatedAccount(provider: provider, account: account.cloudProviderAccount)
			} catch {
				await hud.dismiss(animated: true)
				if error.isUnauthorizedError {
					showReauthenticationAlert(for: account)
				} else {
					handleError(error, for: navigationController)
				}
			}
		}
	}

	private func showReauthenticationAlert(for account: AccountInfo) {
		let providerName = account.cloudProviderType.localizedString()
		let alert = UIAlertController(
			title: LocalizedString.getValue("cloudProvider.error.unauthorized.reauth.title"),
			message: String(format: LocalizedString.getValue("cloudProvider.error.unauthorized.reauth.message"), providerName),
			preferredStyle: .alert
		)
		let signInAction = UIAlertAction(title: LocalizedString.getValue("cloudProvider.error.unauthorized.reauth.button"), style: .default) { _ in
			guard let viewController = self.navigationController.topViewController else { return }
			self.showReauthentication(for: account.cloudProviderAccount, from: viewController)
		}
		let cancelAction = UIAlertAction(title: LocalizedString.getValue("common.button.cancel"), style: .cancel)
		alert.addAction(signInAction)
		alert.addAction(cancelAction)
		navigationController.topViewController?.present(alert, animated: true)
	}

	private func showReauthentication(for account: CloudProviderAccount, from viewController: UIViewController) {
		Task {
			guard let reAuthAccount = try? await reauthenticate(account, from: viewController) else {
				return
			}
			do {
				let provider = try CloudProviderDBManager.shared.getProvider(with: reAuthAccount.accountUID)
				proceedWithValidatedAccount(provider: provider, account: reAuthAccount)
			} catch {
				handleError(error, for: navigationController)
			}
		}
	}
}
