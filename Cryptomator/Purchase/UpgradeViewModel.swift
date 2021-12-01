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
import StoreKit

enum UpgradeButtonAction {
	case paidUpgrade
	case freeUpgrade
	case decideLater
}

enum UpgradeSection {
	case paidUpgradeSection
	case freeUpgradeSection
	case decideLaterSection
	case emptySection
	case loadingSection
}

class UpgradeViewModel: TableViewModel<UpgradeSection>, BaseIAPViewModel {
	override var title: String? {
		return LocalizedString.getValue("upgrade.title")
	}

	var headerTitle: String {
		return LocalizedString.getValue("upgrade.info")
	}

	override var sections: [Section<UpgradeSection>] {
		return _sections
	}

	lazy var freeUpgradeButtonCellViewModel = ButtonCellViewModel<UpgradeButtonAction>(action: .freeUpgrade, title: LocalizedString.getValue("upgrade.freeUpgrade.button"))
	lazy var paidUpgradeButtonCellViewModel = ButtonCellViewModel<UpgradeButtonAction>(action: .paidUpgrade, title: LocalizedString.getValue("upgrade.paidUpgrade.button"))
	lazy var decideLaterButtonCellViewModel = ButtonCellViewModel<UpgradeButtonAction>(action: .decideLater, title: LocalizedString.getValue("purchase.decideLater.button"))
	lazy var loadingCellViewModel = LoadingCellViewModel()

	private lazy var _sections: [Section<UpgradeSection>] = {
		return [
			Section(id: .emptySection, elements: []),
			Section(id: .loadingSection, elements: [loadingCellViewModel]),
			Section(id: .decideLaterSection, elements: [decideLaterButtonCellViewModel])
		]
	}()

	private let storeManager: StoreManager
	private let iapManager: IAPManager
	private var fetchProductsStart: CFAbsoluteTime = 0.0
	private let minimumDisplayTime: TimeInterval = 1.0
	private var products = [ProductIdentifier: SKProduct]()

	init(storeManager: StoreManager = StoreManager.shared, iapManager: IAPManager = StoreObserver.shared) {
		self.storeManager = storeManager
		self.iapManager = iapManager
	}

	func fetchProducts() -> Promise<Void> {
		fetchProductsStart = CFAbsoluteTimeGetCurrent()
		return storeManager.fetchProducts(with: [.paidUpgrade, .freeUpgrade]).then { response in
			self.products = response.products.reduce(into: [ProductIdentifier: SKProduct]()) {
				guard let productIdentifier = ProductIdentifier(rawValue: $1.productIdentifier) else {
					return
				}
				$0[productIdentifier] = $1
			}
		}.delay(getDelay()).then { _ -> Void in
			self.removeLoadingSection()
			self.addPaidUpgradeSection()
			self.addFreeUpgradeSection()
		}
	}

	func purchaseUpgrade() -> Promise<Void> {
		guard let product = products[.paidUpgrade] else {
			return Promise(UpgradeError.unavailableProduct)
		}
		return buyProduct(product)
	}

	func getFreeUpgrade() -> Promise<Void> {
		guard let product = products[.freeUpgrade] else {
			return Promise(UpgradeError.unavailableProduct)
		}
		return buyProduct(product)
	}

	func buttonAction(for indexPath: IndexPath) -> UpgradeButtonAction? {
		let section = sections[indexPath.section]
		guard let cell = section.elements[indexPath.row] as? ButtonCellViewModel<UpgradeButtonAction> else {
			return nil
		}
		return cell.action
	}

	override func getFooterTitle(for section: Int) -> String? {
		switch sections[section].id {
		case .paidUpgradeSection:
			return LocalizedString.getValue("upgrade.paidUpgrade.footer")
		case .freeUpgradeSection:
			return LocalizedString.getValue("upgrade.freeUpgrade.footer")
		case .decideLaterSection:
			return LocalizedString.getValue("upgrade.decideLater.footer")
		case .emptySection, .loadingSection:
			return nil
		}
	}

	private func removeLoadingSection() {
		if let index = _sections.firstIndex(where: { $0.id == .loadingSection }) {
			_sections.remove(at: index)
		}
	}

	private func addPaidUpgradeSection() {
		if let product = products[.paidUpgrade], let index = getDecideLaterSectionIndex(), let localizedPrice = product.localizedPrice {
			paidUpgradeButtonCellViewModel.title.value = String(format: LocalizedString.getValue("upgrade.paidUpgrade.button"), localizedPrice)
			_sections.insert(Section(id: .paidUpgradeSection, elements: [paidUpgradeButtonCellViewModel]), at: index)
		}
	}

	private func addFreeUpgradeSection() {
		if products[.freeUpgrade] != nil, let index = getDecideLaterSectionIndex() {
			_sections.insert(Section(id: .freeUpgradeSection, elements: [freeUpgradeButtonCellViewModel]), at: index)
		}
	}

	private func getDecideLaterSectionIndex() -> Int? {
		return _sections.firstIndex(where: { $0.id == .decideLaterSection })
	}

	private func getDelay() -> TimeInterval {
		if fetchProductsStart > 0 {
			return fetchProductsStart - CFAbsoluteTimeGetCurrent() + minimumDisplayTime
		} else {
			return 0
		}
	}

	private func buyProduct(_ product: SKProduct) -> Promise<Void> {
		return iapManager.buy(product).recover { error -> PurchaseTransaction in
			if (error as? SKError)?.code == .paymentCancelled {
				throw PurchaseError.paymentCancelled
			} else {
				throw error
			}
		}.then { _ in
			// no-op
		}
	}
}
