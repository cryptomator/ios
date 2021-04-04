//
//  CloudAuthenticator.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 21.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import CryptomatorCloudAccessCore
import CryptomatorCloudAccess
import Foundation
import Promises
import UIKit
class CloudAuthenticator {
	private let accountManager: CloudProviderAccountManager

	init(accountManager: CloudProviderAccountManager) {
		self.accountManager = accountManager
	}

	func authenticateDropbox(from viewController: UIViewController) -> Promise<CloudProviderAccount> {
		let authenticator = DropboxCloudAuthenticator()
		return authenticator.authenticate(from: viewController).then { credential -> CloudProviderAccount in
			let account = CloudProviderAccount(accountUID: credential.tokenUid, cloudProviderType: .dropbox)
			try self.accountManager.saveNewAccount(account)
			return account
		}
	}

	func authenticateGoogleDrive(from viewController: UIViewController) -> Promise<CloudProviderAccount> {
		let credential = GoogleDriveCredential(with: UUID().uuidString)
		return GoogleDriveCloudAuthenticator.authenticate(credential: credential, from: viewController).then { () -> CloudProviderAccount in
			let account = CloudProviderAccount(accountUID: credential.tokenUid, cloudProviderType: .googleDrive)
			try self.accountManager.saveNewAccount(account)
			return account
		}
	}

	func authenticateWebDAV(from viewController: UIViewController) -> Promise<CloudProviderAccount> {
		let pendingPromise = Promise<WebDAVCredential>.pending()
		let webDAVLoginViewController = WebDAVLoginViewController(pendingAuthenticationPromise: pendingPromise)
		viewController.present(webDAVLoginViewController, animated: true)
		return pendingPromise.then { credential -> CloudProviderAccount in
			let account = CloudProviderAccount(accountUID: credential.identifier, cloudProviderType: .webDAV)
			try self.accountManager.saveNewAccount(account)
			return account
		}
	}

	func authenticate(_ cloudProviderType: CloudProviderType, from viewController: UIViewController) -> Promise<CloudProviderAccount> {
		switch cloudProviderType {
		case .dropbox:
			return authenticateDropbox(from: viewController)
		case .googleDrive:
			return authenticateGoogleDrive(from: viewController)
		case .webDAV:
			return authenticateWebDAV(from: viewController)
		case .localFileSystem:
			fatalError("not supported (yet)")
		}
	}

	func deauthenticate(account: CloudProviderAccount) throws {
		switch account.cloudProviderType {
		case .dropbox:
			let credential = DropboxCredential(tokenUid: account.accountUID)
			credential.deauthenticate()
		case .googleDrive:
			let credential = GoogleDriveCredential(with: account.accountUID)
			credential.deauthenticate()
		case .webDAV:
			try WebDAVAuthenticator.removeCredentialFromKeychain(with: account.accountUID)
		case .localFileSystem:
			break
		}
		try accountManager.removeAccount(with: account.accountUID)
	}
}
