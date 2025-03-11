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
import Promises
import UIKit

class SharePointAuthenticationCoordinator: Coordinator, SharePointAuthenticating {
	let pendingAuthentication = Promise<CloudProviderAccount>.pending()
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

	func sharePointURLSet(_ sharePointURL: URL, from viewController: UIViewController) {
		MicrosoftGraphAuthenticator.authenticate(from: viewController, for: .sharePoint).then { credential in
			self.showDriveList(credential: credential, sharePointURL: sharePointURL)
		}.catch { error in
			guard case CloudAuthenticatorError.userCanceled = error else {
				self.handleError(error, for: self.navigationController)
				return
			}
		}
	}

	private func showDriveList(credential: MicrosoftGraphCredential, sharePointURL: URL) {
		let viewModel = SharePointDriveListViewModel(credential: credential, sharePointURL: sharePointURL)
		let driveListVC = SharePointDriveListViewController(viewModel: viewModel)
		driveListVC.coordinator = self
		navigationController.pushViewController(driveListVC, animated: true)
	}

	func driveSelected(_ drive: MicrosoftGraphDrive, with credential: MicrosoftGraphCredential) throws {
		let newAccountUID = UUID().uuidString
		let cloudProviderAccount = CloudProviderAccount(accountUID: newAccountUID, cloudProviderType: .microsoftGraph(type: .sharePoint))
		try CloudProviderAccountDBManager.shared.saveNewAccount(cloudProviderAccount) // Make sure to save this first, because Microsoft Graph account has a reference to the Cloud Provider account.
		let microsoftGraphAccount = MicrosoftGraphAccount(accountUID: newAccountUID, credentialID: credential.identifier, driveID: drive.identifier, type: .sharePoint)
		try MicrosoftGraphAccountDBManager.shared.saveNewAccount(microsoftGraphAccount)
		pendingAuthentication.fulfill(cloudProviderAccount)
		close()
	}

	func cancel() {
		pendingAuthentication.reject(MicrosoftGraphAuthenticatorError.userCanceled)
		close()
	}

	private func close() {
		navigationController.dismiss(animated: true)
		parentCoordinator?.childDidFinish(self)
	}
}
