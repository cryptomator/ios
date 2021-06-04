//
//  SettingsCoordinator.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 04.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Foundation
import UIKit

class SettingsCoordinator: Coordinator {
	var childCoordinators = [Coordinator]()
	var navigationController: UINavigationController
	weak var parentCoordinator: MainCoordinator?

	init(navigationController: UINavigationController) {
		self.navigationController = navigationController
	}

	func start() {
		let settingsViewController = SettingsViewController(viewModel: SettingsViewModel())
		settingsViewController.coordinator = self
		navigationController.pushViewController(settingsViewController, animated: false)
	}

	func exportLogs() {
		guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: CryptomatorConstants.appGroupName) else {
			print("containerURL is nil")
			return
		}
		let logDirectory = containerURL.appendingPathComponent("Logs")
		let activityController = UIActivityViewController(activityItems: [logDirectory], applicationActivities: nil)
		navigationController.present(activityController, animated: true)
	}

	func close() {
		navigationController.dismiss(animated: true)
		parentCoordinator?.childDidFinish(self)
	}
}
