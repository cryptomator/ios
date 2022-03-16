//
//  UpgradeViewModel.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 08.09.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Foundation
import Promises

class UpgradeViewModel: BaseIAPViewModel, ProductFetching {
	override var title: String? {
		return LocalizedString.getValue("upgrade.title")
	}

	override var infoText: NSAttributedString? {
		return .textWithLeadingSystemImage("heart.fill",
		                                   text: LocalizedString.getValue("upgrade.info"),
		                                   font: .preferredFont(forTextStyle: .body),
		                                   color: .secondaryLabel)
	}

	func fetchProducts() -> Promise<Void> {
		return fetchProducts(with: [.paidUpgrade, .freeUpgrade])
	}

	override func fetchProductsSuccess() {
		addPaidUpgradeItem()
		addFreeUpgradeItem()
	}

	func addFreeUpgradeItem() {
		guard products[.freeUpgrade] != nil else { return }
		let viewModel = PurchaseCellViewModel(productName: LocalizedString.getValue("purchase.product.freeUpgrade"),
		                                      price: LocalizedString.getValue("purchase.product.pricing.free"),
		                                      purchaseDetail: nil,
		                                      productIdentifier: .freeUpgrade)
		cells.append(.purchaseCell(viewModel))
	}

	func addPaidUpgradeItem() {
		if let product = products[.paidUpgrade], let localizedPrice = product.localizedPrice {
			let viewModel = PurchaseCellViewModel(productName: LocalizedString.getValue("purchase.product.donateAndUpgrade"),
			                                      price: localizedPrice,
			                                      purchaseDetail: LocalizedString.getValue("purchase.product.lifetimeLicense.duration"),
			                                      productIdentifier: .paidUpgrade)
			cells.append(.purchaseCell(viewModel))
		}
	}
}
