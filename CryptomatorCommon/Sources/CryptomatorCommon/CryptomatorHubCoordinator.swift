//
//  CryptomatorHubCoordinator.swift
//
//
//  Created by Philipp Schmid on 22.07.22.
//

import AppAuthCore
import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import UIKit

public class CryptomatorHubCoordinator: Coordinator, HubVaultCoordinator, AddHubVaultCoordinator {
	public lazy var childCoordinators = [Coordinator]()
	public var navigationController: UINavigationController
	public weak var parentCoordinator: Coordinator?
	let vaultItem: VaultItem
	let accountUID: String
	let downloadedVaultConfig: DownloadedVaultConfig

	public init(vaultItem: VaultItem, accountUID: String, downloadedVaultConfig: DownloadedVaultConfig, navigationController: UINavigationController) {
		self.accountUID = accountUID
		self.downloadedVaultConfig = downloadedVaultConfig
		self.vaultItem = vaultItem
		self.navigationController = navigationController
	}

	public func start() {
		let viewModel = AddHubVaultViewModel(downloadedVaultConfig: downloadedVaultConfig, vaultItem: vaultItem, vaultUID: UUID().uuidString, delegateAccountUID: accountUID, coordinator: self)
		let addHubVaultVC = HubVaultViewController(viewModel: viewModel)
		navigationController.pushViewController(addHubVaultVC, animated: true)
	}

	public func handleError(_ error: Error) {
		handleError(error, for: navigationController) {
			self.navigationController.popViewController(animated: true)
			self.parentCoordinator?.childDidFinish(self)
		}
	}

	public func authenticate(with hubConfig: HubConfig) async throws -> OIDAuthState {
		return try await CryptomatorHubAuthenticator.shared.authenticate(with: hubConfig, from: navigationController)
	}

	public func addedVault(withName name: String, vaultUID: String) {
		guard let delegate = parentCoordinator as? CryptomatorHubCoordinatorDelegate else {
			return
		}
		delegate.addedVault(withName: name, vaultUID: vaultUID)
		parentCoordinator?.childDidFinish(self)
	}
}

public protocol CryptomatorHubCoordinatorDelegate: AnyObject {
	func addedVault(withName name: String, vaultUID: String)
}

protocol AddHubVaultCoordinator: AnyObject {
	func authenticate(with hubConfig: HubConfig) async throws -> OIDAuthState
	func addedVault(withName name: String, vaultUID: String)
}
