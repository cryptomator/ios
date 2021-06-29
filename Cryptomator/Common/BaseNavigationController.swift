//
//  BaseNavigationController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 29.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import UIKit

class BaseNavigationController: UINavigationController {
	override func viewDidLoad() {
		super.viewDidLoad()
		navigationBar.tintColor = .white
		navigationBar.barTintColor = UIColor(named: "primary")
		navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
	}
}
