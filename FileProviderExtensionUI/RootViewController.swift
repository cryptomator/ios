//
//  RootViewController.swift
//  FileProviderExtensionUI
//
//  Created by Philipp Schmid on 29.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import FileProviderUI
import UIKit

class RootViewController: FPUIActionExtensionViewController {
	private var coordinator: FileProviderCoordinator?
	override func viewDidLoad() {
		super.viewDidLoad()
		let navigationController = UINavigationController()
		navigationController.navigationBar.barTintColor = UIColor(named: "primary")
		navigationController.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
		navigationController.navigationBar.tintColor = .white
		addChild(navigationController)
		view.addSubview(navigationController.view)
		navigationController.didMove(toParent: self)

		coordinator = FileProviderCoordinator(extensionContext: extensionContext, navigationController: navigationController)
	}

	override func prepare(forError error: Error) {
		coordinator?.startWith(error: error)
	}

	@objc func cancel() {
		extensionContext.cancelRequest(withError: NSError(domain: FPUIErrorDomain, code: Int(FPUIExtensionErrorCode.userCancelled.rawValue), userInfo: nil))
	}
}
