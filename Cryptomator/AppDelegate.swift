//
//  AppDelegate.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 27.04.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import CryptomatorCloudAccessCore
import CryptomatorCommon
import CryptomatorCommonCore
import MSAL
import ObjectiveDropboxOfficial
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
	var window: UIWindow?
	var coordinator: MainCoordinator?

	func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
		// Set up logger
		LoggerSetup.oneTimeSetup()

		// Set up database
		guard let dbURL = CryptomatorDatabase.sharedDBURL else {
			// MARK: Handle error

			print("dbURL is nil")
			return false
		}
		do {
			let dbPool = try CryptomatorDatabase.openSharedDatabase(at: dbURL)
			CryptomatorDatabase.shared = try CryptomatorDatabase(dbPool)
			DatabaseManager.shared = try DatabaseManager(dbPool: dbPool)
		} catch {
			// MARK: Handle error

			print("Error while initializing the CryptomatorDatabase: \(error)")
			return false
		}

		// Clean up
		VaultManager.shared.removeAllUnusedFileProviderDomains().then {
			print("removed all unused FileProviderDomains")
		}.catch { error in
			print("removeAllUnusedFileProviderDomains failed with error: \(error)")
		}

		// Set up cloud storage services
		CloudProviderManager.shared.useBackgroundSession = false
		DropboxSetup.constants = DropboxSetup(appKey: CloudAccessSecrets.dropboxAppKey, sharedContainerIdentifier: nil, keychainService: CryptomatorConstants.mainAppBundleId, forceForegroundSession: true)
		GoogleDriveSetup.constants = GoogleDriveSetup(clientId: CloudAccessSecrets.googleDriveClientId, redirectURL: CloudAccessSecrets.googleDriveRedirectURL!, sharedContainerIdentifier: nil)
		let oneDriveConfiguration = MSALPublicClientApplicationConfig(clientId: CloudAccessSecrets.oneDriveClientId, redirectUri: CloudAccessSecrets.oneDriveRedirectURI, authority: nil)
		oneDriveConfiguration.cacheConfig.keychainSharingGroup = CryptomatorConstants.mainAppBundleId
		do {
			OneDriveSetup.clientApplication = try MSALPublicClientApplication(configuration: oneDriveConfiguration)
		} catch {
			print("Error while setting up OneDrive: \(error)")
		}

		// Application-wide styling
		UINavigationBar.appearance().barTintColor = UIColor(named: "primary")
		UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: UIColor.white]
		UIBarButtonItem.appearance().tintColor = UIColor.white

		// Create window
		let navigationController = UINavigationController()
		coordinator = MainCoordinator(navigationController: navigationController)
		coordinator?.start()
		window = UIWindow(frame: UIScreen.main.bounds)
		window?.tintColor = UIColor(named: "primary")
		window?.rootViewController = navigationController
		window?.makeKeyAndVisible()
		return true
	}

	func application(_: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
		if url.scheme == CloudAccessSecrets.dropboxURLScheme {
			return DBClientsManager.handleRedirectURL(url) { authResult in
				guard let authResult = authResult else {
					return
				}
				if authResult.isSuccess() {
					let tokenUid = authResult.accessToken.uid
					let credential = DropboxCredential(tokenUID: tokenUid)
					DropboxAuthenticator.pendingAuthentication?.fulfill(credential)
				} else if authResult.isCancel() {
					DropboxAuthenticator.pendingAuthentication?.reject(DropboxAuthenticatorError.userCanceled)
				} else if authResult.isError() {
					DropboxAuthenticator.pendingAuthentication?.reject(authResult.nsError)
				}
			}
		} else if url.scheme == CloudAccessSecrets.googleDriveRedirectURLScheme {
			return GoogleDriveAuthenticator.currentAuthorizationFlow?.resumeExternalUserAgentFlow(with: url) ?? false
		} else if url.scheme == CloudAccessSecrets.oneDriveRedirectURIScheme {
			return MSALPublicClientApplication.handleMSALResponse(url, sourceApplication: options[.sourceApplication] as? String)
		}
		return false
	}
}
