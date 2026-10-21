//
//  WebDAVAuthenticator+VC.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 08.04.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import UIKit

extension WebDAVAuthenticator {
	@MainActor private static var coordinator: WebDAVAuthenticationCoordinator?

	static func authenticate(from viewController: UIViewController) async throws -> WebDAVCredential {
		let navigationController = BaseNavigationController()
		let webDAVCoordinator = WebDAVAuthenticationCoordinator(navigationController: navigationController)
		coordinator = webDAVCoordinator
		defer {
			coordinator = nil
		}
		viewController.present(navigationController, animated: true)
		webDAVCoordinator.start()
		return try await webDAVCoordinator.pendingAuthentication.value
	}
}
