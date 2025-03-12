//
//  SharePointAuthenticationCoordinator.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 04.03.25.
//  Copyright © 2025 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import GRDB
import Promises
import UIKit

class SharePointAuthenticationCoordinator: Coordinator, SharePointAuthenticating {
	let pendingAuthentication = Promise<SharePointCredential>.pending()
	var navigationController: UINavigationController
	var childCoordinators = [Coordinator]()
	weak var parentCoordinator: Coordinator?

	init(navigationController: UINavigationController) {
		self.navigationController = navigationController
	}

	func start() {
		let viewModel = EnterSharePointURLViewModel()
		let enterURLVC = EnterSharePointURLViewController(viewModel: viewModel)
		enterURLVC.coordinator = self
		navigationController.pushViewController(enterURLVC, animated: true)
	}

	func setURL(_ url: URL, from viewController: UIViewController) {
		MicrosoftGraphAuthenticator.authenticate(from: viewController, for: .sharePoint).then { credential in
			self.showDriveList(credential: credential, url: url)
		}.catch { error in
			guard case CocoaError.userCancelled = error else {
				self.handleError(error, for: self.navigationController)
				return
			}
		}
	}

	private func showDriveList(credential: MicrosoftGraphCredential, url: URL) {
		let viewModel = SharePointDriveListViewModel(credential: credential, url: url)
		let driveListVC = SharePointDriveListViewController(viewModel: viewModel)
		driveListVC.coordinator = self
		navigationController.pushViewController(driveListVC, animated: true)
	}

	func authenticated(_ credential: SharePointCredential) throws {
		pendingAuthentication.fulfill(credential)
		close()
	}

	func cancel() {
		pendingAuthentication.reject(CocoaError(.userCancelled))
		close()
	}

	private func close() {
		navigationController.dismiss(animated: true)
		parentCoordinator?.childDidFinish(self)
	}
}
