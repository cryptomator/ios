//
//  SettingsCoordinator.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 04.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjack
import CocoaLumberjackSwift
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

	func showAbout() {
		let child = AboutCoordinator(navigationController: navigationController)
		childCoordinators.append(child) // TODO: remove missing?
		child.start()
	}

	func sendLogFile(sourceView: UIView) throws {
		let logsDirectoryURL = URL(fileURLWithPath: DDFileLogger.sharedInstance.logFileManager.logsDirectory)
		let tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: tmpDirURL, withIntermediateDirectories: true)
		let zippedLogsURL = tmpDirURL.appendingPathComponent("Logs.zip", isDirectory: false)
		try logsDirectoryURL.zipFolder(toFileAt: zippedLogsURL)
		let activityController = UIActivityViewController(activityItems: [zippedLogsURL], applicationActivities: nil)
		activityController.completionWithItemsHandler = { _, _, _, _ -> Void in
			try? FileManager.default.removeItem(at: tmpDirURL)
		}
		activityController.popoverPresentationController?.sourceView = sourceView
		activityController.popoverPresentationController?.sourceRect = sourceView.bounds
		navigationController.present(activityController, animated: true)
	}

	func close() {
		navigationController.dismiss(animated: true)
		parentCoordinator?.childDidFinish(self)
	}
}
