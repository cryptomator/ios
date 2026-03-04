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
import Promises
import UIKit

protocol DefaultAccountSelectionBehavior {
	func proceedWithValidatedAccount(provider: CloudProvider, account: CloudProviderAccount)
}

extension Coordinator where Self: DefaultAccountSelectionBehavior & AccountListing {
	func selectedAccont(_ account: AccountInfo) {
		switch account.cloudProviderType {
		case .s3, .webDAV, .localFileSystem:
			do {
				let provider = try CloudProviderDBManager.shared.getProvider(with: account.accountUID)
				proceedWithValidatedAccount(provider: provider, account: account.cloudProviderAccount)
			} catch {
				handleError(error, for: navigationController)
			}
		default:
			validateAndProceed(with: account)
		}
	}

	private func validateAndProceed(with account: AccountInfo) {
		let hud = ProgressHUD()
		hud.text = nil
		hud.show(presentingViewController: navigationController)

		let provider: CloudProvider
		do {
			provider = try CloudProviderDBManager.shared.getProvider(with: account.accountUID)
		} catch {
			hud.dismiss(animated: true) {
				self.handleError(error, for: self.navigationController)
			}
			return
		}

		provider.fetchItemList(forFolderAt: CloudPath("/"), withPageToken: nil).then { _ in
			hud.dismiss(animated: true) {
				self.proceedWithValidatedAccount(provider: provider, account: account.cloudProviderAccount)
			}
		}.catch { error in
			hud.dismiss(animated: true) {
				if case CloudProviderError.unauthorized = error {
					self.showReauthenticationAlert(for: account)
				} else {
					self.handleError(error, for: self.navigationController)
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
			self.reauthenticate(account: account)
		}
		let cancelAction = UIAlertAction(title: LocalizedString.getValue("common.button.cancel"), style: .cancel)
		alert.addAction(signInAction)
		alert.addAction(cancelAction)
		navigationController.topViewController?.present(alert, animated: true)
	}

	private func reauthenticate(account: AccountInfo) {
		guard let viewController = navigationController.topViewController else { return }
		let authenticator = CloudAuthenticator(accountManager: CloudProviderAccountDBManager.shared)
		authenticator.authenticate(account.cloudProviderType, from: viewController).then { reAuthAccount in
			CloudProviderDBManager.shared.providerShouldUpdate(with: reAuthAccount.accountUID)
			let provider = try CloudProviderDBManager.shared.getProvider(with: reAuthAccount.accountUID)
			self.proceedWithValidatedAccount(provider: provider, account: reAuthAccount)
		}.catch { error in
			guard case CocoaError.userCancelled = error else {
				self.handleError(error, for: self.navigationController)
				return
			}
		}
	}
}
