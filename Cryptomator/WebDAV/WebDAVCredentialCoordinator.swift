//
//  WebDAVCredentialCoordinator.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 23.08.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Foundation
import UIKit

class WebDAVCredentialCoordinator: Coordinator, WebDAVAuthenticating {
	var navigationController: UINavigationController
	lazy var childCoordinators = [Coordinator]()
	weak var parentCoordinator: Coordinator?
	private let credential: WebDAVCredential

	init(credential: WebDAVCredential, navigationController: UINavigationController) {
		self.credential = credential
		self.navigationController = navigationController
	}

	func start() {
		let viewModel = WebDAVAuthenticationViewModel(credential: credential)
		let viewController = WebDAVAuthenticationViewController(viewModel: viewModel)
		viewController.coordinator = self
		navigationController.pushViewController(viewController, animated: false)
	}

	func authenticated(with credential: WebDAVCredential) {
		close()
	}

	func cancel() {
		close()
	}

	private func close() {
		navigationController.dismiss(animated: true)
		parentCoordinator?.childDidFinish(self)
	}
}
