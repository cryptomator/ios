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

	init(accountManager: CloudProviderAccountManager, vaultManager: VaultManager = VaultDBManager.shared, vaultAccountManager: VaultAccountManager = VaultAccountDBManager.shared) {
		self.accountManager = accountManager
		self.vaultManager = vaultManager
		self.vaultAccountManager = vaultAccountManager
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

	func authenticateMicrosoftGraph(from viewController: UIViewController, providerType: CloudProviderType) -> Promise<CloudProviderAccount> {
		return MicrosoftGraphAuthenticator.authenticate(from: viewController, for: providerType).then { credential -> CloudProviderAccount in
			let account = CloudProviderAccount(accountUID: credential.identifier, cloudProviderType: providerType)
			try self.accountManager.saveNewAccount(account)
			return account
		}
	}

	func authenticateOneDrive(from viewController: UIViewController) -> Promise<CloudProviderAccount> {
		return authenticateMicrosoftGraph(from: viewController, providerType: .oneDrive)
	}

	func authenticateSharePoint(from viewController: UIViewController) -> Promise<CloudProviderAccount> {
		return authenticateMicrosoftGraph(from: viewController, providerType: .sharePoint)
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
		case .oneDrive:
			return authenticateOneDrive(from: viewController)
		case .pCloud:
			return authenticatePCloud(from: viewController)
		case .sharePoint:
			return authenticateSharePoint(from: viewController)
		case .s3:
			return authenticateS3(from: viewController)
		case .webDAV:
			return authenticateWebDAV(from: viewController)
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
		case .oneDrive:
			let credential = try OneDriveCredential(with: account.accountUID)
			try credential.deauthenticate()
		case .sharePoint:
			let credential = try SharePointCredential(with: account.accountUID)
			try credential.deauthenticate()
		case .pCloud:
			let credential = try PCloudCredential(userID: account.accountUID)
			try credential.deauthenticate()
		case .s3:
			try S3CredentialManager.shared.removeCredential(with: account.accountUID)
		case .webDAV:
			try WebDAVCredentialManager.shared.removeCredentialFromKeychain(with: account.accountUID)
		}
		let correspondingVaults = try vaultAccountManager.getAllAccounts().filter { $0.delegateAccountUID == account.accountUID }
		_ = Promise<Void>(on: .global()) { fulfill, _ in
			for correspondingVault in correspondingVaults {
				do {
					try awaitPromise(self.vaultManager.removeVault(withUID: correspondingVault.vaultUID))
				} catch {
					DDLogError("Remove corresponding vault: \(correspondingVault.vaultName) after deauthenticated account: \(account) - failed with error: \(error)")
				}
			}
			fulfill(())
		}.then {
			try self.accountManager.removeAccount(with: account.accountUID)
		}.catch { error in
			DDLogError("Deauthenticate account: \(account) failed with error: \(error)")
		}
	}
}

enum CloudAuthenticatorError: Error {
	case functionNotYetSupported
}
