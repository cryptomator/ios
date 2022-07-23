//
//  File.swift
//
//
//  Created by Philipp Schmid on 22.07.22.
//

import AppAuthCore
import CryptomatorCloudAccessCore
import Foundation
import UIKit

public protocol HubVaultCoordinator: AnyObject {
	var parentCoordinator: Coordinator? { get set }
	func handleError(_ error: Error)
}

public extension HubVaultCoordinator where Self: Coordinator {
	func handleError(_ error: Error) {
		handleError(error, for: navigationController) {
			self.navigationController.popViewController(animated: true)
			self.parentCoordinator?.childDidFinish(self)
		}
	}
}

public protocol HubVaultUnlockDelegate: AnyObject {
	func unlockedVault()
}

public class CryptomatorHubVaultUnlockCoordinator: Coordinator, HubVaultCoordinator {
	public lazy var childCoordinators = [Coordinator]()
	public var navigationController: UINavigationController
	public weak var parentCoordinator: Coordinator?
	public weak var delegate: HubVaultUnlockDelegate?
	let domain: NSFileProviderDomain
	let hubAccount: HubAccount
	let vaultConfig: UnverifiedVaultConfig

	public init(navigationController: UINavigationController, domain: NSFileProviderDomain, hubAccount: HubAccount, vaultConfig: UnverifiedVaultConfig, parentCoordinator: Coordinator? = nil) {
		self.navigationController = navigationController
		self.domain = domain
		self.hubAccount = hubAccount
		self.vaultConfig = vaultConfig
		self.parentCoordinator = parentCoordinator
	}

	public func start() {
		let viewModel = HubVaultUnlockViewModel(hubAccount: hubAccount,
		                                        domain: domain,
		                                        fileProviderConnector: FileProviderXPCConnector.shared,
		                                        vaultConfig: vaultConfig,
		                                        coordinator: self)
		let addHubVaultVC = HubVaultViewController(viewModel: viewModel)
		navigationController.pushViewController(addHubVaultVC, animated: true)
	}
}

extension CryptomatorHubVaultUnlockCoordinator: HubVaultUnlockDelegate {
	public func unlockedVault() {
		delegate?.unlockedVault()
		parentCoordinator?.childDidFinish(self)
	}
}
