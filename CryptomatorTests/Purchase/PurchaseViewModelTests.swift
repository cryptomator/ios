//
//  PurchaseViewModelTests.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 23.11.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Promises
import StoreKitTest
import XCTest
@testable import Cryptomator

@available(iOS 14.0, *)
class PurchaseViewModelTests: XCTestCase {
	var viewModel: PurchaseViewModel!
	var iapManagerMock: IAPManagerMock!
	var upgradeCheckerMock: UpgradeCheckerMock!
	var cryptomatorSettingsMock: CryptomatorSettingsMock!
	var session: SKTestSession!

	override func setUpWithError() throws {
		session = try SKTestSession(configurationFileNamed: "Configuration")
		setUpMocks()
		viewModel = PurchaseViewModel(upgradeChecker: upgradeCheckerMock, iapManager: iapManagerMock, cryptomatorSettings: cryptomatorSettingsMock)
	}

	// MARK: Sections

	func testDefaultCellViewModelsNonEligibleUpgrade() {
		let expectedSections: [Section<PurchaseSection>] = [
			Section(id: .emptySection, elements: []),
			Section(id: .loadingSection, elements: [viewModel.loadingCellViewModel]),
			Section(id: .restoreSection, elements: [viewModel.restorePurchaseButtonCellViewModel]),
			Section(id: .decideLaterSection, elements: [viewModel.decideLaterButtonCellViewModel])
		]
		XCTAssertEqual(expectedSections, viewModel.sections)
		XCTAssertEqual(1, upgradeCheckerMock.couldBeEligibleForUpgradeCallsCount)
	}

	func testDefaultCellViewModelsEligibleUpgrade() {
		upgradeCheckerMock.couldBeEligibleForUpgradeReturnValue = true
		let expectedSections: [Section<PurchaseSection>] = [
			Section(id: .emptySection, elements: []),
			Section(id: .upgradeSection, elements: [viewModel.upgradeButtonCellViewModel]),
			Section(id: .loadingSection, elements: [viewModel.loadingCellViewModel]),
			Section(id: .restoreSection, elements: [viewModel.restorePurchaseButtonCellViewModel]),
			Section(id: .decideLaterSection, elements: [viewModel.decideLaterButtonCellViewModel])
		]
		XCTAssertEqual(expectedSections, viewModel.sections)
		XCTAssertEqual(1, upgradeCheckerMock.couldBeEligibleForUpgradeCallsCount)
	}

	func testOrderAfterFetchProducts() {
		let expectation = XCTestExpectation()
		let expectedSections: [Section<PurchaseSection>] = [
			Section(id: .emptySection, elements: []),
			Section(id: .trialSection, elements: [viewModel.freeTrialButtonCellViewModel]),
			Section(id: .purchaseSection, elements: [viewModel.purchaseButtonCellViewModel]),
			Section(id: .restoreSection, elements: [viewModel.restorePurchaseButtonCellViewModel]),
			Section(id: .decideLaterSection, elements: [viewModel.decideLaterButtonCellViewModel])
		]

		viewModel.fetchProducts().then {
			XCTAssertEqual(expectedSections, self.viewModel.sections)
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 2.0)
	}

	func testOrderAfterFetchProductsWithRunningTrial() {
		let expectation = XCTestExpectation()
		let expectedSections: [Section<PurchaseSection>] = [
			Section(id: .emptySection, elements: []),
			Section(id: .purchaseSection, elements: [viewModel.purchaseButtonCellViewModel]),
			Section(id: .restoreSection, elements: [viewModel.restorePurchaseButtonCellViewModel]),
			Section(id: .decideLaterSection, elements: [viewModel.decideLaterButtonCellViewModel])
		]

		cryptomatorSettingsMock.trialExpirationDate = .distantFuture
		viewModel.fetchProducts().then {
			XCTAssertEqual(expectedSections, self.viewModel.sections)
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 2.0)
	}

	func testFullVersionPriceFromStoreKit() {
		let expectation = XCTestExpectation()
		let expectedTitle = String(format: LocalizedString.getValue("purchase.purchaseFullVersion.button"), "$11.99")
		viewModel.fetchProducts().then {
			XCTAssertEqual(expectedTitle, self.viewModel.purchaseButtonCellViewModel.title.value)
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 2.0)
	}

	func testShowRefreshSectionIfFetchProductsFailed() {
		let expectation = XCTestExpectation()
		let iapStoreMock = IAPStoreMock()
		iapStoreMock.fetchProductsWithReturnValue = Promise(SKError(.unknown))
		let viewModel = PurchaseViewModel(storeManager: iapStoreMock, upgradeChecker: upgradeCheckerMock, iapManager: iapManagerMock, cryptomatorSettings: cryptomatorSettingsMock)
		viewModel.fetchProducts().then {
			self.assertShowReloadSectionAfterFetchProductFailed(viewModel: viewModel)
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 2.0)
	}

	// MARK: Header Title

	func testHeaderTitle() {
		cryptomatorSettingsMock.trialExpirationDate = nil
		cryptomatorSettingsMock.fullVersionUnlocked = false
		XCTAssertEqual(LocalizedString.getValue("purchase.info"), viewModel.headerTitle)
	}

	func testHeaderTitleForRunningTrial() {
		let trialExpirationDate = Date.distantFuture
		cryptomatorSettingsMock.trialExpirationDate = trialExpirationDate
		cryptomatorSettingsMock.fullVersionUnlocked = false

		let formatter = DateFormatter()
		formatter.dateStyle = .short
		let formattedExpireDate = formatter.string(for: trialExpirationDate)!
		let expectedHeaderTitle = String(format: LocalizedString.getValue("purchase.infoRunningTrial"), formattedExpireDate)
		XCTAssertEqual(expectedHeaderTitle, viewModel.headerTitle)
	}

	func testHeaderTitleForExpiredTrial() {
		cryptomatorSettingsMock.trialExpirationDate = .distantPast
		cryptomatorSettingsMock.fullVersionUnlocked = false
		XCTAssertEqual(LocalizedString.getValue("purchase.infoExpiredTrial"), viewModel.headerTitle)
	}

	// MARK: Begin Free Trial

	func testBeginFreeTrial() {
		let expectation = XCTestExpectation()
		let trialExpirationDate = Date()
		setUpIAPManagerMockForBeginTrial(trialExpirationDate: trialExpirationDate)
		viewModel.fetchProducts().then {
			self.viewModel.beginFreeTrial()
		}.then { actualTrialExpirationDate in
			XCTAssertEqual(trialExpirationDate, actualTrialExpirationDate)
			self.assertBuyProduct(with: .thirtyDayTrial)
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 2.0)
	}

	func testBeginFreeTrialCancelled() {
		let expectation = XCTestExpectation()
		iapManagerMock.buyReturnValue = Promise(SKError(.paymentCancelled))
		viewModel.fetchProducts().then {
			self.viewModel.beginFreeTrial()
		}.then { _ in
			XCTFail("Promise fulfilled")
		}.catch { error in
			XCTAssertEqual(.paymentCancelled, error as? PurchaseError)
			self.assertBuyProduct(with: .thirtyDayTrial)
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 2.0)
	}

	// MARK: Purchase Full Version

	func testPurchaseFullVersion() {
		let expectation = XCTestExpectation()
		setUpIAPManagerMockForFullVersionPurchase()
		viewModel.fetchProducts().then {
			self.viewModel.purchaseFullVersion()
		}.then {
			self.assertBuyProduct(with: .fullVersion)
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 2.0)
	}

	func testPurchaseFullVersionCancelled() {
		let expectation = XCTestExpectation()
		iapManagerMock.buyReturnValue = Promise(SKError(.paymentCancelled))
		viewModel.fetchProducts().then {
			self.viewModel.purchaseFullVersion()
		}.then {
			XCTFail("Promise fulfilled")
		}.catch { error in
			XCTAssertEqual(.paymentCancelled, error as? PurchaseError)
			self.assertBuyProduct(with: .fullVersion)
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 2.0)
	}

	// MARK: - Restore Purchase

	func testRestoreFreeTrial() throws {
		let expectation = XCTestExpectation()
		guard let excpectedTrialExpirationDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) else {
			XCTFail("Could not create excpectedTrialExpirationDate")
			return
		}
		iapManagerMock.restoreReturnValue = Promise(.restoredFreeTrial(expiresOn: excpectedTrialExpirationDate))
		viewModel.fetchProducts().then {
			self.viewModel.restorePurchase()
		}.then { result in
			XCTAssertEqual(.restoredFreeTrial(expiresOn: excpectedTrialExpirationDate), result)
			XCTAssertEqual(1, self.iapManagerMock.restoreCallsCount)
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 2.0)
	}

	func testRestoreFullVersion() throws {
		let expectation = XCTestExpectation()
		iapManagerMock.restoreReturnValue = Promise(.restoredFullVersion)
		viewModel.fetchProducts().then {
			self.viewModel.restorePurchase()
		}.then { result in
			XCTAssertEqual(.restoredFullVersion, result)
			XCTAssertEqual(1, self.iapManagerMock.restoreCallsCount)
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 2.0)
	}

	private func assertBuyProduct(with identifier: ProductIdentifier) {
		XCTAssertEqual(1, iapManagerMock.buyCallsCount)
		let buyReceivedProduct = iapManagerMock.buyReceivedProduct
		XCTAssertEqual(identifier.rawValue, buyReceivedProduct?.productIdentifier)
	}

	private func setUpMocks() {
		iapManagerMock = IAPManagerMock()
		upgradeCheckerMock = UpgradeCheckerMock()
		upgradeCheckerMock.couldBeEligibleForUpgradeReturnValue = false
		cryptomatorSettingsMock = CryptomatorSettingsMock()
	}

	private func setUpIAPManagerMockForFullVersionPurchase() {
		iapManagerMock.buyReturnValue = Promise(PurchaseTransaction.fullVersion)
	}

	private func setUpIAPManagerMockForBeginTrial(trialExpirationDate: Date) {
		iapManagerMock.buyReturnValue = Promise(PurchaseTransaction.freeTrial(expiresOn: trialExpirationDate))
	}

	private func assertShowReloadSectionAfterFetchProductFailed(viewModel: PurchaseViewModel) {
		let expectedSections: [Section<PurchaseSection>] = [
			Section(id: .emptySection, elements: []),
			Section(id: .retrySection, elements: [viewModel.retryButtonCellViewModel]),
			Section(id: .restoreSection, elements: [viewModel.restorePurchaseButtonCellViewModel]),
			Section(id: .decideLaterSection, elements: [viewModel.decideLaterButtonCellViewModel])
		]
		XCTAssertEqual(expectedSections, viewModel.sections)
		XCTAssertEqual(LocalizedString.getValue("purchase.retry.button"), viewModel.retryButtonCellViewModel.title.value)
		XCTAssertEqual(LocalizedString.getValue("purchase.retry.footer"), viewModel.getFooterTitle(for: 1))
	}
}

extension Section: Equatable {
	public static func == (lhs: Section, rhs: Section) -> Bool {
		lhs.id == rhs.id && lhs.elements == rhs.elements
	}
}
