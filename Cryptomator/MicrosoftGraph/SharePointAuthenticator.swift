//
//  SharePointAuthenticator.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 11.03.25.
//  Copyright © 2025 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import GRDB
import UIKit

public class SharePointAuthenticator {
	@MainActor private static var coordinator: SharePointAuthenticationCoordinator?

	public static func authenticate(from viewController: UIViewController, cloudProviderAccountManager: CloudProviderAccountManager, microsoftGraphAccountManager: MicrosoftGraphAccountManager) async throws -> CloudProviderAccount {
		let navigationController = BaseNavigationController()
		let sharePointCoordinator = SharePointAuthenticationCoordinator(navigationController: navigationController)
		coordinator = sharePointCoordinator
		defer {
			coordinator = nil
		}
		viewController.present(navigationController, animated: true)
		sharePointCoordinator.start()
		let credential = try await sharePointCoordinator.pendingAuthentication.value
		let newAccountUID = UUID().uuidString
		let cloudProviderAccount = CloudProviderAccount(accountUID: newAccountUID, cloudProviderType: .microsoftGraph(type: .sharePoint))
		try cloudProviderAccountManager.saveNewAccount(cloudProviderAccount) // Make sure to save this first, because Microsoft Graph account has a reference to the Cloud Provider account.
		do {
			let microsoftGraphAccount = MicrosoftGraphAccount(accountUID: newAccountUID, credentialID: credential.credential.identifier, driveID: credential.driveID, siteURL: credential.siteURL, type: .sharePoint)
			try microsoftGraphAccountManager.saveNewAccount(microsoftGraphAccount)
			return cloudProviderAccount
		} catch let dbError as DatabaseError where dbError.resultCode == .SQLITE_CONSTRAINT {
			try cloudProviderAccountManager.removeAccount(with: newAccountUID)
			let existingMicrosoftGraphAccount = try microsoftGraphAccountManager.getAccount(credentialID: credential.credential.identifier, driveID: credential.driveID, type: .sharePoint)
			return try cloudProviderAccountManager.getAccount(for: existingMicrosoftGraphAccount.accountUID)
		} catch {
			throw error
		}
	}
}
