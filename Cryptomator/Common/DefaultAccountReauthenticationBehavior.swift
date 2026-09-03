//
//  DefaultAccountReauthenticationBehavior.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 31.08.26.
//  Copyright © 2026 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Foundation
import Promises
import UIKit

protocol DefaultAccountReauthenticationBehavior {}

extension Coordinator where Self: DefaultAccountReauthenticationBehavior {
	/**
	 Signs the user in again for an account that is already in use.

	 The returned promise is rejected if the user cancels, signs in with a different account, or the cloud provider cannot keep its account. Callers therefore handle success alone, because every failure is already dealt with here. A mismatch gets an alert, a cancellation needs none, an unsupported provider is logged, and anything else goes to `handleError`.

	 Only a provider with `AccountRecoveryMode.reauthenticate` is accepted. Signing in again would mint a new identifier for S3 and WebDAV, and the local file system has no sign-in at all.

	 - Parameter authenticator: Both the account list and the discard go through this authenticator, thus they always see the same store.
	 */
	func reauthenticate(_ account: CloudProviderAccount, from viewController: UIViewController, authenticator: CloudAuthenticator = CloudAuthenticator(accountManager: CloudProviderAccountDBManager.shared)) -> Promise<CloudProviderAccount> {
		guard account.cloudProviderType.accountRecoveryMode == .reauthenticate else {
			DDLogError("Signing in again is not supported for \(account.cloudProviderType)")
			return Promise(AccountReauthenticationError.unsupportedCloudProviderType)
		}
		let accountUIDsBeforeSignIn = try? authenticator.accountManager.getAllAccountUIDs(for: account.cloudProviderType)
		return authenticator.authenticate(account.cloudProviderType, from: viewController).then { reAuthAccount -> CloudProviderAccount in
			switch AccountReauthenticationOutcome(expectedAccountUID: account.accountUID, reAuthAccountUID: reAuthAccount.accountUID, accountUIDsBeforeSignIn: accountUIDsBeforeSignIn) {
			case .matched:
				CloudProviderDBManager.shared.providerShouldUpdate(with: reAuthAccount.accountUID)
				return reAuthAccount
			case .mismatchedWithNewAccount:
				self.discard(reAuthAccount, with: authenticator)
				self.showAccountMismatchAlert(for: account)
				throw AccountReauthenticationError.accountMismatch
			case .mismatchedWithKnownAccount:
				self.showAccountMismatchAlert(for: account)
				throw AccountReauthenticationError.accountMismatch
			}
		}.catch { error in
			switch error {
			case CocoaError.userCancelled, AccountReauthenticationError.accountMismatch:
				break
			default:
				self.handleError(error, for: self.navigationController)
			}
		}
	}

	private func showAccountMismatchAlert(for account: CloudProviderAccount) {
		let providerName = account.cloudProviderType.localizedString()
		let alert = UIAlertController(
			title: LocalizedString.getValue("common.alert.attention.title"),
			message: String(format: LocalizedString.getValue("cloudProvider.error.unauthorized.reauth.accountMismatch"), providerName),
			preferredStyle: .alert
		)
		let okAction = UIAlertAction(title: LocalizedString.getValue("common.button.ok"), style: .default)
		alert.addAction(okAction)
		navigationController.topViewController?.present(alert, animated: true)
	}

	private func discard(_ account: CloudProviderAccount, with authenticator: CloudAuthenticator) {
		do {
			try authenticator.deauthenticate(account: account)
		} catch {
			DDLogError("Discarding account \(account.accountUID) added by re-authentication failed with error: \(error)")
		}
	}
}

/**
 The result of signing in again for an account that is already in use.

 Discarding an account removes its vaults, thus only an account that the sign-in itself added may be discarded. Everything this classification is unsure about resolves to `mismatchedWithKnownAccount`, an unreadable list included.
 */
enum AccountReauthenticationOutcome: Equatable {
	case matched
	case mismatchedWithNewAccount
	case mismatchedWithKnownAccount

	/**
	 - Parameter accountUIDsBeforeSignIn: The accounts of the same cloud provider that existed before the sign-in, or `nil` if they could not be read. Absence of an account proves that the sign-in added it only if the list holds the expected account.
	 */
	init(expectedAccountUID: String, reAuthAccountUID: String, accountUIDsBeforeSignIn: [String]?) {
		if reAuthAccountUID == expectedAccountUID {
			self = .matched
		} else if let accountUIDsBeforeSignIn = accountUIDsBeforeSignIn, accountUIDsBeforeSignIn.contains(expectedAccountUID), !accountUIDsBeforeSignIn.contains(reAuthAccountUID) {
			self = .mismatchedWithNewAccount
		} else {
			self = .mismatchedWithKnownAccount
		}
	}
}

enum AccountReauthenticationError: Error {
	case accountMismatch
	case unsupportedCloudProviderType
}
