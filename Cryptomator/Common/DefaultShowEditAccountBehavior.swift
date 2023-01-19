//
//  DefaultShowEditAccountBehavior.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 29.06.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Foundation

protocol DefaultShowEditAccountBehavior {}

extension Coordinator where Self: DefaultShowEditAccountBehavior {
	func showEdit(for account: AccountInfo) {
		switch account.cloudProviderType {
		case .s3:
			showEditForS3Account(account)
		case .webDAV:
			showEditForWebDAVAccount(account)
		default:
			return
		}
	}

	private func showEditForS3Account(_ account: AccountInfo) {
		let credential: S3Credential
		let displayName: String
		do {
			guard let fetchedCredential = S3CredentialManager.shared.getCredential(with: account.accountUID) else {
				DDLogError("showEdit - S3CredentialManager has no credential for existing account")
				throw CloudProviderAccountError.accountNotFoundError
			}
			credential = fetchedCredential
			guard let fetchedDisplayName = try S3CredentialManager.shared.getDisplayName(for: credential) else {
				DDLogError("showEdit - S3CredentialManager has no display name for existing account")
				throw CloudProviderAccountError.accountNotFoundError
			}
			displayName = fetchedDisplayName
		} catch {
			handleError(error, for: navigationController)
			return
		}
		let modalNavigationController = BaseNavigationController()
		let child = S3CredentialCoordinator(credential: credential, displayName: displayName, navigationController: modalNavigationController)
		navigationController.present(modalNavigationController, animated: true)
		childCoordinators.append(child)
		child.parentCoordinator = self
		child.start()
	}

	private func showEditForWebDAVAccount(_ account: AccountInfo) {
		let credential: WebDAVCredential
		do {
			guard let fetchedCredential = WebDAVCredentialManager.shared.getCredentialFromKeychain(with: account.accountUID) else {
				DDLogError("showEdit - WebDAVCredentialManager has no credential for existing account")
				throw CloudProviderAccountError.accountNotFoundError
			}
			credential = fetchedCredential
		} catch {
			handleError(error, for: navigationController)
			return
		}
		let modalNavigationController = BaseNavigationController()
		let child = WebDAVCredentialCoordinator(credential: credential, navigationController: modalNavigationController)
		navigationController.present(modalNavigationController, animated: true)
		childCoordinators.append(child)
		child.parentCoordinator = self
		child.start()
	}
}
