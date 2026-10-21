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
import UIKit

class SharePointAuthenticationCoordinator: Coordinator, SharePointAuthenticating {
	let pendingAuthentication = OneShotSignal<SharePointCredential>()
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

	func setSiteURL(_ siteURL: URL, from viewController: UIViewController) {
		Task {
			do {
				let credential = try await MicrosoftGraphAuthenticator.authenticate(from: viewController, for: .sharePoint)
				showDriveList(credential: credential, siteURL: siteURL)
			} catch CocoaError.userCancelled {
				return
			} catch {
				handleError(error, for: navigationController)
			}
		}
	}

	private func showDriveList(credential: MicrosoftGraphCredential, siteURL: URL) {
		let viewModel = SharePointDriveListViewModel(credential: credential, siteURL: siteURL)
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
