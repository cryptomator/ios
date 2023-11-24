//
//  FileProviderCoordinator.swift
//  FileProviderExtensionUI
//
//  Created by Philipp Schmid on 29.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCloudAccessCore
import CryptomatorCommon
import CryptomatorCommonCore
import CryptomatorFileProvider
import FileProviderUI
import LocalAuthentication
import UIKit

class FileProviderCoordinator: Coordinator {
	lazy var childCoordinators = [Coordinator]()
	lazy var navigationController: UINavigationController = {
		let appearance = UINavigationBarAppearance()
		appearance.configureWithOpaqueBackground()
		appearance.backgroundColor = .cryptomatorPrimary
		appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
		let navigationController = UINavigationController()
		navigationController.navigationBar.standardAppearance = appearance
		navigationController.navigationBar.scrollEdgeAppearance = appearance
		navigationController.navigationBar.tintColor = .white
		addViewControllerAsChildToHost(navigationController)
		return navigationController
	}()

	private let extensionContext: FPUIActionExtensionContext
	private weak var hostViewController: UIViewController?

	init(extensionContext: FPUIActionExtensionContext, hostViewController: UIViewController) {
		self.extensionContext = extensionContext
		self.hostViewController = hostViewController
	}

	func userCancelled() {
		extensionContext.cancelRequest(withError: NSError(domain: FPUIErrorDomain, code: Int(FPUIExtensionErrorCode.userCancelled.rawValue), userInfo: nil))
	}

	func start() {}

	func startWith(error: Error) {
		let error = error as NSError
		let userInfo = error.userInfo
		guard let internalError = userInfo[NSUnderlyingErrorKey] as? Error, let vaultName = userInfo[VaultNameErrorKey] as? String, let pathRelativeToDocumentStorage = userInfo[PathRelativeToDocumentStorageErrorKey] as? String, let domainIdentifier = userInfo[DomainIdentifierErrorKey] as? NSFileProviderDomainIdentifier else {
			showOnboarding()
			return
		}
		let domain = NSFileProviderDomain(identifier: domainIdentifier, displayName: vaultName, pathRelativeToDocumentStorage: pathRelativeToDocumentStorage)

		switch internalError {
		case let unlockError as UnlockError:
			startAuthentication(for: domain, unlockError: unlockError)
		default:
			showOnboarding()
		}
	}

	func handleError(_ error: Error, for viewController: UIViewController) {
		DDLogError("Error: \(error)")
		let alertController = UIAlertController(title: LocalizedString.getValue("common.alert.error.title"), message: error.localizedDescription, preferredStyle: .alert)
		alertController.addAction(UIAlertAction(title: LocalizedString.getValue("common.button.ok"), style: .default))
		viewController.present(alertController, animated: true)
	}

	func done() {
		extensionContext.completeRequest()
	}

	// MARK: - Onboarding

	func showOnboarding() {
		let onboardingVC = OnboardingViewController()
		onboardingVC.coordinator = self
		navigationController.pushViewController(onboardingVC, animated: false)
	}

	func openCryptomatorApp() {
		let url = URL(string: "cryptomator:")!
		extensionContext.open(url) { success in
			if success {
				self.userCancelled()
			}
		}
	}

	// MARK: - Vault Unlock

	func startAuthentication(for domain: NSFileProviderDomain, unlockError: UnlockError) {
		let viewModel = UnlockVaultViewModel(domain: domain, wrongBiometricalPassword: unlockError == .biometricalUnlockWrongPassword)
		if unlockError == .defaultLock, viewModel.canQuickUnlock {
			performQuickUnlock(viewModel: viewModel)
		} else {
			showManualLogin(for: domain, unlockError: unlockError)
		}
	}

	/**
	 Performs a quick unlock, i.e. biometric authentication gets triggered immediately.

	 If the biometric authentication has failed several times, the user is shown "Enter password" as a fallback option as of iOS 16.
	 In this case, the regular unlock screen will be shown.
	 */
	func performQuickUnlock(viewModel: UnlockVaultViewModel) {
		viewModel.biometricalUnlock().then { [weak self] in
			self?.done()
		}.catch { [weak self] error in
			if case LAError.userFallback = error {
				self?.showManualPasswordScreen(viewModel: viewModel)
			} else {
				self?.done()
			}
		}
	}

	func showManualLogin(for domain: NSFileProviderDomain, unlockError: UnlockError) {
		let vaultUID = domain.identifier.rawValue
		let vaultCache = VaultDBCache()
		let vaultAccount: VaultAccount
		let provider: CloudProvider
		do {
			vaultAccount = try VaultAccountDBManager.shared.getAccount(with: vaultUID)
			provider = try LocalizedCloudProviderDecorator(delegate: CloudProviderDBManager.shared.getProvider(with: vaultAccount.delegateAccountUID))
		} catch {
			handleError(error)
			return
		}
		vaultCache.refreshVaultCache(for: vaultAccount, with: provider).recover { error -> Void in
			switch error {
			case CloudProviderError.noInternetConnection, LocalizedCloudProviderError.itemNotFound:
				break
			default:
				throw error
			}
		}.then {
			let cachedVault = try vaultCache.getCachedVault(withVaultUID: vaultUID)
			if let vaultConfigToken = cachedVault.vaultConfigToken {
				let unverifiedVaultConfig = try UnverifiedVaultConfig(token: vaultConfigToken)
				switch VaultConfigHelper.getType(for: unverifiedVaultConfig) {
				case .hub:
					self.showHubLoginScreen(vaultConfig: unverifiedVaultConfig, domain: domain)
				case .masterkeyFile:
					let viewModel = UnlockVaultViewModel(domain: domain, wrongBiometricalPassword: unlockError == .biometricalUnlockWrongPassword)
					self.showManualPasswordScreen(viewModel: viewModel)
				case .unknown:
					fatalError("TODO: throw error")
				}
			} else {
				let viewModel = UnlockVaultViewModel(domain: domain, wrongBiometricalPassword: unlockError == .biometricalUnlockWrongPassword)
				self.showManualPasswordScreen(viewModel: viewModel)
			}
		}.catch {
			self.handleError($0)
		}
	}

	func showHubLoginScreen(vaultConfig: UnverifiedVaultConfig, domain: NSFileProviderDomain) {
		let child = HubXPCLoginCoordinator(navigationController: navigationController,
		                                   domain: domain,
		                                   vaultConfig: vaultConfig,
		                                   onUnlocked: { [weak self] in self?.done() },
		                                   onErrorAlertDismissed: { [weak self] in self?.done() })
		childCoordinators.append(child)
		child.start()
	}

	func showManualPasswordScreen(viewModel: UnlockVaultViewModel) {
		let unlockVaultVC = UnlockVaultViewController(viewModel: viewModel)
		unlockVaultVC.coordinator = self
		navigationController.pushViewController(unlockVaultVC, animated: false)
	}

	// MARK: - Internal

	private func addViewControllerAsChildToHost(_ viewController: UIViewController) {
		guard let hostViewController = hostViewController else {
			return
		}
		hostViewController.addChild(viewController)
		hostViewController.view.addSubview(viewController.view)
		viewController.didMove(toParent: hostViewController)
	}

	private func handleError(_ error: Error) {
		guard let hostViewController = hostViewController else {
			return
		}
		handleError(error, for: hostViewController)
	}
}
