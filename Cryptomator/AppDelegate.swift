//
//  AppDelegate.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 27.04.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCloudAccess
import CryptomatorCloudAccessCore
import CryptomatorCommon
import CryptomatorCommonCore
import MSAL
import ObjectiveDropboxOfficial
import StoreKit
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

			DDLogError("dbURL is nil")
			return false
		}
		do {
			let dbPool = try CryptomatorDatabase.openSharedDatabase(at: dbURL)
			CryptomatorDatabase.shared = try CryptomatorDatabase(dbPool)
			DatabaseManager.shared = try DatabaseManager(dbPool: dbPool)
		} catch {
			// MARK: Handle error

			DDLogError("Initializing CryptomatorDatabase failed with error: \(error)")
			return false
		}
		VaultDBManager.shared.recoverMissingFileProviderDomains().catch { error in
			DDLogError("Recover missing FileProvider domains failed with error: \(error)")
		}
		// Clean up
		do {
			let webDAVAccountUIDs = try CloudProviderAccountDBManager.shared.getAllAccountUIDs(for: .webDAV(type: .custom))
			try WebDAVAuthenticator.removeUnusedWebDAVCredentials(existingAccountUIDs: webDAVAccountUIDs)
		} catch {
			DDLogError("Clean up unused WebDAV Credentials failed with error: \(error)")
		}

		// Set up cloud storage services
		CloudProviderDBManager.shared.useBackgroundSession = false
		DropboxSetup.constants = DropboxSetup(appKey: CloudAccessSecrets.dropboxAppKey, sharedContainerIdentifier: nil, keychainService: CryptomatorConstants.mainAppBundleId, forceForegroundSession: true)
		GoogleDriveSetup.constants = GoogleDriveSetup(clientId: CloudAccessSecrets.googleDriveClientId, redirectURL: CloudAccessSecrets.googleDriveRedirectURL!, sharedContainerIdentifier: nil)
		let oneDriveConfiguration = MSALPublicClientApplicationConfig(clientId: CloudAccessSecrets.oneDriveClientId, redirectUri: CloudAccessSecrets.oneDriveRedirectURI, authority: nil)
		oneDriveConfiguration.cacheConfig.keychainSharingGroup = CryptomatorConstants.mainAppBundleId
		do {
			OneDriveSetup.clientApplication = try MSALPublicClientApplication(configuration: oneDriveConfiguration)
		} catch {
			DDLogError("Setting up OneDrive failed with error: \(error)")
		}

		// Set up payment queue
		SKPaymentQueue.default().add(StoreObserver.shared)

		// Create window
		coordinator = MainCoordinator()
		#if SNAPSHOTS
		coordinator = SnapshotCoordinator()
		UIView.setAnimationsEnabled(false)
		#endif
		coordinator?.start()
		StoreObserver.shared.fallbackDelegate = coordinator
		window = UIWindow(frame: UIScreen.main.bounds)
		window?.tintColor = UIColor(named: "primary")
		window?.rootViewController = coordinator?.rootViewController
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

	func applicationDidBecomeActive(_ application: UIApplication) {
		PremiumManager.shared.refreshStatus()
	}

	func applicationWillTerminate(_ application: UIApplication) {
		SKPaymentQueue.default().remove(StoreObserver.shared)
	}
}
