//
//  VaultDetailUnlockCoordinator.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 04.08.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Promises
import UIKit

enum VaultDetailUnlockError: Error {
	case userCanceled
}

class VaultDetailUnlockCoordinator: NSObject, Coordinator, VaultPasswordVerifying, UIAdaptivePresentationControllerDelegate {
	var childCoordinators = [Coordinator]()
	weak var parentCoordinator: Coordinator?
	var navigationController: UINavigationController
	private let pendingAuthentication: Promise<Void>
	private let vault: VaultInfo
	private let biometryTypeName: String
	init(navigationController: UINavigationController, vault: VaultInfo, biometryTypeName: String, pendingAuthentication: Promise<Void>) {
		self.navigationController = navigationController
		self.vault = vault
		self.biometryTypeName = biometryTypeName
		self.pendingAuthentication = pendingAuthentication
		super.init()
		self.navigationController.presentationController?.delegate = self
	}

	func start() {
		let viewModel = VaultDetailUnlockVaultViewModel(vault: vault, biometryTypeName: biometryTypeName, passwordManager: VaultPasswordKeychainManager())
		let vaultDetailUnlockVaultVC = VaultDetailUnlockVaultViewController(viewModel: viewModel)
		vaultDetailUnlockVaultVC.coordinator = self
		navigationController.pushViewController(vaultDetailUnlockVaultVC, animated: false)
	}

	func verifiedVaultPassword() {
		pendingAuthentication.fulfill(())
		close()
	}

	private func close() {
		navigationController.dismiss(animated: true)
		parentCoordinator?.childDidFinish(self)
	}

	func cancel() {
		pendingAuthentication.reject(VaultDetailUnlockError.userCanceled)
		close()
	}

	// MARK: - UIAdaptivePresentationControllerDelegate

	func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
		// User has canceled the authentication by closing the modal via swipe
		pendingAuthentication.reject(VaultDetailUnlockError.userCanceled)
	}
}
