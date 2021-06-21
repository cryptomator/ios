//
//  AddVaultSuccessCoordinator.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 18.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjack
import CocoaLumberjackSwift
import CryptomatorCommonCore
import UIKit

class AddVaultSuccessCoordinator: AddVaultSuccesing, Coordinator {
	var childCoordinators = [Coordinator]()
	var navigationController: UINavigationController
	var parentCoordinator: Coordinator?

	private let vaultName: String
	private let vaultUID: String

	init(vaultName: String, vaultUID: String, navigationController: UINavigationController) {
		self.vaultName = vaultName
		self.vaultUID = vaultUID
		self.navigationController = navigationController
	}

	func start() {
		let viewModel = AddVaultSuccessViewModel(vaultName: vaultName, vaultUID: vaultUID)
		let successVC = AddVaultSuccessViewController(viewModel: viewModel)
		successVC.title = NSLocalizedString("addVault.openExistingVault.title", comment: "")
		successVC.coordinator = self
		navigationController.pushViewController(successVC, animated: true)
		// Remove the previous ViewControllers so that the user cannot navigate to the previous screens.
		navigationController.viewControllers = [successVC]
	}

	// MARK: - AddVaultSuccesing

	func done() {
		parentCoordinator?.childDidFinish(self)
		navigationController.dismiss(animated: true)
	}

	func showFilesApp(forVaultUID vaultUID: String) {
		guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: CryptomatorConstants.appGroupName) else {
			DDLogDebug("containerURL is nil")
			return
		}
		let url = containerURL.appendingPathComponent("File Provider Storage").appendingPathComponent(vaultUID)
		guard let sharedDocumentsURL = changeSchemeToSharedDocuments(for: url) else {
			DDLogDebug("Conversion to shared documents url failed")
			return
		}
		UIApplication.shared.open(sharedDocumentsURL)
		done()
	}

	private func changeSchemeToSharedDocuments(for url: URL) -> URL? {
		var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
		comps?.scheme = "shareddocuments"
		return comps?.url
	}
}
