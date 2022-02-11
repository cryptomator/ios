//
//  RootViewController.swift
//  FileProviderExtensionUI
//
//  Created by Philipp Schmid on 29.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import FileProviderUI
import MSAL
import UIKit

class RootViewController: FPUIActionExtensionViewController {
	private lazy var coordinator: FileProviderCoordinator = {
		#if SNAPSHOTS
		return FileProviderCoordinatorSnapshotMock(extensionContext: extensionContext, hostViewController: self)
		#else
		return .init(extensionContext: extensionContext, hostViewController: self)
		#endif
	}()

	override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
		super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
		NotificationCenter.default.addObserver(self,
		                                       selector: #selector(extensionHostDidEnterBackground),
		                                       name: NSNotification.Name.NSExtensionHostDidEnterBackground,
		                                       object: nil)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	/**
	 To prevent a visible dismiss of the `RootViewController` when the FileProviderExtensionUI was in the background and becomes active again, we cancel the request as soon as the host app (Files app) switches to the background.
	 */
	@objc func extensionHostDidEnterBackground() {
		cancel()
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		RootViewController.oneTimeSetup()
	}

	@objc func cancel() {
		extensionContext.cancelRequest(withError: NSError(domain: FPUIErrorDomain, code: Int(FPUIExtensionErrorCode.userCancelled.rawValue), userInfo: nil))
	}

	static var oneTimeSetup: () -> Void = {
		// Set up logger
		LoggerSetup.oneTimeSetup()
		// Set up database
		guard let dbURL = CryptomatorDatabase.sharedDBURL else {
			// MARK: Handle error

			DDLogError("dbURL is nil")
			return {}
		}
		do {
			let dbPool = try CryptomatorDatabase.openSharedDatabase(at: dbURL)
			CryptomatorDatabase.shared = try CryptomatorDatabase(dbPool)
		} catch {
			// MARK: Handle error

			DDLogError("Initializing CryptomatorDatabase failed with error: \(error)")
			return {}
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
		return {}
	}()

	// MARK: - FPUIActionExtensionViewController

	override func prepare(forError error: Error) {
		coordinator.startWith(error: error)
	}
}
