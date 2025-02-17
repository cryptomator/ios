//
//  PurchaseViewModelTests.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 23.11.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import StoreKitTest
import XCTest
@testable import Cryptomator
@testable import CryptomatorCommonCore
@testable import Promises

@available(iOS 14.0, *)
class PurchaseViewModelTests: IAPViewModelTestCase {
	var viewModel: PurchaseViewModel!
	var cryptomatorSettingsMock: CryptomatorSettingsMock!

	override func setUpWithError() throws {
		try super.setUpWithError()
		cryptomatorSettingsMock = CryptomatorSettingsMock()
		viewModel = PurchaseViewModel(iapManager: iapManagerMock, cryptomatorSettings: cryptomatorSettingsMock, minimumDisplayTime: 0)
	}

	// MARK: Cells

	func testDefaultCellsBeforeFetchProducts() {
		assertShowsLoadingCell(viewModel: viewModel)
	}

	func testCellsAfterFetchProducts() {
		let expectedCells: [BaseIAPViewModel.Item] = [
			purchaseTrialCell,
			yearlySubscriptionCell,
			lifetimeLicenseCell,
			upgradeOfferCell
		]
		wait(for: viewModel.fetchProducts())
		XCTAssertEqual(expectedCells, viewModel.cells)
	}

	func testCellsAfterFetchProductsWithRunningTrial() {
		let expectedCells: [BaseIAPViewModel.Item] = [
			runningTrialCell,
			yearlySubscriptionCell,
			lifetimeLicenseCell,
			upgradeOfferCell
		]
		cryptomatorSettingsMock.trialExpirationDate = .distantFuture
		wait(for: viewModel.fetchProducts())
		XCTAssertEqual(expectedCells, viewModel.cells)
	}

	func testCellsAfterFetchProductsWithExpiredTrial() {
		let expectedCells: [BaseIAPViewModel.Item] = [
			expiredTrialCell,
			yearlySubscriptionCell,
			lifetimeLicenseCell,
			upgradeOfferCell
		]
		cryptomatorSettingsMock.trialExpirationDate = .distantPast

		wait(for: viewModel.fetchProducts())
		XCTAssertEqual(expectedCells, viewModel.cells)
	}

	func testCellsAfterFetchProductsFailed() {
		let iapStoreMock = IAPStoreMock()
		iapStoreMock.fetchProductsWithReturnValue = Promise(SKError(.unknown))
		let viewModel = PurchaseViewModel(storeManager: iapStoreMock, iapManager: iapManagerMock, cryptomatorSettings: cryptomatorSettingsMock)
		wait(for: viewModel.fetchProducts(), timeout: 2.0)
		XCTAssertEqual([retryCell], viewModel.cells)
	}

	// MARK: Begin Free Trial

	func testBeginFreeTrial() throws {
		let trialExpirationDate = Date()
		setUpIAPManagerMockForBeginTrial(trialExpirationDate: trialExpirationDate)
		try assertBuyProductWorks(viewModel: viewModel,
		                          productIdentifier: .thirtyDayTrial,
		                          expectedPurchaseTransaction: .freeTrial(expiresOn: trialExpirationDate))
	}

	func testBeginFreeTrialCancelled() throws {
		iapManagerMock.buyReturnValue = Promise(SKError(.paymentCancelled))
		try assertCancelledBuyProduct(viewModel: viewModel,
		                              productIdentifier: .thirtyDayTrial)
	}

	// MARK: Purchase Full Version

	func testPurchaseFullVersion() throws {
		setUpIAPManagerMockForFullVersionPurchase()
		try assertBuyProductWorks(viewModel: viewModel,
		                          productIdentifier: .fullVersion,
		                          expectedPurchaseTransaction: .fullVersion)
	}

	func testPurchaseFullVersionCancelled() throws {
		iapManagerMock.buyReturnValue = Promise(SKError(.paymentCancelled))
		try assertCancelledBuyProduct(viewModel: viewModel,
		                              productIdentifier: .fullVersion)
	}

	// MARK: Start Yearly Subscription

	func testPurchaseYearlySubscription() throws {
		setUpIAPManagerMockForYearlySubscriptionPurchase()
		try assertBuyProductWorks(viewModel: viewModel,
		                          productIdentifier: .yearlySubscription,
		                          expectedPurchaseTransaction: .yearlySubscription)
	}

	func testPurchaseYearlySubscriptionCancelled() throws {
		iapManagerMock.buyReturnValue = Promise(SKError(.paymentCancelled))
		try assertCancelledBuyProduct(viewModel: viewModel,
		                              productIdentifier: .yearlySubscription)
	}

	// MARK: - Restore Purchase

	func testRestoreFreeTrial() throws {
		let expectedTrialExpirationDate = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 30, to: Date()))
		iapManagerMock.restoreReturnValue = Promise(.restoredFreeTrial(expiresOn: expectedTrialExpirationDate))
		try assertRestoredPurchase(viewModel: viewModel, expectedResult: .restoredFreeTrial(expiresOn: expectedTrialExpirationDate))
	}

	func testRestoreFullVersion() throws {
		iapManagerMock.restoreReturnValue = Promise(.restoredFullVersion)
		try assertRestoredPurchase(viewModel: viewModel, expectedResult: .restoredFullVersion)
	}

	func testRestoreNothing() throws {
		iapManagerMock.restoreReturnValue = Promise(.noRestorablePurchases)
		try assertRestoredPurchase(viewModel: viewModel, expectedResult: .noRestorablePurchases)
	}

	// MARK: Internal

	private func setUpIAPManagerMockForFullVersionPurchase() {
		iapManagerMock.buyReturnValue = Promise(PurchaseTransaction.fullVersion)
	}

	private func setUpIAPManagerMockForBeginTrial(trialExpirationDate: Date) {
		iapManagerMock.buyReturnValue = Promise(PurchaseTransaction.freeTrial(expiresOn: trialExpirationDate))
	}

	private func setUpIAPManagerMockForYearlySubscriptionPurchase() {
		iapManagerMock.buyReturnValue = Promise(PurchaseTransaction.yearlySubscription)
	}

	private var purchaseTrialCell: Item {
		return .purchaseCell(.init(productName: LocalizedString.getValue("purchase.product.trial"),
		                           price: LocalizedString.getValue("purchase.product.pricing.free"),
		                           purchaseDetail: LocalizedString.getValue("purchase.product.trial.duration"),
		                           productIdentifier: .thirtyDayTrial))
	}

	private var yearlySubscriptionCell: Item {
		return .purchaseCell(.init(productName: LocalizedString.getValue("purchase.product.yearlySubscription"),
		                           price: "$5.99",
		                           purchaseDetail: LocalizedString.getValue("purchase.product.yearlySubscription.duration"),
		                           productIdentifier: .yearlySubscription))
	}

	private var lifetimeLicenseCell: Item {
		return .purchaseCell(.init(productName: LocalizedString.getValue("purchase.product.lifetimeLicense"),
		                           price: "$11.99",
		                           purchaseDetail: LocalizedString.getValue("purchase.product.lifetimeLicense.duration"),
		                           productIdentifier: .fullVersion))
	}

	private var upgradeOfferCell: Item {
		return .showUpgradeOffer
	}

	private var runningTrialCell: Item {
		return .trialCell(.init(expirationDate: .distantFuture))
	}

	private var expiredTrialCell: Item {
		return .trialCell(.init(expirationDate: .distantPast))
	}
}

extension Section: Equatable {
	public static func == (lhs: Section, rhs: Section) -> Bool {
		lhs.id == rhs.id && lhs.elements == rhs.elements
	}
}
