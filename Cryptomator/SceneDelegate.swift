//
//  SceneDelegate.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 02.10.26.
//  Copyright © 2026 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCloudAccess
import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import MSAL
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
	var window: UIWindow?
	private var coordinator: MainCoordinator?

	func scene(_ scene: UIScene, willConnectTo _: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
		guard let windowScene = scene as? UIWindowScene else {
			return
		}
		coordinator = MainCoordinator()
		#if SNAPSHOTS
		coordinator = SnapshotCoordinator()
		UIView.setAnimationsEnabled(false)
		#endif
		coordinator?.start()
		StoreObserver.shared.fallbackDelegate = coordinator
		window = UIWindow(windowScene: windowScene)
		window?.tintColor = .cryptomatorPrimary
		window?.rootViewController = coordinator?.rootViewController
		window?.makeKeyAndVisible()

		// A cold launch delivers its URLs and user activities here instead of through the callbacks below.
		// Lay out first, since presenting from a URL needs the split view's children in the window hierarchy.
		window?.layoutIfNeeded()
		self.scene(scene, openURLContexts: connectionOptions.urlContexts)
		for userActivity in connectionOptions.userActivities {
			self.scene(scene, continue: userActivity)
		}
	}

	func scene(_: UIScene, openURLContexts urlContexts: Set<UIOpenURLContext>) {
		for urlContext in urlContexts {
			open(urlContext.url, sourceApplication: urlContext.options.sourceApplication)
		}
	}

	func sceneDidBecomeActive(_: UIScene) {
		PremiumManager.shared.refreshStatus()
	}

	func scene(_: UIScene, continue userActivity: NSUserActivity) {
		switch userActivity.activityType {
		case "OpenVaultIntent":
			handleOpenInFilesApp(for: userActivity)
		default:
			DDLogInfo("Received an unsupported userActivity of type: \(String(describing: userActivity.activityType))")
		}
	}

	private func open(_ url: URL, sourceApplication: String?) {
		if url.scheme == "cryptomator" {
			if url.host == "purchase" {
				coordinator?.showPurchase()
			}
		} else if url.scheme == CloudAccessSecrets.dropboxURLScheme {
			_ = DropboxAuthenticator.handleRedirectURL(url)
		} else if url.scheme == CloudAccessSecrets.googleDriveRedirectURLScheme {
			try? GoogleDriveAuthenticator.currentAuthorizationFlow?.resumeExternalUserAgentFlow(url)
		} else if url.scheme == CloudAccessSecrets.microsoftGraphRedirectURIScheme {
			MSALPublicClientApplication.handleMSALResponse(url, sourceApplication: sourceApplication)
		}
	}

	private func handleOpenInFilesApp(for userActivity: NSUserActivity) {
		guard let vaultUID = userActivity.userInfo?["vaultUID"] as? String else {
			DDLogError("Received a userActivity of type: \(String(describing: userActivity.activityType)) which has no vaultUID.")
			return
		}
		FilesAppUtil.showFilesApp(forVaultUID: vaultUID)
	}
}
