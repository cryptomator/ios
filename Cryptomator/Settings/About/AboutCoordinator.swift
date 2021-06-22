//
//  AboutCoordinator.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 14.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation
import UIKit

class AboutCoordinator: Coordinator {
	var childCoordinators = [Coordinator]()
	var navigationController: UINavigationController

	init(navigationController: UINavigationController) {
		self.navigationController = navigationController
	}

	func start() {
		let localWebViewController = LocalWebViewController(viewModel: AboutViewModel())
		localWebViewController.coordinator = self
		navigationController.pushViewController(localWebViewController, animated: true)
	}
}
