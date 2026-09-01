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
	/// Set when an unlock starts and never cleared, thus it is nil only for an error that precedes any unlock.
	private var authenticatingDomain: NSFileProviderDomain?

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
		showError(error, for: viewController, onOKTapped: nil)
	}

	func done() {
		extensionContext.completeRequest()
	}

	func completeUnlock() {
		#if !ALWAYS_PREMIUM
		guard SalePromo.shared.shouldShowSummer2026UnlockPromo() else {
			done()
			return
		}
		CryptomatorUserDefaults.shared.summer2026UnlockPromoShown = true
		showSalePromoAlert()
		#else
		done()
		#endif
	}

	// MARK: - Onboarding

	func showOnboarding() {
		let onboardingVC = OnboardingViewController()
		onboardingVC.coordinator = self
		navigationController.pushViewController(onboardingVC, animated: false)
	}

	func showUnauthorizedError(vaultName: String) {
		let unauthorizedErrorVC = UnauthorizedErrorViewController(vaultName: vaultName)
		unauthorizedErrorVC.coordinator = self
		navigationController.pushViewController(unauthorizedErrorVC, animated: true)
	}

	func openCryptomatorApp() {
		open(URL(string: "cryptomator:")!, onFailure: { [weak self] in
			self?.userCancelled()
		})
	}

	func showSalePromoAlert() {
		guard let hostViewController = hostViewController else {
			done()
			return
		}
		let title = "\(SalePromo.summer2026Emoji) Summer Sale!"
		let message = "For a limited time, Lifetime License is \(SalePromo.summer2026Discount)!"
		let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
		alertController.addAction(UIAlertAction(title: "Learn More", style: .default) { [weak self] _ in
			guard let self = self else { return }
			self.open(URL(string: "cryptomator://purchase")!, onFailure: { [weak self] in
				self?.done()
			})
		})
		alertController.addAction(UIAlertAction(title: "Not Now", style: .cancel) { [weak self] _ in
			self?.done()
		})
		hostViewController.present(alertController, animated: true)
	}

	// MARK: - Vault Unlock

	func startAuthentication(for domain: NSFileProviderDomain, unlockError: UnlockError) {
		authenticatingDomain = domain
		let viewModel = UnlockVaultViewModel(domain: domain, wrongBiometricalPassword: unlockError == .biometricalUnlockWrongPassword)
		if unlockError == .defaultLock, viewModel.canQuickUnlock {
			performQuickUnlock(viewModel: viewModel)
		} else {
			showManualLogin(for: domain, unlockError: unlockError)
		}
	}

	/**
	 Performs a quick unlock, i.e. biometric authentication gets triggered immediately.

	 The manual unlock screen is shown when the user picks "Enter password" after repeated biometric failures. It is also shown when biometric authentication is unavailable on the device.

	 A canceled or failed biometric authentication ends the request without a message. Every other error, e.g. an expired cloud session, is shown first, because the quick unlock leaves the user with nothing else on screen.
	 */
	func performQuickUnlock(viewModel: UnlockVaultViewModel) {
		viewModel.biometricalUnlock().then { [weak self] in
			self?.completeUnlock()
		}.catch { [weak self] error in
			switch QuickUnlockFailure(error: error) {
			case .fallBackToPassword:
				self?.showManualPasswordScreen(viewModel: viewModel)
			case .dismiss:
				self?.done()
			case .report:
				self?.reportQuickUnlockFailure(error)
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
			case CloudProviderError.itemNotFound, LocalizedCloudProviderError.itemNotFound:
				break
			default:
				guard error.isTransientConnectivityError else {
					throw error
				}
				DDLogInfo("FileProviderCoordinator: refreshVaultCache unreachable, using cached masterkey (\(error))")
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

	/**
	 Opens a URL, which sends the user out of the extension.

	 The user leaves the extension, thus a successful open cancels the request. A failed open keeps the user here, thus the caller decides how the request ends.
	 */
	private func open(_ url: URL, onFailure: @escaping () -> Void) {
		extensionContext.open(url) { [weak self] success in
			if success {
				self?.userCancelled()
			} else {
				DDLogError("Opening \(url) failed")
				onFailure()
			}
		}
	}

	private func handleError(_ error: Error) {
		guard let hostViewController = hostViewController else {
			return
		}
		handleError(error, for: hostViewController)
	}

	/**
	 The quick unlock has nothing on screen, so the alert has to end the request. Otherwise the extension keeps the request open and the user cannot leave the empty screen.
	 */
	private func reportQuickUnlockFailure(_ error: Error) {
		guard let hostViewController = hostViewController else {
			return
		}
		showError(error, for: hostViewController, onOKTapped: { [weak self] in
			self?.done()
		})
	}

	/**
	 Routes an unauthorized error to the dedicated screen and every other error to an alert.

	 The vault name comes from the domain that is currently being unlocked, thus an unauthorized error before an unlock falls back to the alert.

	 `onOKTapped` applies to the alert only. The unauthorized screen ends the request through its own actions, thus it ignores the callback.
	 */
	private func showError(_ error: Error, for viewController: UIViewController, onOKTapped: (() -> Void)?) {
		if error.isUnauthorizedError, let vaultName = authenticatingDomain?.displayName {
			DDLogError("Error: \(error)")
			showUnauthorizedError(vaultName: vaultName)
		} else {
			handleError(error, for: viewController, onOKTapped: onOKTapped)
		}
	}
}
