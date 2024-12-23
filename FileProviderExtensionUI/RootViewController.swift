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
import CryptomatorFileProvider
import Dependencies
import FileProviderUI
import MSAL
import Promises
import UIKit

class RootViewController: FPUIActionExtensionViewController {
	private lazy var coordinator: FileProviderCoordinator = {
		#if SNAPSHOTS
		return FileProviderCoordinatorSnapshotMock(extensionContext: extensionContext, hostViewController: self)
		#else
		return .init(extensionContext: extensionContext, hostViewController: self)
		#endif
	}()

	@Dependency(\.fileProviderConnector) private var fileProviderConnector

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
		return {}
	}()

	func retryUpload(for itemIdentifiers: [NSFileProviderItemIdentifier], domainIdentifier: NSFileProviderDomainIdentifier) {
		let getXPCPromise: Promise<XPC<UploadRetrying>> = fileProviderConnector.getXPC(serviceName: .uploadRetryingService, domainIdentifier: domainIdentifier)
		getXPCPromise.then { xpc in
			return wrap {
				xpc.proxy.retryUpload(for: itemIdentifiers, reply: $0)
			}
		}.then {
			if let error = $0 {
				throw error
			}
			self.extensionContext.completeRequest()
		}.catch { error in
			DDLogError("Retry upload failed with error: \(error)")
			self.extensionContext.cancelRequest(withError: NSError(domain: FPUIErrorDomain, code: Int(FPUIExtensionErrorCode.failed.rawValue), userInfo: nil))
		}.always { [fileProviderConnector] in
			fileProviderConnector.invalidateXPC(getXPCPromise)
		}
	}

	func showDomainNotFoundAlert() {
		let alertController = RetryUploadAlertControllerFactory.createDomainNotFoundAlert(okAction: { [weak self] in
			self?.cancel()
		})
		present(alertController, animated: true)
	}

	func showUploadProgressAlert(for itemIdentifiers: [NSFileProviderItemIdentifier], domainIdentifier: NSFileProviderDomainIdentifier) {
		let getXPCPromise: Promise<XPC<UploadRetrying>> = fileProviderConnector.getXPC(serviceName: .uploadRetryingService, domainIdentifier: domainIdentifier)
		let progressAlert = RetryUploadAlertControllerFactory.createUploadProgressAlert(dismissAction: { [weak self] in
			self?.cancel()
		}, retryAction: { [weak self] in
			self?.retryUpload(for: itemIdentifiers, domainIdentifier: domainIdentifier)
		})
		getXPCPromise.then { xpc -> Promise<Void> in
			let observeProgressPromise = progressAlert.observeProgress(itemIdentifier: itemIdentifiers[0], proxy: xpc.proxy)
			let alertActionPromise = progressAlert.alertActionTriggered
			return race([observeProgressPromise, alertActionPromise])
		}.always { [fileProviderConnector] in
			self.extensionContext.completeRequest()
			fileProviderConnector.invalidateXPC(getXPCPromise)
		}
		present(progressAlert, animated: true)
	}

	func showEvictFileFromCacheAlert(for itemIdentifiers: [NSFileProviderItemIdentifier], domainIdentifier: NSFileProviderDomainIdentifier) {
		let alertController = UIAlertController(title: LocalizedString.getValue("fileProvider.clearFileFromCache.title"),
		                                        message: LocalizedString.getValue("fileProvider.clearFileFromCache.message"),
		                                        preferredStyle: .alert)
		let deleteAction = UIAlertAction(title: LocalizedString.getValue("common.button.clear"), style: .destructive) { _ in
			alertController.dismiss(animated: true) {
				self.evictFilesFromCache(with: itemIdentifiers, domainIdentifier: domainIdentifier)
			}
		}
		let cancelAction = UIAlertAction(title: LocalizedString.getValue("common.button.cancel"), style: .cancel) { _ in
			self.cancel()
		}
		alertController.addAction(deleteAction)
		alertController.addAction(cancelAction)
		alertController.preferredAction = cancelAction

		present(alertController, animated: true)
	}

	func evictFilesFromCache(with itemIdentifiers: [NSFileProviderItemIdentifier], domainIdentifier: NSFileProviderDomainIdentifier) {
		let getXPCPromise: Promise<XPC<CacheManaging>> = fileProviderConnector.getXPC(serviceName: .cacheManaging, domainIdentifier: domainIdentifier)
		getXPCPromise.then { xpc in
			xpc.proxy.evictFilesFromCache(with: itemIdentifiers)
		}.catch { error in
			let alertController = UIAlertController(title: LocalizedString.getValue("common.alert.error.title"),
			                                        message: error.localizedDescription,
			                                        preferredStyle: .alert)
			let okAction = UIAlertAction(title: LocalizedString.getValue("common.button.ok"), style: .default) { _ in
				self.extensionContext.completeRequest()
			}
			alertController.addAction(okAction)
			alertController.preferredAction = okAction
			self.present(alertController, animated: true)
		}.then {
			self.extensionContext.completeRequest()
		}.always { [fileProviderConnector] in
			fileProviderConnector.invalidateXPC(getXPCPromise)
		}
	}

	// MARK: - FPUIActionExtensionViewController

	override func prepare(forError error: Error) {
		coordinator.startWith(error: error)
	}

	override func prepare(forAction actionIdentifier: String, itemIdentifiers: [NSFileProviderItemIdentifier]) {
		let action = FileProviderAction(rawValue: actionIdentifier)
		switch action {
		case .retryWaitingUpload:
			if let domainIdentifier = itemIdentifiers.first?.domainIdentifier {
				showUploadProgressAlert(for: itemIdentifiers, domainIdentifier: domainIdentifier)
			} else {
				showDomainNotFoundAlert()
			}
		case .retryFailedUpload:
			if let domainIdentifier = itemIdentifiers.first?.domainIdentifier {
				retryUpload(for: itemIdentifiers, domainIdentifier: domainIdentifier)
			} else {
				showDomainNotFoundAlert()
			}
		case .evictFileFromCache:
			if let domainIdentifier = itemIdentifiers.first?.domainIdentifier {
				showEvictFileFromCacheAlert(for: itemIdentifiers, domainIdentifier: domainIdentifier)
			} else {
				showDomainNotFoundAlert()
			}
		case .none:
			let error = NSError(domain: NSCocoaErrorDomain, code: NSFeatureUnsupportedError, userInfo: [:])
			extensionContext.cancelRequest(withError: error)
		}
	}
}
