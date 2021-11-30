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
	var session: SKTestSession!

	override func setUpWithError() throws {
		session = try SKTestSession(configurationFileNamed: "Configuration")
		iapManagerMock = IAPManagerMock()
		iapManagerMock.buyReturnValue = Promise(())
		upgradeCheckerMock = UpgradeCheckerMock()
		upgradeCheckerMock.couldBeEligibleForUpgradeReturnValue = false
		viewModel = PurchaseViewModel(upgradeChecker: upgradeCheckerMock, iapManager: iapManagerMock)
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

	// MARK: Begin Free Trial

	func testBeginFreeTrial() {
		let expectation = XCTestExpectation()
		viewModel.fetchProducts().then {
			self.viewModel.beginFreeTrial()
		}.then {
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
		}.then {
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
}

extension Section: Equatable {
	public static func == (lhs: Section, rhs: Section) -> Bool {
		lhs.id == rhs.id && lhs.elements == rhs.elements
	}
}
