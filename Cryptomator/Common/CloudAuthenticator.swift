//
//  CloudAuthenticator.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 21.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCloudAccess
import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Foundation
import Promises
import UIKit

class CloudAuthenticator {
	private let accountManager: CloudProviderAccountManager
	private let vaultManager: VaultManager
	private let vaultAccountManager: VaultAccountManager
	private let microsoftGraphAccountManager: MicrosoftGraphAccountManager

	init(accountManager: CloudProviderAccountManager, vaultManager: VaultManager = VaultDBManager.shared, vaultAccountManager: VaultAccountManager = VaultAccountDBManager.shared, microsoftGraphAccountManager: MicrosoftGraphAccountManager = MicrosoftGraphAccountDBManager.shared) {
		self.accountManager = accountManager
		self.vaultManager = vaultManager
		self.vaultAccountManager = vaultAccountManager
		self.microsoftGraphAccountManager = microsoftGraphAccountManager
	}

	func authenticate(_ cloudProviderType: CloudProviderType, from viewController: UIViewController) -> Promise<CloudProviderAccount> {
		switch cloudProviderType {
		case .box:
			return authenticateBox(from: viewController)
		case .dropbox:
			return authenticateDropbox(from: viewController)
		case .googleDrive:
			return authenticateGoogleDrive(from: viewController)
		case .localFileSystem:
			return Promise(CloudAuthenticatorError.functionNotYetSupported)
		case .microsoftGraph(type: .oneDrive):
			return authenticateOneDrive(from: viewController)
		case .microsoftGraph(type: .sharePoint):
			return authenticateSharePoint(from: viewController)
		case .pCloud:
			return authenticatePCloud(from: viewController)
		case .s3:
			return authenticateS3(from: viewController)
		case .webDAV:
			return authenticateWebDAV(from: viewController)
		}
	}

	func authenticateDropbox(from viewController: UIViewController) -> Promise<CloudProviderAccount> {
		let authenticator = DropboxAuthenticator()
		return authenticator.authenticate(from: viewController).then { credential -> CloudProviderAccount in
			let account = CloudProviderAccount(accountUID: credential.tokenUID, cloudProviderType: .dropbox)
			try self.accountManager.saveNewAccount(account)
			return account
		}
	}

	func authenticateGoogleDrive(from viewController: UIViewController) -> Promise<CloudProviderAccount> {
		let credential = GoogleDriveCredential()
		return GoogleDriveAuthenticator.authenticate(credential: credential, from: viewController).then { () -> CloudProviderAccount in
			let account = try CloudProviderAccount(accountUID: credential.getAccountID(), cloudProviderType: .googleDrive)
			try self.accountManager.saveNewAccount(account)
			return account
		}
	}

	func authenticateOneDrive(from viewController: UIViewController) -> Promise<CloudProviderAccount> {
		return OneDriveAuthenticator.authenticate(from: viewController, cloudProviderAccountManager: accountManager, microsoftGraphAccountManager: microsoftGraphAccountManager)
	}

	func authenticateSharePoint(from viewController: UIViewController) -> Promise<CloudProviderAccount> {
		return SharePointAuthenticator.authenticate(from: viewController, cloudProviderAccountManager: accountManager, microsoftGraphAccountManager: microsoftGraphAccountManager)
	}

	func authenticatePCloud(from viewController: UIViewController) -> Promise<CloudProviderAccount> {
		return PCloudAuthenticator.authenticate(from: viewController).then { credential -> CloudProviderAccount in
			try credential.saveToKeychain()
			let account = CloudProviderAccount(accountUID: credential.userID, cloudProviderType: .pCloud)
			try self.accountManager.saveNewAccount(account)
			return account
		}
	}

	func authenticateBox(from viewController: UIViewController) -> Promise<CloudProviderAccount> {
		let tokenStorage = BoxTokenStorage()
		let credential = BoxCredential(tokenStorage: tokenStorage)
		return BoxAuthenticator.authenticate(from: viewController, tokenStorage: tokenStorage).then { _ -> Promise<CloudProviderAccount> in
			return credential.getUserID().then { userID in
				tokenStorage.userID = userID // this will actually save the access token to the keychain
				let account = CloudProviderAccount(accountUID: userID, cloudProviderType: .box)
				try self.accountManager.saveNewAccount(account)
				return account
			}
		}
	}

	func authenticateWebDAV(from viewController: UIViewController) -> Promise<CloudProviderAccount> {
		return WebDAVAuthenticator.authenticate(from: viewController).then { credential -> CloudProviderAccount in
			let account = CloudProviderAccount(accountUID: credential.identifier, cloudProviderType: .webDAV(type: .custom))
			try self.accountManager.saveNewAccount(account)
			return account
		}
	}

	func authenticateS3(from viewController: UIViewController) -> Promise<CloudProviderAccount> {
		return S3Authenticator.authenticate(from: viewController).then { credential -> CloudProviderAccount in
			let account = CloudProviderAccount(accountUID: credential.identifier, cloudProviderType: .s3(type: .custom))
			try self.accountManager.saveNewAccount(account)
			return account
		}
	}

	func deauthenticate(account: CloudProviderAccount) throws {
		switch account.cloudProviderType {
		case .box:
			let tokenStorage = BoxTokenStorage(userID: account.accountUID)
			let credential = BoxCredential(tokenStorage: tokenStorage)
			_ = credential.deauthenticate()
		case .dropbox:
			let credential = DropboxCredential(tokenUID: account.accountUID)
			credential.deauthenticate()
		case .googleDrive:
			let credential = GoogleDriveCredential(userID: account.accountUID)
			credential.deauthenticate()
		case .localFileSystem:
			break
		case let .microsoftGraph(type):
			try deauthenticateMicrosoftGraph(account: account, type: type)
		case .pCloud:
			let credential = try PCloudCredential(userID: account.accountUID)
			try credential.deauthenticate()
		case .s3:
			try S3CredentialManager.shared.removeCredential(with: account.accountUID)
		case .webDAV:
			try WebDAVCredentialManager.shared.removeCredentialFromKeychain(with: account.accountUID)
		}
		let correspondingVaults = try vaultAccountManager.getAllAccounts().filter { $0.delegateAccountUID == account.accountUID }
		let vaultUIDs = correspondingVaults.map { $0.vaultUID }

		_ = Promise<Void>(on: .global()) { fulfill, reject in
			do {
				if !vaultUIDs.isEmpty {
					try awaitPromise(self.vaultManager.removeVaults(withUIDs: vaultUIDs))
					DDLogInfo("Removed \(vaultUIDs.count) vaults for deauthenticated account: \(account)")
				}
				fulfill(())
			} catch {
				reject(error)
			}
		}.then {
			try self.accountManager.removeAccount(with: account.accountUID)
		}.catch { error in
			DDLogError("Deauthenticate account: \(account) failed with error: \(error)")
		}
	}

	func deauthenticateMicrosoftGraph(account: CloudProviderAccount, type: MicrosoftGraphType) throws {
		let microsoftGraphAccount = try microsoftGraphAccountManager.getAccount(for: account.accountUID)
		if try microsoftGraphAccountManager.multipleAccountsExist(for: microsoftGraphAccount.credentialID) {
			DDLogInfo("Skipped deauthentication for accountUID \(microsoftGraphAccount.accountUID) because the credentialID \(microsoftGraphAccount.credentialID) appears multiple times in the database.")
		} else {
			let credential = MicrosoftGraphCredential(identifier: microsoftGraphAccount.credentialID, type: type)
			try credential.deauthenticate()
		}
	}
}

enum CloudAuthenticatorError: Error {
	case functionNotYetSupported
}
