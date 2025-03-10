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

	private let account: AccountInfo

	init(navigationController: UINavigationController, account: AccountInfo) {
		self.navigationController = navigationController
		self.account = account
	}

	func start() {
		do {
			_ = try CloudProviderAccountDBManager.shared.getAccount(for: account.accountUID)
			let provider = try CloudProviderDBManager.shared.getProvider(with: account.accountUID)
			parentCoordinator?.startFolderChooser(with: provider, account: account.cloudProviderAccount)
		} catch {
			let viewModel = EnterSharePointURLViewModel()
			let enterURLVC = EnterSharePointURLViewController(viewModel: viewModel)
			enterURLVC.coordinator = self
			navigationController.pushViewController(enterURLVC, animated: true)
		}
	}

	func setSharePointURL(_ url: URL) {
		let credential = MicrosoftGraphCredential(identifier: account.accountUID, type: .sharePoint)
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
		try MicrosoftGraphAccountDBManager.shared.updateDriveID(for: account.accountUID, driveID: drive.identifier)
		try CloudProviderAccountDBManager.shared.saveNewAccount(account.cloudProviderAccount)
		let provider = try CloudProviderDBManager.shared.getProvider(with: account.accountUID)
		parentCoordinator?.startFolderChooser(with: provider, account: account.cloudProviderAccount)
	}
}
