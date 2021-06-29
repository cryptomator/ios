//
//  FileProviderCoordinator.swift
//  FileProviderExtensionUI
//
//  Created by Philipp Schmid on 29.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

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
}
