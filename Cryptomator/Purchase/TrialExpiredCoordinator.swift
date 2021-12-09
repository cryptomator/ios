//
//  TrialExpiredCoordinator.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 03.12.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation
class TrialExpiredCoordinator: PurchaseCoordinator {
	override func start() {
		let purchaseViewController = PurchaseViewController(viewModel: PurchaseViewModel())
		purchaseViewController.coordinator = self
		navigationController.pushViewController(purchaseViewController, animated: false)
	}
}
