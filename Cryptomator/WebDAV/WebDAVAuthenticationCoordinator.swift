//
//  WebDAVAuthenticationCoordinator.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 07.04.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Promises
import UIKit

class WebDAVAuthenticationCoordinator: NSObject, Coordinator, WebDAVAuthenticating, UIAdaptivePresentationControllerDelegate {
	var navigationController: UINavigationController
	var childCoordinators = [Coordinator]()
	weak var parentCoordinator: Coordinator?

	private(set) var pendingAuthentication: Promise<WebDAVCredential>

	init(navigationController: UINavigationController) {
		self.navigationController = navigationController
		self.pendingAuthentication = Promise<WebDAVCredential>.pending()
		super.init()
		navigationController.presentationController?.delegate = self
	}

	func start() {
		let viewModel = WebDAVAuthenticationViewModel()
		let webDAVAuthenticationVC = WebDAVAuthenticationViewController(viewModel: viewModel)
		webDAVAuthenticationVC.coordinator = self
		navigationController.pushViewController(webDAVAuthenticationVC, animated: false)
	}

	private func close() {
		navigationController.dismiss(animated: true)
		parentCoordinator?.childDidFinish(self)
	}

	// MARK: - WebDAVAuthenticating

	func authenticated(with credential: WebDAVCredential) {
		pendingAuthentication.fulfill(credential)
		close()
	}

	func cancel() {
		pendingAuthentication.reject(WebDAVAuthenticationError.userCanceled)
		close()
	}

	// MARK: - UIAdaptivePresentationControllerDelegate

	func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
		// User has canceled the authentication by closing the modal via swipe
		pendingAuthentication.reject(WebDAVAuthenticationError.userCanceled)
	}
}
