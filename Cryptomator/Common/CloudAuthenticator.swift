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
import UIKit

class CloudAuthenticator {
	let accountManager: CloudProviderAccountManager
	private let vaultManager: VaultManager
	private let vaultAccountManager: VaultAccountManager
	private let microsoftGraphAccountManager: MicrosoftGraphAccountManager

	init(accountManager: CloudProviderAccountManager, vaultManager: VaultManager = VaultDBManager.shared, vaultAccountManager: VaultAccountManager = VaultAccountDBManager.shared, microsoftGraphAccountManager: MicrosoftGraphAccountManager = MicrosoftGraphAccountDBManager.shared) {
		self.accountManager = accountManager
		self.vaultManager = vaultManager
		self.vaultAccountManager = vaultAccountManager
		self.microsoftGraphAccountManager = microsoftGraphAccountManager
	}

	func authenticate(_ cloudProviderType: CloudProviderType, from viewController: UIViewController) async throws -> CloudProviderAccount {
		switch cloudProviderType {
		case .box:
			return try await authenticateBox(from: viewController)
		case .dropbox:
			return try await authenticateDropbox(from: viewController)
		case .googleDrive:
			return try await authenticateGoogleDrive(from: viewController)
		case .localFileSystem:
			throw CloudAuthenticatorError.functionNotYetSupported
		case .microsoftGraph(type: .oneDrive):
			return try await authenticateOneDrive(from: viewController)
		case .microsoftGraph(type: .sharePoint):
			return try await authenticateSharePoint(from: viewController)
		case .pCloud:
			return try await authenticatePCloud(from: viewController)
		case .s3:
			return try await authenticateS3(from: viewController)
		case .webDAV:
			return try await authenticateWebDAV(from: viewController)
		}
	}

	func authenticateDropbox(from viewController: UIViewController) async throws -> CloudProviderAccount {
		let authenticator = DropboxAuthenticator()
		let credential = try await authenticator.authenticate(from: viewController)
		let account = CloudProviderAccount(accountUID: credential.tokenUID, cloudProviderType: .dropbox)
		try accountManager.saveNewAccount(account)
		return account
	}

	func authenticateGoogleDrive(from viewController: UIViewController) async throws -> CloudProviderAccount {
		let credential = GoogleDriveCredential()
		try await GoogleDriveAuthenticator.authenticate(credential: credential, from: viewController)
		let account = try CloudProviderAccount(accountUID: credential.getAccountID(), cloudProviderType: .googleDrive)
		try accountManager.saveNewAccount(account)
		return account
	}

	func authenticateOneDrive(from viewController: UIViewController) async throws -> CloudProviderAccount {
		return try await OneDriveAuthenticator.authenticate(from: viewController, cloudProviderAccountManager: accountManager, microsoftGraphAccountManager: microsoftGraphAccountManager)
	}

	func authenticateSharePoint(from viewController: UIViewController) async throws -> CloudProviderAccount {
		return try await SharePointAuthenticator.authenticate(from: viewController, cloudProviderAccountManager: accountManager, microsoftGraphAccountManager: microsoftGraphAccountManager)
	}

	func authenticatePCloud(from viewController: UIViewController) async throws -> CloudProviderAccount {
		let credential = try await PCloudAuthenticator.authenticate(from: viewController)
		try credential.saveToKeychain()
		let account = CloudProviderAccount(accountUID: credential.userID, cloudProviderType: .pCloud)
		try accountManager.saveNewAccount(account)
		return account
	}

	func authenticateBox(from viewController: UIViewController) async throws -> CloudProviderAccount {
		let tokenStorage = BoxTokenStorage()
		let credential = BoxCredential(tokenStorage: tokenStorage)
		_ = try await BoxAuthenticator.authenticate(from: viewController, tokenStorage: tokenStorage)
		let userID = try await credential.getUserID()
		tokenStorage.userID = userID // this will actually save the access token to the keychain
		let account = CloudProviderAccount(accountUID: userID, cloudProviderType: .box)
		try accountManager.saveNewAccount(account)
		return account
	}

	func authenticateWebDAV(from viewController: UIViewController) async throws -> CloudProviderAccount {
		let credential = try await WebDAVAuthenticator.authenticate(from: viewController)
		let account = CloudProviderAccount(accountUID: credential.identifier, cloudProviderType: .webDAV(type: .custom))
		try accountManager.saveNewAccount(account)
		return account
	}

	func authenticateS3(from viewController: UIViewController) async throws -> CloudProviderAccount {
		let credential = try await S3Authenticator.authenticate(from: viewController)
		let account = CloudProviderAccount(accountUID: credential.identifier, cloudProviderType: .s3(type: .custom))
		try accountManager.saveNewAccount(account)
		return account
	}

	func deauthenticate(account: CloudProviderAccount) throws {
		switch account.cloudProviderType {
		case .box:
			deauthenticateBox(account: account)
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

		Task {
			do {
				if !vaultUIDs.isEmpty {
					try await self.vaultManager.removeVaults(withUIDs: vaultUIDs)
					DDLogInfo("Removed \(vaultUIDs.count) vaults for deauthenticated account: \(account)")
				}
				try self.accountManager.removeAccount(with: account.accountUID)
			} catch {
				DDLogError("Deauthenticate account: \(account) failed with error: \(error)")
			}
		}
	}

	func deauthenticateBox(account: CloudProviderAccount) {
		let tokenStorage = BoxTokenStorage(userID: account.accountUID)
		let credential = BoxCredential(tokenStorage: tokenStorage)
		Task {
			do {
				try await credential.deauthenticate()
			} catch {
				DDLogError("Revoking the Box token of account: \(account) failed with error: \(error)")
			}
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
