//
//  LocalFileSystemAuthenticator.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 23.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Promises
import UIKit
class LocalFileSystemAuthenticator {
	private static var coordinator: LocalFileSystemCoordinator?

	static func authenticateForOpenExistingVault(from navigationController: UINavigationController, onCompletion: @escaping (LocalFileSystemCredential) -> Void) {
		let documentPickerButtonText = NSLocalizedString("localFileSystemAuthentication.openExistingVault.button", comment: "")
		let headerText = NSLocalizedString("localFileSystemAuthentication.openExistingVault.header", comment: "")
		let viewModel = LocalFileSystemAuthenticationViewModel(documentPickerButtonText: documentPickerButtonText, headerText: headerText)
		authenticate(from: navigationController, viewModel: viewModel, onCompletion: onCompletion)
	}

	static func authenticateForCreateNewVault(from navigationController: UINavigationController, onCompletion: @escaping (LocalFileSystemCredential) -> Void) {
		let documentPickerButtonText = NSLocalizedString("localFileSystemAuthentication.createNewVault.button", comment: "")
		let headerText = NSLocalizedString("localFileSystemAuthentication.createNewVault.header", comment: "")
		let viewModel = LocalFileSystemAuthenticationViewModel(documentPickerButtonText: documentPickerButtonText, headerText: headerText)
		authenticate(from: navigationController, viewModel: viewModel, onCompletion: onCompletion)
	}

	static func authenticate(from navigationController: UINavigationController, viewModel: LocalFileSystemAuthenticationViewModelProtocol, onCompletion: @escaping (LocalFileSystemCredential) -> Void) {
		let coordinator = LocalFileSystemCoordinator(navigationController: navigationController, viewModel: viewModel, onAuthenticated: onCompletion)
		self.coordinator = coordinator
		coordinator.start()
	}
}

private class LocalFileSystemCoordinator: Coordinator, LocalFileSystemAuthenticating {
	var childCoordinators = [Coordinator]()

	var navigationController: UINavigationController

	private let viewModel: LocalFileSystemAuthenticationViewModelProtocol
	let onAuthenticated: (LocalFileSystemCredential) -> Void

	init(navigationController: UINavigationController, viewModel: LocalFileSystemAuthenticationViewModelProtocol, onAuthenticated: @escaping (LocalFileSystemCredential) -> Void) {
		self.navigationController = navigationController
		self.viewModel = viewModel
		self.onAuthenticated = onAuthenticated
	}

	func start() {
		let localFSAuthVC = LocalFileSystemAuthenticationViewController(viewModel: viewModel)
		localFSAuthVC.coordinator = self
		navigationController.pushViewController(localFSAuthVC, animated: true)
	}

	func authenticated(credential: LocalFileSystemCredential) {
		onAuthenticated(credential)
	}
}
