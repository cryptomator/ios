import AppAuthCore
import CryptoKit
import CryptomatorCloudAccessCore
import CryptomatorCryptoLib
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
		let viewController = UIHostingController(rootView: HubAuthenticationView(viewModel: viewModel))
		navigationController.pushViewController(viewController, animated: true)
	}
}

extension HubXPCLoginCoordinator: HubAuthenticationFlowDelegate {
	public func receivedExistingKey(jwe: JWE, privateKey: P384.KeyAgreement.PrivateKey) async {
		let masterkey: Masterkey
		do {
			masterkey = try JWEHelper.decrypt(jwe: jwe, with: privateKey)
		} catch {
			handleError(error, for: navigationController, onOKTapped: onErrorAlertDismissed)
			return
		}
		let xpc: XPC<VaultUnlocking>
		do {
			xpc = try await fileProviderConnector.getXPC(serviceName: .vaultUnlocking, domain: domain)
			defer {
				fileProviderConnector.invalidateXPC(xpc)
			}
			try await xpc.proxy.unlockVault(rawKey: masterkey.rawKey).getValue()
			fileProviderConnector.invalidateXPC(xpc)
			onUnlocked()
		} catch {
			handleError(error, for: navigationController, onOKTapped: onErrorAlertDismissed)
		}
	}
}

extension HubXPCLoginCoordinator: HubUserLogin {
	public func authenticate(with hubConfig: HubConfig) async throws -> OIDAuthState {
		try await hubAuthenticator.authenticate(with: hubConfig, from: navigationController)
	}
}
