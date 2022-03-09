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

enum PurchaseError: Error {
	case unavailableProduct
	case paymentCancelled
}

class PurchaseViewModel: BaseIAPViewModel, ProductFetching {
	override var title: String? {
		return LocalizedString.getValue("purchase.title")
	}

	private let upgradeChecker: UpgradeCheckerProtocol
	private let cryptomatorSettings: CryptomatorSettings

	init(storeManager: IAPStore = StoreManager.shared, upgradeChecker: UpgradeCheckerProtocol = UpgradeChecker.shared, iapManager: IAPManager = StoreObserver.shared, cryptomatorSettings: CryptomatorSettings = CryptomatorUserDefaults.shared, minimumDisplayTime: TimeInterval = 1.0) {
		self.upgradeChecker = upgradeChecker
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

	/**
	 Presents the code redemption sheet.

	 - Note: The code redemption sheet does not work on the simulator.
	 */
	@available(iOS 14.0, *)
	func redeemCode() {
		SKPaymentQueue.default().presentCodeRedemptionSheet()
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
