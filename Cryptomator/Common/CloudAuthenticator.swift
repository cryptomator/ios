//
//  CloudAuthenticator.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 21.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CloudAccessPrivate
import CloudAccessPrivateCore
import CryptomatorCloudAccess
import Foundation
import Promises
import UIKit
class CloudAuthenticator {
	private let accountManager: CloudProviderAccountManager

	init(accountManager: CloudProviderAccountManager) {
		self.accountManager = accountManager
	}

	func authenticateDropbox(from viewController: UIViewController) -> Promise<DropboxCredential> {
		let authenticator = DropboxCloudAuthenticator()
		return authenticator.authenticate(from: viewController).then { credential in
			let account = CloudProviderAccount(accountUID: credential.tokenUid, cloudProviderType: .dropbox)
			try self.accountManager.saveNewAccount(account)
		}
	}

	func authenticateGoogleDrive(from viewController: UIViewController) -> Promise<GoogleDriveCredential> {
		let credential = GoogleDriveCredential(with: UUID().uuidString)
		return GoogleDriveCloudAuthenticator.authenticate(credential: credential, from: viewController).then { () -> GoogleDriveCredential in
			let account = CloudProviderAccount(accountUID: credential.tokenUid, cloudProviderType: .googleDrive)
			try self.accountManager.saveNewAccount(account)
			return credential
		}
	}

	func authenticateWebDAV(from viewController: UIViewController) -> Promise<WebDAVCredential> {
		let pendingPromise = Promise<WebDAVCredential>.pending()
		let webDAVLoginViewController = WebDAVLoginViewController(pendingAuthenticationPromise: pendingPromise)
		viewController.present(webDAVLoginViewController, animated: true)
		return pendingPromise.then { credential in
			let account = CloudProviderAccount(accountUID: credential.identifier, cloudProviderType: .webDAV)
			try self.accountManager.saveNewAccount(account)
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
