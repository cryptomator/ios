//
//  Coordinator.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 04.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import UIKit

protocol Coordinator: AnyObject {
	var childCoordinators: [Coordinator] { get set }
	var navigationController: UINavigationController { get set }

	func start()
}

extension Coordinator {
	func handleError(_ error: Error, for viewController: UIViewController) {
		let alertController = UIAlertController(title: LocalizedString.getValue("common.alert.error.title"), message: error.localizedDescription, preferredStyle: .alert)
		alertController.addAction(UIAlertAction(title: LocalizedString.getValue("common.button.ok"), style: .default))
		viewController.present(alertController, animated: true)
	}

	func childDidFinish(_ child: Coordinator?) {
		for (index, coordinator) in childCoordinators.enumerated() where coordinator === child {
			childCoordinators.remove(at: index)
			break
		}
	}
}
