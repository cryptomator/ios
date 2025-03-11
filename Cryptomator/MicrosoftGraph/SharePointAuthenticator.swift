//
//  SharePointAuthenticator.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 11.03.25.
//  Copyright © 2025 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Promises
import UIKit

public class SharePointAuthenticator {
	private static var coordinator: SharePointAuthenticationCoordinator?

	public static func authenticate(from viewController: UIViewController) -> Promise<CloudProviderAccount> {
		let navigationController = BaseNavigationController()
		let sharePointCoordinator = SharePointAuthenticationCoordinator(navigationController: navigationController)
		coordinator = sharePointCoordinator
		viewController.present(navigationController, animated: true)
		sharePointCoordinator.start()
		return sharePointCoordinator.pendingAuthentication.always {
			self.coordinator = nil
		}
	}
}
