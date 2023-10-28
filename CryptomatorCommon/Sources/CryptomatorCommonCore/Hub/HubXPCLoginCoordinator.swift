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
	let fileProviderConnector: FileProviderConnector
	let hubAuthenticator: HubAuthenticating
	public let onUnlocked: () -> Void
	public let onErrorAlertDismissed: () -> Void
	@Dependency(\.hubRepository) private var hubRepository

	public init(navigationController: UINavigationController,
	            domain: NSFileProviderDomain,
	            vaultConfig: UnverifiedVaultConfig,
	            fileProviderConnector: FileProviderConnector = FileProviderXPCConnector.shared,
	            hubAuthenticator: HubAuthenticating,
	            onUnlocked: @escaping () -> Void,
	            onErrorAlertDismissed: @escaping () -> Void) {
		self.navigationController = navigationController
		self.domain = domain
		self.vaultConfig = vaultConfig
		self.fileProviderConnector = fileProviderConnector
		self.hubAuthenticator = hubAuthenticator
		self.onUnlocked = onUnlocked
		self.onErrorAlertDismissed = onErrorAlertDismissed
	}

	public func start() {
		let viewModel = HubAuthenticationViewModel(vaultConfig: vaultConfig,
		                                           hubUserAuthenticator: self,
		                                           delegate: self)
		let viewController = HubAuthenticationViewController(viewModel: viewModel)
		navigationController.pushViewController(viewController, animated: true)
	}
}

extension HubXPCLoginCoordinator: HubAuthenticationFlowDelegate {
	public func didSuccessfullyRemoteUnlock(_ response: HubUnlockResponse) async {
		let masterkey: Masterkey
		do {
			masterkey = try JWEHelper.decrypt(jwe: response.jwe, with: response.privateKey)
		} catch {
			handleError(error, for: navigationController, onOKTapped: onErrorAlertDismissed)
			return
		}
		do {
			let xpc: XPC<VaultUnlocking> = try await fileProviderConnector.getXPC(serviceName: .vaultUnlocking, domain: domain)
			defer {
				fileProviderConnector.invalidateXPC(xpc)
			}
			try await xpc.proxy.unlockVault(rawKey: masterkey.rawKey).getValue()
			let hubVault = HubVault(vaultUID: domain.identifier.rawValue, subscriptionState: response.subscriptionState)
			try hubRepository.save(hubVault)
			onUnlocked()
		} catch {
			handleError(error, for: navigationController, onOKTapped: onErrorAlertDismissed)
			return
		}
	}
}

extension HubXPCLoginCoordinator: HubUserLogin {
	public func authenticate(with hubConfig: HubConfig) async throws -> OIDAuthState {
		try await hubAuthenticator.authenticate(with: hubConfig, from: navigationController)
	}
}
