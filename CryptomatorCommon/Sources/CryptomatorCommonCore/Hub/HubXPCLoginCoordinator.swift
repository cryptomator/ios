import AppAuthCore
import CryptoKit
import CryptomatorCloudAccessCore
import CryptomatorCryptoLib
import Dependencies
import JOSESwift
import SwiftUI
import UIKit

public final class HubXPCLoginCoordinator: Coordinator {
	public var childCoordinators = [Coordinator]()
	public var navigationController: UINavigationController
	let domain: NSFileProviderDomain
	let vaultConfig: UnverifiedVaultConfig
	public let onUnlocked: () -> Void
	public let onErrorAlertDismissed: () -> Void
	@Dependency(\.hubRepository) private var hubRepository
	@Dependency(\.fileProviderConnector) private var fileProviderConnector

	public init(navigationController: UINavigationController,
	            domain: NSFileProviderDomain,
	            vaultConfig: UnverifiedVaultConfig,
	            onUnlocked: @escaping () -> Void,
	            onErrorAlertDismissed: @escaping () -> Void) {
		self.navigationController = navigationController
		self.domain = domain
		self.vaultConfig = vaultConfig
		self.onUnlocked = onUnlocked
		self.onErrorAlertDismissed = onErrorAlertDismissed
	}

	public func start() {
		let unlockHandler = HubXPCVaultUnlockHandler(fileProviderConnector: fileProviderConnector, domain: domain, delegate: self)
		prepareNavigationControllerForLogin()
		let child = HubAuthenticationCoordinator(navigationController: navigationController,
		                                         vaultConfig: vaultConfig,
		                                         unlockHandler: unlockHandler,
		                                         parent: self,
		                                         delegate: self)
		childCoordinators.append(child)
		child.start()
	}

	/// Prepares the `UINavigationController` for the hub authentication flow.
	///
	/// As the FileProviderExtensionUI is always shown as a sheet and the login is initially just a alert which asks the user to open a website, we want to hide the navigation bar initially.
	private func prepareNavigationControllerForLogin() {
		navigationController.setNavigationBarHidden(true, animated: false)
	}
}

extension HubXPCLoginCoordinator: HubVaultUnlockHandlerDelegate {
	public func successfullyProcessedUnlockedVault() {
		onUnlocked()
	}

	public func failedToProcessUnlockedVault(error: Error) {
		handleError(error, for: navigationController, onOKTapped: onErrorAlertDismissed)
	}
}

extension HubXPCLoginCoordinator: HubAuthenticationCoordinatorDelegate {
	public func userDidCancelHubAuthentication() {
		onErrorAlertDismissed()
	}

	public func userDismissedHubAuthenticationErrorMessage() {
		onErrorAlertDismissed()
	}
}
