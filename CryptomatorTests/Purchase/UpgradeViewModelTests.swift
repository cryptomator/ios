//
//  UpgradeViewModelTests.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 30.11.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Promises
import StoreKitTest
import XCTest
@testable import Cryptomator

@available(iOS 14.0, *)
class UpgradeViewModelTests: IAPViewModelTestCase {
	var viewModel: UpgradeViewModel!

	override func setUpWithError() throws {
		try super.setUpWithError()
		iapManagerMock.buyReturnValue = Promise(PurchaseTransaction.fullVersion)
		viewModel = UpgradeViewModel(iapManager: iapManagerMock, minimumDisplayTime: 0)
	}

	// MARK: Cells

	func testDefaultCellsBeforeFetchProducts() {
		assertShowsLoadingCell(viewModel: viewModel)
	}

	func testCellsAfterFetchProducts() {
		let expectedCells: [BaseIAPViewModel.Item] = [
			paidUpgradeCell,
			freeUpgradeCell
		]
		wait(for: viewModel.fetchProducts())
		XCTAssertEqual(expectedCells, viewModel.cells)
	}

	func testCellsAfterFetchProductsFailed() {
		let iapStoreMock = IAPStoreMock()
		iapStoreMock.fetchProductsWithReturnValue = Promise(SKError(.unknown))
		let viewModel = UpgradeViewModel(storeManager: iapStoreMock, iapManager: iapManagerMock, minimumDisplayTime: 0)
		wait(for: viewModel.fetchProducts(), timeout: 2.0)
		XCTAssertEqual([retryCell], viewModel.cells)
	}

	// MARK: Paid Upgrade

	func testPaidUpgrade() throws {
		iapManagerMock.buyReturnValue = Promise(.fullVersion)
		try assertBuyProductWorks(viewModel: viewModel,
		                          productIdentifier: .paidUpgrade,
		                          expectedPurchaseTransaction: .fullVersion)
	}

	func testPaidUpgradeCancelled() throws {
		iapManagerMock.buyReturnValue = Promise(SKError(.paymentCancelled))
		try assertCancelledBuyProduct(viewModel: viewModel,
		                              productIdentifier: .paidUpgrade)
	}

	// MARK: Free Upgrade

	func testFreeUpgrade() throws {
		iapManagerMock.buyReturnValue = Promise(.fullVersion)
		try assertBuyProductWorks(viewModel: viewModel,
		                          productIdentifier: .freeUpgrade,
		                          expectedPurchaseTransaction: .fullVersion)
	}

	func testFreeUpgradeCancelled() throws {
		iapManagerMock.buyReturnValue = Promise(SKError(.paymentCancelled))
		try assertCancelledBuyProduct(viewModel: viewModel,
		                              productIdentifier: .freeUpgrade)
	}

	private var freeUpgradeCell: Item {
		return .purchaseCell(.init(productName: LocalizedString.getValue("purchase.product.freeUpgrade"),
		                           price: LocalizedString.getValue("purchase.product.pricing.free"),
		                           purchaseDetail: nil,
		                           productIdentifier: .freeUpgrade))
	}

	private var paidUpgradeCell: Item {
		return .purchaseCell(.init(productName: LocalizedString.getValue("purchase.product.donateAndUpgrade"),
		                           price: "$1.99",
		                           purchaseDetail: LocalizedString.getValue("purchase.product.lifetimeLicense.duration"),
		                           productIdentifier: .paidUpgrade))
	}
}
