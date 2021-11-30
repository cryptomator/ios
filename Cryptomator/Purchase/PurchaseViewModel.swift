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
}

enum PurchaseSection {
	case upgradeSection
	case trialSection
	case purchaseSection
	case restoreSection
	case decideLaterSection
	case loadingSection
	case emptySection
}

enum PurchaseError: Error {
	case unavailableProduct
	case paymentCancelled
}

class PurchaseViewModel: TableViewModel<PurchaseSection>, BaseIAPViewModel {
	lazy var upgradeButtonCellViewModel = ButtonCellViewModel<PurchaseButtonAction>.createDisclosureButton(action: .showUpgrade, title: LocalizedString.getValue("upgrade.title"))
	lazy var freeTrialButtonCellViewModel = ButtonCellViewModel<PurchaseButtonAction>(action: .beginFreeTrial, title: LocalizedString.getValue("purchase.beginFreeTrial.button"))
	lazy var purchaseButtonCellViewModel = ButtonCellViewModel<PurchaseButtonAction>(action: .purchaseFullVersion, title: LocalizedString.getValue("purchase.purchaseFullVersion.button"))
	lazy var restorePurchaseButtonCellViewModel = ButtonCellViewModel<PurchaseButtonAction>(action: .restorePurchase, title: LocalizedString.getValue("purchase.restorePurchase.button"))
	lazy var decideLaterButtonCellViewModel = ButtonCellViewModel<PurchaseButtonAction>(action: .decideLater, title: LocalizedString.getValue("purchase.decideLater.button"))
	lazy var loadingCellViewModel = LoadingCellViewModel()
	override var sections: [Section<PurchaseSection>] {
		return _sections
	}

	override var title: String? {
		return LocalizedString.getValue("purchase.title")
	}

	var headerTitle: String {
		return LocalizedString.getValue("purchase.info")
	}

	private lazy var _sections: [Section<PurchaseSection>] = {
		let sections: [Section<PurchaseSection>?] = [
			Section(id: .emptySection, elements: []),
			upgradeChecker.couldBeEligibleForUpgrade() ? Section(id: .upgradeSection, elements: [upgradeButtonCellViewModel]) : nil,
			Section(id: .loadingSection, elements: [loadingCellViewModel]),
			Section(id: .restoreSection, elements: [restorePurchaseButtonCellViewModel]),
			Section(id: .decideLaterSection, elements: [decideLaterButtonCellViewModel])
		]
		return sections.compactMap { $0 }
	}()

	private let storeManager: StoreManager
	private let upgradeChecker: UpgradeCheckerProtocol
	private let iapManager: IAPManager
	private var products = [ProductIdentifier: SKProduct]()
	private var fetchProductsStart: CFAbsoluteTime = 0.0
	private let minimumDisplayTime: TimeInterval = 1.0

	init(storeManager: StoreManager = StoreManager.shared, upgradeChecker: UpgradeCheckerProtocol = UpgradeChecker.shared, iapManager: IAPManager = StoreObserver.shared) {
		self.storeManager = storeManager
		self.upgradeChecker = upgradeChecker
		self.iapManager = iapManager
	}

	override func getFooterTitle(for section: Int) -> String? {
		switch sections[section].id {
		case .upgradeSection:
			return LocalizedString.getValue("purchase.upgrade.footer")
		case .trialSection:
			return LocalizedString.getValue("purchase.beginFreeTrial.footer")
		case .purchaseSection:
			return LocalizedString.getValue("purchase.purchaseFullVersion.footer")
		case .restoreSection:
			return LocalizedString.getValue("purchase.restorePurchase.footer")
		case .decideLaterSection:
			return LocalizedString.getValue("purchase.decideLater.footer")
		case .loadingSection, .emptySection:
			return nil
		}
	}

	func fetchProducts() -> Promise<Void> {
		fetchProductsStart = CFAbsoluteTimeGetCurrent()
		return storeManager.fetchProducts(with: [.thirtyDayTrial, .fullVersion]).then { response in
			self.products = response.products.reduce(into: [ProductIdentifier: SKProduct]()) {
				guard let productIdentifier = ProductIdentifier(rawValue: $1.productIdentifier) else {
					return
				}
				$0[productIdentifier] = $1
			}
		}.delay(getDelay()).then { _ -> Void in
			self.removeLoadingSection()
			self.addTrialSection()
			self.addPurchaseFullVersionSection()
		}
	}

	func buttonAction(for indexPath: IndexPath) -> PurchaseButtonAction {
		let section = sections[indexPath.section]
		guard let cell = section.elements[indexPath.row] as? ButtonCellViewModel<PurchaseButtonAction> else {
			return .unknown
		}
		return cell.action
	}

	func beginFreeTrial() -> Promise<Void> {
		guard let product = products[.thirtyDayTrial] else {
			return Promise(PurchaseError.unavailableProduct)
		}
		return buyProduct(product)
	}

	func purchaseFullVersion() -> Promise<Void> {
		guard let product = products[.fullVersion] else {
			return Promise(PurchaseError.unavailableProduct)
		}
		return buyProduct(product)
	}

	func restorePurchase() -> Promise<RestoreTransactionsResult> {
		return iapManager.restore()
	}

	private func removeLoadingSection() {
		if let index = _sections.firstIndex(where: { $0.id == .loadingSection }) {
			_sections.remove(at: index)
		}
	}

	private func addTrialSection() {
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

	private func getDelay() -> TimeInterval {
		if fetchProductsStart > 0 {
			return fetchProductsStart - CFAbsoluteTimeGetCurrent() + minimumDisplayTime
		} else {
			return 0
		}
	}

	private func delaySectionChange() -> Promise<Void> {
		return Promise<Void> { fulfill, _ in
			DispatchQueue.main.asyncAfter(deadline: .now() + self.getDelay()) {
				fulfill(())
			}
		}
	}

	private func buyProduct(_ product: SKProduct) -> Promise<Void> {
		return iapManager.buy(product).recover { error -> Void in
			if (error as? SKError)?.code == .paymentCancelled {
				throw PurchaseError.paymentCancelled
			} else {
				throw error
			}
		}
	}
}
