//
//  PurchaseViewModelTests.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 23.11.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import StoreKit
import XCTest
@testable import Cryptomator
@testable import CryptomatorCommonCore

class PurchaseViewModelTests: IAPViewModelTestCase {
	var viewModel: PurchaseViewModel!
	var cryptomatorSettingsMock: CryptomatorSettingsMock!

	override func setUp() async throws {
		try await super.setUp()
		cryptomatorSettingsMock = CryptomatorSettingsMock()
		viewModel = PurchaseViewModel(storeManager: iapStoreMock, iapManager: iapManagerMock, cryptomatorSettings: cryptomatorSettingsMock, minimumDisplayTime: 0)
	}

	// MARK: Cells

	func testDefaultCellsBeforeFetchProducts() {
		assertShowsLoadingCell(viewModel: viewModel)
	}

	func testCellsAfterFetchProducts() async {
		let expectedCells: [BaseIAPViewModel.Item] = [
			purchaseTrialCell,
			yearlySubscriptionCell,
			lifetimeLicenseCell,
			upgradeOfferCell
		]
		await viewModel.fetchProducts()
		XCTAssertEqual(expectedCells, viewModel.cells)
	}

	func testCellsAfterFetchProductsWithRunningTrial() async {
		let expectedCells: [BaseIAPViewModel.Item] = [
			runningTrialCell,
			yearlySubscriptionCell,
			lifetimeLicenseCell,
			upgradeOfferCell
		]
		cryptomatorSettingsMock.trialExpirationDate = .distantFuture
		await viewModel.fetchProducts()
		XCTAssertEqual(expectedCells, viewModel.cells)
	}

	func testCellsAfterFetchProductsWithExpiredTrial() async {
		let expectedCells: [BaseIAPViewModel.Item] = [
			expiredTrialCell,
			yearlySubscriptionCell,
			lifetimeLicenseCell,
			upgradeOfferCell
		]
		cryptomatorSettingsMock.trialExpirationDate = .distantPast

		await viewModel.fetchProducts()
		XCTAssertEqual(expectedCells, viewModel.cells)
	}

	func testCellsAfterFetchProductsFailed() async {
		iapStoreMock.fetchProductsWithThrowableError = SKError(.unknown)
		let viewModel = PurchaseViewModel(storeManager: iapStoreMock, iapManager: iapManagerMock, cryptomatorSettings: cryptomatorSettingsMock)
		await viewModel.fetchProducts()
		XCTAssertEqual([retryCell], viewModel.cells)
	}

	// MARK: Begin Free Trial

	func testBeginFreeTrial() async throws {
		let trialExpirationDate = Date()
		setUpIAPManagerMockForBeginTrial(trialExpirationDate: trialExpirationDate)
		try await assertBuyProductWorks(viewModel: viewModel,
		                                productIdentifier: .thirtyDayTrial,
		                                expectedPurchaseTransaction: .freeTrial(expiresOn: trialExpirationDate))
	}

	func testBeginFreeTrialCancelled() async throws {
		iapManagerMock.buyClosure = { _ in throw SKError(.paymentCancelled) }
		try await assertCancelledBuyProduct(viewModel: viewModel,
		                                    productIdentifier: .thirtyDayTrial)
	}

	// MARK: Purchase Full Version

	func testPurchaseFullVersion() async throws {
		setUpIAPManagerMockForFullVersionPurchase()
		try await assertBuyProductWorks(viewModel: viewModel,
		                                productIdentifier: .fullVersion,
		                                expectedPurchaseTransaction: .fullVersion)
	}

	func testPurchaseFullVersionCancelled() async throws {
		iapManagerMock.buyClosure = { _ in throw SKError(.paymentCancelled) }
		try await assertCancelledBuyProduct(viewModel: viewModel,
		                                    productIdentifier: .fullVersion)
	}

	// MARK: Start Yearly Subscription

	func testPurchaseYearlySubscription() async throws {
		setUpIAPManagerMockForYearlySubscriptionPurchase()
		try await assertBuyProductWorks(viewModel: viewModel,
		                                productIdentifier: .yearlySubscription,
		                                expectedPurchaseTransaction: .yearlySubscription)
	}

	func testPurchaseYearlySubscriptionCancelled() async throws {
		iapManagerMock.buyClosure = { _ in throw SKError(.paymentCancelled) }
		try await assertCancelledBuyProduct(viewModel: viewModel,
		                                    productIdentifier: .yearlySubscription)
	}

	// MARK: - Restore Purchase

	func testRestoreFreeTrial() async throws {
		let expectedTrialExpirationDate = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 30, to: Date()))
		iapManagerMock.restoreReturnValue = .restoredFreeTrial(expiresOn: expectedTrialExpirationDate)
		try await assertRestoredPurchase(viewModel: viewModel, expectedResult: .restoredFreeTrial(expiresOn: expectedTrialExpirationDate))
	}

	func testRestoreFullVersion() async throws {
		iapManagerMock.restoreReturnValue = .restoredFullVersion
		try await assertRestoredPurchase(viewModel: viewModel, expectedResult: .restoredFullVersion)
	}

	func testRestoreNothing() async throws {
		iapManagerMock.restoreReturnValue = .noRestorablePurchases
		try await assertRestoredPurchase(viewModel: viewModel, expectedResult: .noRestorablePurchases)
	}

	// MARK: Internal

	private func setUpIAPManagerMockForFullVersionPurchase() {
		iapManagerMock.buyReturnValue = PurchaseTransaction.fullVersion
	}

	private func setUpIAPManagerMockForBeginTrial(trialExpirationDate: Date) {
		iapManagerMock.buyReturnValue = PurchaseTransaction.freeTrial(expiresOn: trialExpirationDate)
	}

	private func setUpIAPManagerMockForYearlySubscriptionPurchase() {
		iapManagerMock.buyReturnValue = PurchaseTransaction.yearlySubscription
	}

	private var purchaseTrialCell: Item {
		return .purchaseCell(.init(productName: LocalizedString.getValue("purchase.product.trial"),
		                           productDetail: nil,
		                           price: LocalizedString.getValue("purchase.product.pricing.free"),
		                           purchaseDetail: LocalizedString.getValue("purchase.product.trial.duration"),
		                           productIdentifier: .thirtyDayTrial))
	}

	private var yearlySubscriptionCell: Item {
		return .purchaseCell(.init(productName: LocalizedString.getValue("purchase.product.yearlySubscription"),
		                           productDetail: nil,
		                           price: "$5.99",
		                           purchaseDetail: LocalizedString.getValue("purchase.product.yearlySubscription.duration"),
		                           productIdentifier: .yearlySubscription))
	}

	private var lifetimeLicenseCell: Item {
		let productDetail = SalePromo.isHalloween2026Active() ? "\(SalePromo.halloween2026Emoji) \(SalePromo.halloween2026Discount)" : nil
		return .purchaseCell(.init(productName: LocalizedString.getValue("purchase.product.lifetimeLicense"),
		                           productDetail: productDetail,
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

extension Section: @MainActor Equatable {
	public static func == (lhs: Section, rhs: Section) -> Bool {
		lhs.id == rhs.id && lhs.elements == rhs.elements
	}
}
