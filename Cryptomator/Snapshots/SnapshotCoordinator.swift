//
//  SnapshotCoordinator.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 13.12.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

#if SNAPSHOTS
import CryptomatorCommonCore
import FileProvider
import Foundation
import LocalAuthentication
import Promises
import UIKit

class SnapshotCoordinator: MainCoordinator {
	private static let vaultListViewModel = SnapshotVaultListViewModel()

	override func start() {
		swizzleViewController()
		resetOnboarding()
		unlockFullVersion()
		super.start()
		guard navigationController.topViewController is VaultListViewController else {
			fatalError("NavigationController has different topViewController: \(String(describing: navigationController.topViewController))")
		}
		let vaultListViewController = VaultListViewController(with: SnapshotCoordinator.vaultListViewModel)
		vaultListViewController.coordinator = self
		navigationController.viewControllers = [vaultListViewController]
	}

	override func showVaultDetail(for vaultInfo: VaultInfo) {
		let snapshotFileProviderConnectorMock = SnapshotFileProviderConnectorMock()
		snapshotFileProviderConnectorMock.proxy = SnapshotVaultLockingMock()
		let viewModel = VaultDetailViewModel(vaultInfo: vaultInfo, vaultManager: VaultDBManager.shared, fileProviderConnector: snapshotFileProviderConnectorMock, passwordManager: SnapshotVaultPasswordManagerMock(), dbManager: DatabaseManager.shared, vaultKeepUnlockedSettings: SnapshotVaultKeepUnlockedSettings())
		let vaultDetailViewController = VaultDetailViewController(viewModel: viewModel)
		let detailNavigationController = BaseNavigationController(rootViewController: vaultDetailViewController)
		rootViewController.showDetailViewController(detailNavigationController, sender: nil)
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
		OnboardingViewController.skipPurchaseViewController
	}
}

private class SnapshotFileProviderConnectorMock: FileProviderConnector {
	var proxy: Any?
	func getXPC<T>(serviceName: NSFileProviderServiceName, domain: NSFileProviderDomain?) -> Promise<XPC<T>> {
		return getCastedProxy()
	}

	func getXPC<T>(serviceName: NSFileProviderServiceName, domainIdentifier: NSFileProviderDomainIdentifier) -> Promise<XPC<T>> {
		return getCastedProxy()
	}

	private func getCastedProxy<T>() -> Promise<XPC<T>> {
		guard let castedProxy = proxy as? T else {
			return Promise(FileProviderXPCConnectorError.typeMismatch)
		}
		return Promise(XPC(proxy: castedProxy))
	}
}

private class SnapshotVaultLockingMock: VaultLocking {
	func gracefulLockVault(domainIdentifier: NSFileProviderDomainIdentifier, reply: @escaping (Error?) -> Void) {
		reply(nil)
	}

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

class SnapshotVaultPasswordManagerMock: VaultPasswordManager {
	func setPassword(_ password: String, forVaultUID vaultUID: String) throws {}

	func getPassword(forVaultUID vaultUID: String, context: LAContext) throws -> String {
		return ""
	}

	func removePassword(forVaultUID vaultUID: String) throws {}

	func hasPassword(forVaultUID vaultUID: String) throws -> Bool {
		return true
	}
}

private class SnapshotVaultKeepUnlockedSettings: VaultKeepUnlockedSettings {
	func getKeepUnlockedDuration(forVaultUID vaultUID: String) -> KeepUnlockedDuration {
		return .tenMinutes
	}

	func setKeepUnlockedDuration(_ duration: KeepUnlockedDuration, forVaultUID vaultUID: String) throws {}

	func removeKeepUnlockedDuration(forVaultUID vaultUID: String) throws {}

	func getLastUsedDate(forVaultUID vaultUID: String) -> Date? {
		return nil
	}

	func setLastUsedDate(_ date: Date, forVaultUID vaultUID: String) throws {}
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

extension OnboardingViewController {
	static let skipPurchaseViewController: Void = {
		guard let originalMethod = class_getInstanceMethod(OnboardingViewController.self, #selector(tableView(_:didSelectRowAt:))),
		      let swizzledMethod = class_getInstanceMethod(OnboardingViewController.self, #selector(swizzled_tableView(_:didSelectRowAt:)))
		else { return }
		method_exchangeImplementations(originalMethod, swizzledMethod)
	}()

	@objc func swizzled_tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		SnapshotCoordinator.startShowingMockVaults()
		dismiss(animated: false)
	}
}
#endif
