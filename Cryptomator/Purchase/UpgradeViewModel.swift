//
//  UpgradeViewModel.swift
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

enum UpgradeButtonAction {
	case paidUpgrade
	case freeUpgrade
	case decideLater
	case refreshProducts
}

enum UpgradeSection {
	case paidUpgradeSection
	case freeUpgradeSection
	case decideLaterSection
	case emptySection
	case loadingSection
	case retrySection
}

class UpgradeViewModel: BaseIAPViewModel<UpgradeSection, UpgradeButtonAction>, ProductFetching {
	override var title: String? {
		return LocalizedString.getValue("upgrade.title")
	}

	override var headerTitle: String? {
		return LocalizedString.getValue("upgrade.info")
	}

	override var sections: [Section<UpgradeSection>] {
		return _sections
	}

	lazy var freeUpgradeButtonCellViewModel = LoadingButtonCellViewModel<UpgradeButtonAction>(action: .freeUpgrade, title: LocalizedString.getValue("upgrade.freeUpgrade.button"))
	lazy var paidUpgradeButtonCellViewModel = LoadingButtonCellViewModel<UpgradeButtonAction>(action: .paidUpgrade, title: LocalizedString.getValue("upgrade.paidUpgrade.button"))
	lazy var decideLaterButtonCellViewModel = ButtonCellViewModel<UpgradeButtonAction>(action: .decideLater, title: LocalizedString.getValue("purchase.decideLater.button"))
	lazy var retryButtonCellViewModel = SystemSymbolButtonCellViewModel<UpgradeButtonAction>(action: .refreshProducts, title: LocalizedString.getValue("purchase.retry.button"), symbolName: "arrow.clockwise")
	lazy var loadingCellViewModel = LoadingCellViewModel()

	private lazy var _sections: [Section<UpgradeSection>] = {
		return [
			Section(id: .emptySection, elements: []),
			Section(id: .loadingSection, elements: [loadingCellViewModel]),
			Section(id: .decideLaterSection, elements: [decideLaterButtonCellViewModel])
		]
	}()

	override init(storeManager: IAPStore = StoreManager.shared, iapManager: IAPManager = StoreObserver.shared) {
		super.init(storeManager: storeManager, iapManager: iapManager)
	}

	func fetchProducts() -> Promise<Void> {
		return fetchProducts(with: [.paidUpgrade, .freeUpgrade]).always {
			self.removeLoadingSection()
		}
	}

	override func fetchProductsSuccess() {
		removeLoadingSection()
		addPaidUpgradeSection()
		addFreeUpgradeSection()
	}

	override func fetchProductsRecover() {
		addRetrySection()
	}

	func purchaseUpgrade() -> Promise<Void> {
		guard let product = products[.paidUpgrade] else {
			return Promise(UpgradeError.unavailableProduct)
		}
		return buyProduct(product, isLoadingBinding: paidUpgradeButtonCellViewModel.isLoading)
	}

	func getFreeUpgrade() -> Promise<Void> {
		guard let product = products[.freeUpgrade] else {
			return Promise(UpgradeError.unavailableProduct)
		}
		return buyProduct(product, isLoadingBinding: freeUpgradeButtonCellViewModel.isLoading)
	}

	func replaceRetrySectionWithLoadingSection() {
		if let index = _sections.firstIndex(where: { $0.id == .retrySection }) {
			_sections[index] = Section(id: .loadingSection, elements: [loadingCellViewModel])
		}
	}

	override func getFooterTitle(for section: Int) -> String? {
		switch sections[section].id {
		case .paidUpgradeSection:
			return LocalizedString.getValue("upgrade.paidUpgrade.footer")
		case .freeUpgradeSection:
			return LocalizedString.getValue("upgrade.freeUpgrade.footer")
		case .decideLaterSection:
			return LocalizedString.getValue("upgrade.decideLater.footer")
		case .retrySection:
			return LocalizedString.getValue("purchase.retry.footer")
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

	private func addRetrySection() {
		if let index = getDecideLaterSectionIndex() {
			_sections.insert(Section(id: .retrySection, elements: [retryButtonCellViewModel]), at: index)
		}
	}

	private func getDecideLaterSectionIndex() -> Int? {
		return _sections.firstIndex(where: { $0.id == .decideLaterSection })
	}

	private func buyProduct(_ product: SKProduct, isLoadingBinding: Bindable<Bool>) -> Promise<Void> {
		super.buyProduct(product, isLoadingBinding: isLoadingBinding).then { _ in
			// no-op
		}
	}
}
