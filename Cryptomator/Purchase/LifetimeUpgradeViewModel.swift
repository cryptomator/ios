//
//  LifetimeUpgradeViewModel.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 09.03.26.
//  Copyright © 2026 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Foundation
import Promises

class LifetimeUpgradeViewModel: BaseIAPViewModel, ProductFetching {
	override var title: String? {
		return LocalizedString.getValue("purchase.product.lifetimeLicense")
	}

	override var infoText: NSAttributedString? {
		if CryptomatorUserDefaults.shared.hasRunningSubscription {
			return .textWithLeadingSystemImage("info.circle.fill",
			                                   text: LocalizedString.getValue("purchase.lifetime.hasSubscription.hint"),
			                                   font: .preferredFont(forTextStyle: .body),
			                                   color: .secondaryLabel)
		} else {
			return nil
		}
	}

	func fetchProducts() -> Promise<Void> {
		return fetchProducts(with: [.fullVersion])
	}

	override func fetchProductsSuccess() {
		addLifetimeLicenseItem()
	}
}
