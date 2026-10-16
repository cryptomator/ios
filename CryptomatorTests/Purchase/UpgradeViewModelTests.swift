//
//  UpgradeViewModelTests.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 30.11.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import StoreKit
import XCTest
@testable import Cryptomator

class UpgradeViewModelTests: IAPViewModelTestCase {
	var viewModel: UpgradeViewModel!

	override func setUp() async throws {
		try await super.setUp()
		iapManagerMock.buyReturnValue = PurchaseTransaction.fullVersion
		viewModel = UpgradeViewModel(storeManager: iapStoreMock, iapManager: iapManagerMock, minimumDisplayTime: 0)
	}

	// MARK: Cells

	func testDefaultCellsBeforeFetchProducts() {
		assertShowsLoadingCell(viewModel: viewModel)
	}

	func testCellsAfterFetchProducts() async {
		let expectedCells: [BaseIAPViewModel.Item] = [
			paidUpgradeCell,
			freeUpgradeCell
		]
		await viewModel.fetchProducts()
		XCTAssertEqual(expectedCells, viewModel.cells)
	}

	func testCellsAfterFetchProductsFailed() async {
		iapStoreMock.fetchProductsWithThrowableError = SKError(.unknown)
		let viewModel = UpgradeViewModel(storeManager: iapStoreMock, iapManager: iapManagerMock, minimumDisplayTime: 0)
		await viewModel.fetchProducts()
		XCTAssertEqual([retryCell], viewModel.cells)
	}

	// MARK: Paid Upgrade

	func testPaidUpgrade() async throws {
		iapManagerMock.buyReturnValue = .fullVersion
		try await assertBuyProductWorks(viewModel: viewModel,
		                                productIdentifier: .paidUpgrade,
		                                expectedPurchaseTransaction: .fullVersion)
	}

	func testPaidUpgradeCancelled() async throws {
		iapManagerMock.buyClosure = { _ in throw SKError(.paymentCancelled) }
		try await assertCancelledBuyProduct(viewModel: viewModel,
		                                    productIdentifier: .paidUpgrade)
	}

	// MARK: Free Upgrade

	func testFreeUpgrade() async throws {
		iapManagerMock.buyReturnValue = .fullVersion
		try await assertBuyProductWorks(viewModel: viewModel,
		                                productIdentifier: .freeUpgrade,
		                                expectedPurchaseTransaction: .fullVersion)
	}

	func testFreeUpgradeCancelled() async throws {
		iapManagerMock.buyClosure = { _ in throw SKError(.paymentCancelled) }
		try await assertCancelledBuyProduct(viewModel: viewModel,
		                                    productIdentifier: .freeUpgrade)
	}

	private var freeUpgradeCell: Item {
		return .purchaseCell(.init(productName: LocalizedString.getValue("purchase.product.freeUpgrade"),
		                           productDetail: nil,
		                           price: LocalizedString.getValue("purchase.product.pricing.free"),
		                           purchaseDetail: nil,
		                           productIdentifier: .freeUpgrade))
	}

	private var paidUpgradeCell: Item {
		return .purchaseCell(.init(productName: LocalizedString.getValue("purchase.product.donateAndUpgrade"),
		                           productDetail: nil,
		                           price: "$1.99",
		                           purchaseDetail: LocalizedString.getValue("purchase.product.lifetimeLicense.duration"),
		                           productIdentifier: .paidUpgrade))
	}
}
