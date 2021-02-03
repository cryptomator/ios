//
//  AppDelegate.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 27.04.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import CloudAccessPrivate
import CloudAccessPrivateCore
import ObjectiveDropboxOfficial
import UIKit
@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
	var window: UIWindow?
	var coordinator: MainCoordinator?

	func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
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

		// FIXME: Dirty hack, which nukes database when there is a new version
		let userDefaults = UserDefaults.standard
		let appVersionKey = "CryptomatorUserDefaultAppVersion"
		let currentAppVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
		let previousVersion = userDefaults.string(forKey: appVersionKey)
		if previousVersion == nil || previousVersion != currentAppVersion {
			do {
				let dbPool = DatabaseManager.shared.dbPool
				try dbPool.erase()
				CryptomatorDatabase.shared = try CryptomatorDatabase(dbPool)
				DatabaseManager.shared = try DatabaseManager(dbPool: dbPool)
			} catch {
				print("Error while nuking the CryptomatorDatabase: \(error)")
				return false
			}
		}
		userDefaults.set(currentAppVersion, forKey: appVersionKey)

		VaultManager.shared.removeAllUnusedFileProviderDomains().then {
			print("removed all unused FileProviderDomains")
		}.catch { error in
			print("removeAllUnusedFileProviderDomains failed with error: \(error)")
		}
		CloudProviderManager.shared.useBackgroundSession = false

		// Application wide styling
		UINavigationBar.appearance().barTintColor = UIColor(named: "primary")
		UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: UIColor.white]
		UIBarButtonItem.appearance().tintColor = UIColor.white

		let navigationController = UINavigationController()
		coordinator = MainCoordinator(navigationController: navigationController)
		coordinator?.start()

		window = UIWindow(frame: UIScreen.main.bounds)
		window?.rootViewController = navigationController
		window?.makeKeyAndVisible()
		return true
	}

	func application(_: UIApplication, open url: URL, options _: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
		if url.scheme == CloudAccessSecrets.dropboxURLScheme {
			let canHandle = DBClientsManager.handleRedirectURL(url) { authResult in
				guard let authResult = authResult else {
					return
				}
				if authResult.isSuccess() {
					let tokenUid = authResult.accessToken.uid
					let credential = DropboxCredential(tokenUid: tokenUid)
					DropboxCloudAuthenticator.pendingAuthentication?.fulfill(credential)
				} else if authResult.isCancel() {
					DropboxCloudAuthenticator.pendingAuthentication?.reject(DropboxAuthenticationError.userCanceled)
				} else if authResult.isError() {
					DropboxCloudAuthenticator.pendingAuthentication?.reject(authResult.nsError)
				}
			}
			return canHandle
		}
		return true
	}
}
