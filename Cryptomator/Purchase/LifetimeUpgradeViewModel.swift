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

	func fetchProducts() -> Promise<Void> {
		return fetchProducts(with: [.fullVersion])
	}

	override func fetchProductsSuccess() {
		if let product = products[.fullVersion], let localizedPrice = product.localizedPrice {
			// Temporarily added for 10th Anniversary Sale
			let productDetail = SalePromo.isTenthAnniversaryActive() ? "\(SalePromo.tenthAnniversaryEmoji) \(SalePromo.tenthAnniversaryDiscount)" : nil
			let viewModel = PurchaseCellViewModel(productName: LocalizedString.getValue("purchase.product.lifetimeLicense"),
			                                      productDetail: productDetail,
			                                      price: localizedPrice,
			                                      purchaseDetail: LocalizedString.getValue("purchase.product.lifetimeLicense.duration"),
			                                      productIdentifier: .fullVersion)
			cells.append(.purchaseCell(viewModel))
		}
	}
}
