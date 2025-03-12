//
//  OneDriveAuthenticator.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 12.03.25.
//  Copyright © 2025 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import GRDB
import Promises
import UIKit

public class OneDriveAuthenticator {
	public static func authenticate(from viewController: UIViewController, cloudProviderAccountManager: CloudProviderAccountManager, microsoftGraphAccountManager: MicrosoftGraphAccountManager) -> Promise<CloudProviderAccount> {
		return MicrosoftGraphAuthenticator.authenticate(from: viewController, for: .oneDrive).then { credential -> CloudProviderAccount in
			let accountUID = UUID().uuidString
			let cloudProviderAccount = CloudProviderAccount(accountUID: accountUID, cloudProviderType: .microsoftGraph(type: .oneDrive))
			try cloudProviderAccountManager.saveNewAccount(cloudProviderAccount) // Make sure to save this first, because Microsoft Graph account has a reference to the Cloud Provider account.
			do {
				let microsoftGraphAccount = MicrosoftGraphAccount(accountUID: accountUID, credentialID: credential.identifier, type: .oneDrive)
				try microsoftGraphAccountManager.saveNewAccount(microsoftGraphAccount)
				return cloudProviderAccount
			} catch let dbError as DatabaseError where dbError.resultCode == .SQLITE_CONSTRAINT {
				try cloudProviderAccountManager.removeAccount(with: accountUID)
				let existingMicrosoftGraphAccount = try microsoftGraphAccountManager.getAccount(credentialID: credential.identifier, driveID: nil, type: .oneDrive)
				return try cloudProviderAccountManager.getAccount(for: existingMicrosoftGraphAccount.accountUID)
			} catch {
				throw error
			}
		}
	}
}
