//
//  Coordinator.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 04.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import UIKit

protocol Coordinator: AnyObject {
	var childCoordinators: [Coordinator] { get set }
	var navigationController: UINavigationController { get set }

	func start()
}

extension Coordinator {
	func handleError(_ error: Error, for viewController: UIViewController) {
		let alertController = UIAlertController(title: NSLocalizedString("common.error.alert.title", comment: ""), message: error.localizedDescription, preferredStyle: .alert)
		alertController.addAction(UIAlertAction(title: NSLocalizedString("common.button.ok", comment: ""), style: .default))
		viewController.present(alertController, animated: true)
	}

	func childDidFinish(_ child: Coordinator?) {
		for (index, coordinator) in childCoordinators.enumerated() where coordinator === child {
			childCoordinators.remove(at: index)
			break
		}
	}
}
