//
//  Coordinator.swift
//  CryptomatorCommon
//
//  Created by Philipp Schmid on 04.01.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import UIKit

public protocol Coordinator: AnyObject {
	var childCoordinators: [Coordinator] { get set }
	var navigationController: UINavigationController { get set }

	func start()
}

public extension Coordinator {
	func handleError(_ error: Error, for viewController: UIViewController, onOKTapped: (() -> Void)? = nil) {
		DDLogError("Error: \(error)")
		let alertController = UIAlertController(title: LocalizedString.getValue("common.alert.error.title"), message: error.localizedDescription, preferredStyle: .alert)
		let okAction = UIAlertAction(title: LocalizedString.getValue("common.button.ok"), style: .default) { _ in
			onOKTapped?()
		}
		alertController.addAction(okAction)
		viewController.present(alertController, animated: true)
	}

	func childDidFinish(_ child: Coordinator?) {
		for (index, coordinator) in childCoordinators.enumerated() where coordinator === child {
			childCoordinators.remove(at: index)
			break
		}
	}
}
