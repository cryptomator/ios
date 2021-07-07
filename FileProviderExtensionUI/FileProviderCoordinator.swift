//
//  FileProviderCoordinator.swift
//  FileProviderExtensionUI
//
//  Created by Philipp Schmid on 29.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import FileProviderUI
import UIKit

class FileProviderCoordinator {
	let navigationController: UINavigationController
	let extensionContext: FPUIActionExtensionContext

	init(extensionContext: FPUIActionExtensionContext, navigationController: UINavigationController) {
		self.extensionContext = extensionContext
		self.navigationController = navigationController
	}

	func userCancelled() {
		extensionContext.cancelRequest(withError: NSError(domain: FPUIErrorDomain, code: Int(FPUIExtensionErrorCode.userCancelled.rawValue), userInfo: nil))
	}

	func startWith(error: Error) {
		let error = error as NSError
		let userInfo = error.userInfo
		guard let internalError = userInfo["internalError"] as? Error, let vaultName = userInfo["vaultName"] as? String, let pathRelativeToDocumentStorage = userInfo["pathRelativeToDocumentStorage"] as? String, let domainIdentifier = userInfo["domainIdentifier"] as? NSFileProviderDomainIdentifier else {
			showOnboarding()
			return
		}
		switch internalError {
		case let internalError as NSError where internalError == VaultManagerError.passwordNotInKeychain as NSError:
			let domain = NSFileProviderDomain(identifier: domainIdentifier, displayName: vaultName, pathRelativeToDocumentStorage: pathRelativeToDocumentStorage)
			showPasswordScreen(for: domain)
		default:
			print(internalError)
			showOnboarding()
		}
	}

	func handleError(_ error: Error, for viewController: UIViewController) {
		let alertController = UIAlertController(title: NSLocalizedString("common.alert.error.title", comment: ""), message: error.localizedDescription, preferredStyle: .alert)
		alertController.addAction(UIAlertAction(title: NSLocalizedString("common.button.ok", comment: ""), style: .default))
		viewController.present(alertController, animated: true)
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

	func showPasswordScreen(for domain: NSFileProviderDomain) {
		let viewModel = UnlockVaultViewModel(domain: domain)
		let unlockVaultVC = UnlockVaultViewController(viewModel: viewModel)
		unlockVaultVC.coordinator = self
		navigationController.pushViewController(unlockVaultVC, animated: false)
	}

	func unlocked() {
		extensionContext.completeRequest()
	}
}
