//
//  BaseNavigationController.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 29.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import UIKit

class BaseNavigationController: UINavigationController {
	override var preferredStatusBarStyle: UIStatusBarStyle {
		return .lightContent
	}

	override var modalPresentationStyle: UIModalPresentationStyle {
		get {
			if useDefaultModalPresentationStyle {
				return .formSheet
			}
			return super.modalPresentationStyle
		}
		set {
			useDefaultModalPresentationStyle = false
			super.modalPresentationStyle = newValue
		}
	}

	private var useDefaultModalPresentationStyle = true

	override func viewDidLoad() {
		super.viewDidLoad()
		let appearance = UINavigationBarAppearance()
		appearance.configureWithOpaqueBackground()
		appearance.backgroundColor = .cryptomatorPrimary
		appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
		navigationBar.standardAppearance = appearance
		navigationBar.scrollEdgeAppearance = appearance
		navigationBar.tintColor = .white
	}
}
