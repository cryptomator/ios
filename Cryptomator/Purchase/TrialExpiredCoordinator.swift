//
//  TrialExpiredCoordinator.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 03.12.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import UIKit

class TrialExpiredCoordinator: PurchaseCoordinator {
	override func start() {
		let purchaseViewController = PurchaseViewController(viewModel: TrialExpiredPurchaseViewModel())
		purchaseViewController.coordinator = self
		purchaseViewController.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonTapped))
		navigationController.pushViewController(purchaseViewController, animated: false)
	}
}

private class TrialExpiredPurchaseViewModel: PurchaseViewModel {
	override var infoText: NSAttributedString? {
		.textWithLeadingSystemImage("info.circle.fill",
		                            text: LocalizedString.getValue("purchase.expiredTrial"),
		                            font: .preferredFont(forTextStyle: .body),
		                            color: .secondaryLabel)
	}
}
