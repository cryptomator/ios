//
//  WebDAVAuthenticator+VC.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 08.04.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Promises
import UIKit

extension WebDAVAuthenticator {
	private static var coordinator: WebDAVAuthenticationCoordinator?

	static func authenticate(from viewController: UIViewController) -> Promise<WebDAVCredential> {
		let navigationController = BaseNavigationController()
		let webDAVCoordinator = WebDAVAuthenticationCoordinator(navigationController: navigationController)
		coordinator = webDAVCoordinator
		viewController.present(navigationController, animated: true)
		webDAVCoordinator.start()
		return webDAVCoordinator.pendingAuthentication.always {
			self.coordinator = nil
		}
	}
}
