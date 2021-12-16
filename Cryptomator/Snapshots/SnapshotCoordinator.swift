//
//  SnapshotCoordinator.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 13.12.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import FileProvider
import Foundation
import Promises

class SnapshotCoordinator: MainCoordinator {
	private static let vaultListViewModel = SnapshotVaultListViewModel()

	override func start() {
		swizzleViewController()
		resetOnboarding()
		unlockFullVersion()
		let vaultListViewController = VaultListViewController(with: SnapshotCoordinator.vaultListViewModel)
		vaultListViewController.coordinator = self
		navigationController.pushViewController(vaultListViewController, animated: false)
	}

	override func showVaultDetail(for vaultInfo: VaultInfo) {
		let snapshotFileProviderConnectorMock = SnapshotFileProviderConntectorMock()
		snapshotFileProviderConnectorMock.proxy = SnapshotVaultLockingMock()
		let viewModel = VaultDetailViewModel(vaultInfo: vaultInfo, vaultManager: VaultDBManager.shared, fileProviderConnector: SnapshotFileProviderConntectorMock(), passwordManager: VaultPasswordKeychainManager(), dbManager: DatabaseManager.shared)
		let vaultDetailViewController = VaultDetailViewController(viewModel: viewModel)
		navigationController.pushViewController(vaultDetailViewController, animated: true)
	}

	static func startShowingMockVaults() {
		vaultListViewModel.showMockVaults = true
	}

	private func resetOnboarding() {
		CryptomatorUserDefaults.shared.showOnboardingAtStartup = true
	}

	private func unlockFullVersion() {
		CryptomatorUserDefaults.shared.fullVersionUnlocked = true
	}

	private func swizzleViewController() {
		BaseUITableViewController.setSnapshotAccessibilityIdentifier
		OnboardingNavigationController.informAboutDisappear
	}
}

private class SnapshotFileProviderConntectorMock: FileProviderConnector {
	var proxy: Any?
	func getProxy<T>(serviceName: NSFileProviderServiceName, domainIdentifier: NSFileProviderDomainIdentifier) -> Promise<T> {
		return getCastedProxy()
	}

	func getProxy<T>(serviceName: NSFileProviderServiceName, domain: NSFileProviderDomain?) -> Promise<T> {
		return getCastedProxy()
	}

	private func getCastedProxy<T>() -> Promise<T> {
		guard let castedProxy = proxy as? T else {
			return Promise(FileProviderXPCConnectorError.typeMismatch)
		}
		return Promise(castedProxy)
	}
}

private class SnapshotVaultLockingMock: VaultLocking {
	func lockVault(domainIdentifier: NSFileProviderDomainIdentifier) {}

	func getIsUnlockedVault(domainIdentifier: NSFileProviderDomainIdentifier, reply: @escaping (Bool) -> Void) {
		reply(true)
	}

	func getUnlockedVaultDomainIdentifiers(reply: @escaping ([NSFileProviderDomainIdentifier]) -> Void) {
		fatalError()
	}

	var serviceName: NSFileProviderServiceName = .init("org.cryptomator.ios.vault-locking")

	func makeListenerEndpoint() throws -> NSXPCListenerEndpoint {
		fatalError()
	}
}

extension BaseUITableViewController {
	static let setSnapshotAccessibilityIdentifier: Void = {
		guard let originalMethod = class_getInstanceMethod(BaseUITableViewController.self, #selector(viewDidLoad)),
		      let swizzledMethod = class_getInstanceMethod(BaseUITableViewController.self, #selector(swizzled_viewDidLoad))
		else { return }
		method_exchangeImplementations(originalMethod, swizzledMethod)
	}()

	@objc func swizzled_viewDidLoad() {
		swizzled_viewDidLoad()
		tableView.accessibilityIdentifier = "Snapshot_\(String(describing: type(of: self)))"
	}
}

extension OnboardingNavigationController {
	static let informAboutDisappear: Void = {
		guard let originalMethod = class_getInstanceMethod(OnboardingNavigationController.self, #selector(viewWillDisappear(_:))),
		      let swizzledMethod = class_getInstanceMethod(OnboardingNavigationController.self, #selector(swizzled_viewWillDisappear(_:)))
		else { return }
		method_exchangeImplementations(originalMethod, swizzledMethod)
	}()

	@objc func swizzled_viewWillDisappear(_ animated: Bool) {
		swizzled_viewWillDisappear(animated)
		SnapshotCoordinator.startShowingMockVaults()
	}
}
