//
//  AppDelegate.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 27.04.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCloudAccessCore
import CryptomatorCommon
import CryptomatorCommonCore
import Dependencies
import MSAL
import StoreKit
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
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
		do {
			let microsoftGraphConfiguration = MSALPublicClientApplicationConfig(clientId: CloudAccessSecrets.microsoftGraphClientId, redirectUri: CloudAccessSecrets.microsoftGraphRedirectURI, authority: nil)
			microsoftGraphConfiguration.cacheConfig.keychainSharingGroup = CryptomatorConstants.mainAppBundleId
			let microsoftGraphClientApplication = try MSALPublicClientApplication(configuration: microsoftGraphConfiguration)
			MicrosoftGraphSetup.constants = MicrosoftGraphSetup(clientApplication: microsoftGraphClientApplication, sharedContainerIdentifier: nil)
		} catch {
			DDLogError("Setting up OneDrive failed with error: \(error)")
		}
		PCloudSetup.constants = PCloudSetup(appKey: CloudAccessSecrets.pCloudAppKey, sharedContainerIdentifier: nil)
		BoxSetup.constants = BoxSetup(clientId: CloudAccessSecrets.boxClientId, clientSecret: CloudAccessSecrets.boxClientSecret, sharedContainerIdentifier: nil)

		// Set up payment queue
		SKPaymentQueue.default().add(StoreObserver.shared)
		return true
	}

	func applicationWillTerminate(_ application: UIApplication) {
		SKPaymentQueue.default().remove(StoreObserver.shared)
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
