//
//  WebDAVAuthenticationCoordinator.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 07.04.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Promises
import UIKit
class WebDAVAuthenticationCoordinator: NSObject, Coordinator, WebDAVAuthenticating, UIAdaptivePresentationControllerDelegate {
	weak var parentCoordinator: Coordinator?
	var childCoordinators = [Coordinator]()

	var navigationController: UINavigationController
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

	func authenticated(with credential: WebDAVCredential) {
		pendingAuthentication.fulfill(credential)
		close()
	}

	func handleUntrustedCertificate(_ certificate: TLSCertificate, url: URL, for viewController: WebDAVAuthenticationViewController, viewModel: WebDAVAuthenticationViewModelProtocol) {
		let alertController = UIAlertController(title: NSLocalizedString("untrustedTLSCertificate.title", comment: ""),
		                                        message: String(format: NSLocalizedString("untrustedTLSCertificate.message", comment: ""), url.absoluteString, certificate.fingerprint),
		                                        preferredStyle: .alert)
		alertController.addAction(UIAlertAction(title: NSLocalizedString("untrustedTLSCertificate.add", comment: ""), style: .default, handler: { _ in
			viewController.addAccount(allowedCertificate: certificate.data)
		}))
		alertController.addAction(UIAlertAction(title: NSLocalizedString("untrustedTLSCertificate.dismiss", comment: ""), style: .cancel))
		viewController.present(alertController, animated: true)
	}

	func cancel() {
		pendingAuthentication.reject(WebDAVAuthenticationError.userCanceled)
		close()
	}

	private func close() {
		navigationController.dismiss(animated: true)
		parentCoordinator?.childDidFinish(self)
	}

	func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
		// User has canceled the authentication by closing the modal via swipe
		pendingAuthentication.reject(WebDAVAuthenticationError.userCanceled)
	}
}
