//
//  PoppingCloseCoordinator.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 30.11.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import UIKit

protocol PoppingCloseCoordinator: Coordinator {
	var oldTopViewController: UIViewController? { get }
}

extension PoppingCloseCoordinator {
	func close() {
		popToOldTopViewController()
	}

	func popToOldTopViewController() {
		guard let oldTopViewController = oldTopViewController else {
			return
		}
		navigationController.popToViewController(oldTopViewController, animated: true)
	}
}
