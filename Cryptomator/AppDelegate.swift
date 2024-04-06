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
import Dependencies
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

		// Set up IAP Checker
		setupIAP()

		// Set up database
		DatabaseManager.shared = DatabaseManager()

		VaultDBManager.shared.recoverMissingFileProviderDomains().catch { error in
			DDLogError("Recover missing FileProvider domains failed with error: \(error)")
		}
		cleanup()

		// Set up cloud storage services
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
		window?.tintColor = .cryptomatorPrimary
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

	func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
		switch userActivity.activityType {
		case "OpenVaultIntent":
			return handleOpenInFilesApp(for: userActivity)
		default:
			DDLogInfo("Received an unsupported userActivity of type: \(String(describing: userActivity.activityType))")
			return false
		}
	}

	private func handleOpenInFilesApp(for userActivity: NSUserActivity) -> Bool {
		guard let vaultUID = userActivity.userInfo?["vaultUID"] as? String else {
			DDLogError("Received a userActivity of type: \(String(describing: userActivity.activityType)) which has no vaultUID.")
			return false
		}
		FilesAppUtil.showFilesApp(forVaultUID: vaultUID)
		return true
	}

	private func cleanup() {
		_ = VaultDBManager.shared.removeAllUnusedFileProviderDomains()
		do {
			let webDAVAccountUIDs = try CloudProviderAccountDBManager.shared.getAllAccountUIDs(for: .webDAV(type: .custom))
			try WebDAVCredentialManager.shared.removeUnusedWebDAVCredentials(existingAccountUIDs: webDAVAccountUIDs)
		} catch {
			DDLogError("Clean up unused WebDAV Credentials failed with error: \(error)")
		}
	}

	private func setupIAP() {
		#if ALWAYS_PREMIUM
		DDLogDebug("Always activated premium")
		CryptomatorUserDefaults.shared.fullVersionUnlocked = true
		#else
		DDLogDebug("Freemium version")
		#endif
	}
}

/**
 Define the liveValue in the main target since compilation flags do not work on Swift Package Manager level.
 Be aware that it is needed to set the default value once per app launch (+ also when launching the FileProviderExtension).
 */
extension FullVersionCheckerKey: DependencyKey {
	public static var liveValue: FullVersionChecker {
		#if ALWAYS_PREMIUM
		return AlwaysActivatedPremium.default
		#else
		return UserDefaultsFullVersionChecker.default
		#endif
	}
}
