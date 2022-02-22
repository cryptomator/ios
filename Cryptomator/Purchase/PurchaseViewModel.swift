//
//  PurchaseViewModel.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 08.09.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Combine
import CryptomatorCommonCore
import Foundation
import Promises
import StoreKit
import UIKit

enum PurchaseButtonAction {
	case showUpgrade
	case beginFreeTrial
	case purchaseFullVersion
	case restorePurchase
	case decideLater
	case unknown
	case refreshProducts
	case startSubscription
	@available(iOS 14.0, *)
	case redeemCode
}

enum PurchaseSection {
	case upgradeSection
	case trialSection
	case purchaseSection
	case restoreSection
	case decideLaterSection
	case loadingSection
	case emptySection
	case retrySection
	case subscribeSection
}

enum PurchaseError: Error {
	case unavailableProduct
	case paymentCancelled
}

class PurchaseViewModel: BaseIAPViewModel<PurchaseSection, PurchaseButtonAction>, ProductFetching {
	lazy var upgradeButtonCellViewModel = ButtonCellViewModel<PurchaseButtonAction>.createDisclosureButton(action: .showUpgrade, title: LocalizedString.getValue("upgrade.title"))
	lazy var freeTrialButtonCellViewModel = LoadingButtonCellViewModel<PurchaseButtonAction>(action: .beginFreeTrial, title: LocalizedString.getValue("purchase.beginFreeTrial.button"))
	lazy var purchaseButtonCellViewModel = LoadingButtonCellViewModel<PurchaseButtonAction>(action: .purchaseFullVersion, title: LocalizedString.getValue("purchase.purchaseFullVersion.button"))
	lazy var restorePurchaseButtonCellViewModel = LoadingButtonCellViewModel<PurchaseButtonAction>(action: .restorePurchase, title: LocalizedString.getValue("purchase.restorePurchase.button"))
	lazy var decideLaterButtonCellViewModel = ButtonCellViewModel<PurchaseButtonAction>(action: .decideLater, title: LocalizedString.getValue("purchase.decideLater.button"))
	lazy var retryButtonCellViewModel = SystemSymbolButtonCellViewModel<PurchaseButtonAction>(action: .refreshProducts, title: LocalizedString.getValue("purchase.retry.button"), symbolName: "arrow.clockwise")
	lazy var subscribeButtonCellViewModel = LoadingButtonCellViewModel<PurchaseButtonAction>(action: .startSubscription, title: LocalizedString.getValue("purchase.startSubscription.button"))
	@available(iOS 14.0, *)
	lazy var redeemButtonCellViewModel = ButtonCellViewModel<PurchaseButtonAction>(action: .redeemCode, title: LocalizedString.getValue("purchase.redeemCode.button"))
	lazy var loadingCellViewModel = LoadingCellViewModel()
	override var sections: [Section<PurchaseSection>] {
		return _sections
	}

	override var title: String? {
		return LocalizedString.getValue("purchase.title")
	}

	override var headerTitle: String? {
		if let trialExpirationDate = trialExpirationDate {
			return getHeaderTitle(for: trialExpirationDate)
		} else {
			return LocalizedString.getValue("purchase.info")
		}
	}

	private var trialExpirationDate: Date? {
		return cryptomatorSettings.trialExpirationDate
	}

	private lazy var _sections: [Section<PurchaseSection>] = {
		let sections: [Section<PurchaseSection>?] = [
			Section(id: .emptySection, elements: []),
			Section(id: .upgradeSection, elements: [upgradeButtonCellViewModel]),
			Section(id: .loadingSection, elements: [loadingCellViewModel]),
			Section(id: .restoreSection, elements: [restorePurchaseButtonCellViewModel]),
			Section(id: .decideLaterSection, elements: [decideLaterButtonCellViewModel])
		]
		return sections.compactMap { $0 }
	}()

	private let upgradeChecker: UpgradeCheckerProtocol
	private let cryptomatorSettings: CryptomatorSettings

	init(storeManager: IAPStore = StoreManager.shared, upgradeChecker: UpgradeCheckerProtocol = UpgradeChecker.shared, iapManager: IAPManager = StoreObserver.shared, cryptomatorSettings: CryptomatorSettings = CryptomatorUserDefaults.shared) {
		self.upgradeChecker = upgradeChecker
		self.cryptomatorSettings = cryptomatorSettings
		super.init(storeManager: storeManager, iapManager: iapManager)
	}

	override func getFooterTitle(for section: Int) -> String? {
		switch sections[section].id {
		case .upgradeSection:
			if upgradeChecker.couldBeEligibleForUpgrade() {
				return LocalizedString.getValue("purchase.upgrade.footer")
			} else {
				return LocalizedString.getValue("purchase.upgrade.notEligible.footer")
			}
		case .trialSection:
			return LocalizedString.getValue("purchase.beginFreeTrial.footer")
		case .purchaseSection:
			return LocalizedString.getValue("purchase.purchaseFullVersion.footer")
		case .restoreSection:
			return LocalizedString.getValue("purchase.restorePurchase.footer")
		case .decideLaterSection:
			return LocalizedString.getValue("purchase.decideLater.footer")
		case .retrySection:
			return LocalizedString.getValue("purchase.retry.footer")
		case .loadingSection, .emptySection, .subscribeSection:
			return nil
		}
	}

	func fetchProducts() -> Promise<Void> {
		return fetchProducts(with: [.thirtyDayTrial, .fullVersion, .yearlySubscription]).always {
			self.removeLoadingSection()
		}
	}

	override func fetchProductsSuccess() {
		addTrialSection()
		addPurchaseFullVersionSection()
		addStartSubscriptionSection()
	}

	override func fetchProductsRecover() {
		addRetrySection()
	}

	func beginFreeTrial() -> Promise<Date> {
		guard let product = products[.thirtyDayTrial] else {
			return Promise(PurchaseError.unavailableProduct)
		}
		return buyProduct(product, isLoadingBinding: freeTrialButtonCellViewModel.isLoading).then { result -> Date in
			guard case let PurchaseTransaction.freeTrial(trialExpirationDate) = result else {
				throw PurchaseError.unavailableProduct
			}
			return trialExpirationDate
		}
	}

	func purchaseFullVersion() -> Promise<Void> {
		guard let product = products[.fullVersion] else {
			return Promise(PurchaseError.unavailableProduct)
		}
		return buyProduct(product, isLoadingBinding: purchaseButtonCellViewModel.isLoading).then { _ in
			// no-op
		}
	}

	func startSubscription() -> Promise<Void> {
		guard let product = products[.yearlySubscription] else {
			return Promise(PurchaseError.unavailableProduct)
		}
		return buyProduct(product, isLoadingBinding: subscribeButtonCellViewModel.isLoading).then { _ in
			// no-op
		}
	}

	func restorePurchase() -> Promise<RestoreTransactionsResult> {
		return restorePurchase(isLoadingBinding: restorePurchaseButtonCellViewModel.isLoading)
	}

	/**
	 Presents the code redemption sheet.

	 - Note: The code redemption sheet does not work on the simulator.
	 */
	@available(iOS 14.0, *)
	func redeemCode() {
		SKPaymentQueue.default().presentCodeRedemptionSheet()
	}

	func replaceRetrySectionWithLoadingSection() {
		if let index = _sections.firstIndex(where: { $0.id == .retrySection }) {
			_sections[index] = Section(id: .loadingSection, elements: [loadingCellViewModel])
		}
	}

	private func removeLoadingSection() {
		if let index = _sections.firstIndex(where: { $0.id == .loadingSection }) {
			_sections.remove(at: index)
		}
	}

	private func addTrialSection() {
		guard cryptomatorSettings.trialExpirationDate == nil else {
			return
		}
		if products[.thirtyDayTrial] != nil, let index = getRestoreSectionIndex() {
			_sections.insert(Section(id: .trialSection, elements: [freeTrialButtonCellViewModel]), at: index)
		}
	}

	private func addPurchaseFullVersionSection() {
		if let product = products[.fullVersion], let index = getRestoreSectionIndex(), let localizedPrice = product.localizedPrice {
			purchaseButtonCellViewModel.title.value = String(format: LocalizedString.getValue("purchase.purchaseFullVersion.button"), localizedPrice)
			_sections.insert(Section(id: .purchaseSection, elements: [purchaseButtonCellViewModel]), at: index)
		}
	}

	private func getRestoreSectionIndex() -> Int? {
		return _sections.firstIndex(where: { $0.id == .restoreSection })
	}

	private func getHeaderTitle(for trialExpirationDate: Date) -> String {
		if trialExpirationDate > Date() {
			let formatter = DateFormatter()
			formatter.dateStyle = .short
			let formattedExpireDate = formatter.string(for: trialExpirationDate) ?? "Invalid Date"
			return String(format: LocalizedString.getValue("purchase.infoRunningTrial"), formattedExpireDate)
		} else {
			return LocalizedString.getValue("purchase.infoExpiredTrial")
		}
	}

	private func addRetrySection() {
		if let index = getRestoreSectionIndex() {
			_sections.insert(Section(id: .retrySection, elements: [retryButtonCellViewModel]), at: index)
		}
	}

	private func addStartSubscriptionSection() {
		if let product = products[.yearlySubscription], let index = getRestoreSectionIndex(), let localizedPrice = product.localizedPrice {
			subscribeButtonCellViewModel.title.value = String(format: LocalizedString.getValue("purchase.startSubscription.button"), localizedPrice)
			let elements: [ButtonCellViewModel<PurchaseButtonAction>]
			if #available(iOS 14.0, *) {
				elements = [subscribeButtonCellViewModel, redeemButtonCellViewModel]
			} else {
				elements = [subscribeButtonCellViewModel]
			}
			_sections.insert(Section(id: .subscribeSection, elements: elements), at: index)
		}
	}
}
