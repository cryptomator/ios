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
			let account = CloudProviderAccount(accountUID: try credential.getAccountID(), cloudProviderType: .googleDrive)
			try self.accountManager.saveNewAccount(account)
			return account
		}
	}

	func authenticateOneDrive(from viewController: UIViewController) -> Promise<CloudProviderAccount> {
		OneDriveAuthenticator.authenticate(from: viewController).then { credential -> CloudProviderAccount in
			let account = CloudProviderAccount(accountUID: credential.identifier, cloudProviderType: .oneDrive)
			try self.accountManager.saveNewAccount(account)
			return account
		}
	}

	func authenticatePCloud(from viewController: UIViewController) -> Promise<CloudProviderAccount> {
		let authenticator = PCloudAuthenticator(appKey: CloudAccessSecrets.pCloudAppKey)
		return authenticator.authenticate(from: viewController).then { credential -> CloudProviderAccount in
			try credential.saveToKeychain()
			let account = CloudProviderAccount(accountUID: credential.userID, cloudProviderType: .pCloud)
			try self.accountManager.saveNewAccount(account)
			return account
		}
	}

	func authenticateWebDAV(from viewController: UIViewController) -> Promise<CloudProviderAccount> {
		return WebDAVAuthenticator.authenticate(from: viewController).then { credential -> CloudProviderAccount in
			let account = CloudProviderAccount(accountUID: credential.identifier, cloudProviderType: .webDAV(type: .custom))
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
		case .oneDrive:
			return authenticateOneDrive(from: viewController)
		case .pCloud:
			return authenticatePCloud(from: viewController)
		case .webDAV:
			return authenticateWebDAV(from: viewController)
		case .localFileSystem:
			return Promise(CloudAuthenticatorError.functionNotYetSupported)
		}
	}

	func deauthenticate(account: CloudProviderAccount) throws {
		switch account.cloudProviderType {
		case .dropbox:
			let credential = DropboxCredential(tokenUID: account.accountUID)
			credential.deauthenticate()
		case .googleDrive:
			let credential = GoogleDriveCredential(userID: account.accountUID)
			credential.deauthenticate()
		case .oneDrive:
			let credential = try OneDriveCredential(with: account.accountUID)
			try credential.deauthenticate()
		case .pCloud:
			let credential = try PCloudCredential(userID: account.accountUID)
			try credential.deauthenticate()
		case .webDAV:
			try WebDAVAuthenticator.removeCredentialFromKeychain(with: account.accountUID)
		case .localFileSystem:
			break
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
