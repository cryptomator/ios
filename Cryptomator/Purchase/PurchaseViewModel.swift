//
//  PurchaseViewModel.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 08.09.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Foundation
import Promises
import StoreKit

enum PurchaseError: LocalizedError {
	case unavailableProduct
	case paymentCancelled
	case unknown

	public var errorDescription: String? {
		switch self {
		case .unavailableProduct:
			return nil // should never happen
		case .paymentCancelled:
			return nil // not needed since nothing should be shown
		case .unknown:
			return LocalizedString.getValue("purchase.error.unknown")
		}
	}
}

class PurchaseViewModel: BaseIAPViewModel, ProductFetching {
	override var title: String? {
		return LocalizedString.getValue("purchase.title")
	}

	private let cryptomatorSettings: CryptomatorSettings

	init(storeManager: IAPStore = StoreManager.shared, iapManager: IAPManager = StoreObserver.shared, cryptomatorSettings: CryptomatorSettings = CryptomatorUserDefaults.shared, minimumDisplayTime: TimeInterval = 1.0) {
		self.cryptomatorSettings = cryptomatorSettings
		super.init(storeManager: storeManager, iapManager: iapManager, minimumDisplayTime: minimumDisplayTime)
	}

	func fetchProducts() -> Promise<Void> {
		return fetchProducts(with: [.thirtyDayTrial, .fullVersion, .yearlySubscription])
	}

	override func fetchProductsSuccess() {
		addTrialItem()
		addSubscriptionItem()
		addLifetimeLicenseItem()
		addUpgradeOfferItem()
	}

	private func addTrialItem() {
		if let trialExpirationDate = cryptomatorSettings.trialExpirationDate {
			cells.append(.trialCell(TrialCellViewModel(expirationDate: trialExpirationDate)))
		} else {
			cells.append(.purchaseCell(PurchaseCellViewModel(productName: LocalizedString.getValue("purchase.product.trial"),
			                                                 price: LocalizedString.getValue("purchase.product.pricing.free"),
			                                                 purchaseDetail: LocalizedString.getValue("purchase.product.trial.duration"),
			                                                 productIdentifier: .thirtyDayTrial)))
		}
	}

	private func addSubscriptionItem() {
		if let product = products[.yearlySubscription], let localizedPrice = product.localizedPrice {
			let viewModel = PurchaseCellViewModel(productName: LocalizedString.getValue("purchase.product.yearlySubscription"),
			                                      price: localizedPrice,
			                                      purchaseDetail: LocalizedString.getValue("purchase.product.yearlySubscription.duration"),
			                                      productIdentifier: .yearlySubscription)
			cells.append(.purchaseCell(viewModel))
		}
	}

	private func addLifetimeLicenseItem() {
		if let product = products[.fullVersion], let localizedPrice = product.localizedPrice {
			let viewModel = PurchaseCellViewModel(productName: LocalizedString.getValue("purchase.product.lifetimeLicense"),
			                                      price: localizedPrice,
			                                      purchaseDetail: LocalizedString.getValue("purchase.product.lifetimeLicense.duration"),
			                                      productIdentifier: .fullVersion)
			cells.append(.purchaseCell(viewModel))
		}
	}

	private func addUpgradeOfferItem() {
		cells.append(.showUpgradeOffer)
	}
}
