//
//  SharePointCoordinator.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 04.03.25.
//  Copyright © 2025 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import UIKit

class SharePointCoordinator: SharePointURLSetting, Coordinator {
	var navigationController: UINavigationController
	var childCoordinators = [Coordinator]()
	weak var parentCoordinator: (Coordinator & FolderChooserStarting)?

	private let credentialID: String

	init(navigationController: UINavigationController, account: CloudProviderAccount) {
		self.navigationController = navigationController
		self.credentialID = account.accountUID // Here is an exception that `account.accountUID` actually contains the `credentialID`.
	}

	func start() {
		let viewModel = EnterSharePointURLViewModel()
		let enterURLVC = EnterSharePointURLViewController(viewModel: viewModel)
		enterURLVC.coordinator = self
		navigationController.pushViewController(enterURLVC, animated: true)
	}

	func setSharePointURL(_ url: URL) {
		let credential = MicrosoftGraphCredential(identifier: credentialID, type: .sharePoint)
		let discovery = MicrosoftGraphDiscovery(credential: credential)
		showDriveList(discovery: discovery, sharePointURL: url)
	}

	private func showDriveList(discovery: MicrosoftGraphDiscovery, sharePointURL: URL) {
		let viewModel = SharePointDriveListViewModel(discovery: discovery, sharePointURL: sharePointURL)
		let driveListVC = SharePointDriveListViewController(viewModel: viewModel)
		driveListVC.coordinator = self
		navigationController.pushViewController(driveListVC, animated: true)
	}

	func didSelectDrive(_ drive: MicrosoftGraphDrive) throws {
		let newAccountUID = UUID().uuidString
		let cloudProviderAccount = CloudProviderAccount(accountUID: newAccountUID, cloudProviderType: .microsoftGraph(type: .sharePoint))
		try CloudProviderAccountDBManager.shared.saveNewAccount(cloudProviderAccount) // Make sure to save this first, because Microsoft Graph account has a reference to the Cloud Provider account.
		let microsoftGraphAccount = MicrosoftGraphAccount(accountUID: newAccountUID, credentialID: credentialID, type: .sharePoint)
		try MicrosoftGraphAccountDBManager.shared.saveNewAccount(microsoftGraphAccount)
		let provider = try CloudProviderDBManager.shared.getProvider(with: newAccountUID)
		parentCoordinator?.startFolderChooser(with: provider, account: cloudProviderAccount)
	}
}
