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
class UpgradeViewModelTests: XCTestCase {
	var viewModel: UpgradeViewModel!
	var iapManagerMock: IAPManagerMock!
	var session: SKTestSession!

	override func setUpWithError() throws {
		session = try SKTestSession(configurationFileNamed: "Configuration")
		iapManagerMock = IAPManagerMock()
		iapManagerMock.buyReturnValue = Promise(PurchaseTransaction.fullVersion)
		viewModel = UpgradeViewModel(iapManager: iapManagerMock)
	}

	// MARK: Sections

	func testDefaultSections() {
		let expectedSections: [Section<UpgradeSection>] = [
			Section(id: .emptySection, elements: []),
			Section(id: .loadingSection, elements: [viewModel.loadingCellViewModel]),
			Section(id: .decideLaterSection, elements: [viewModel.decideLaterButtonCellViewModel])
		]
		XCTAssertEqual(expectedSections, viewModel.sections)
	}

	func testSectionsAfterFetchProducts() {
		let expectation = XCTestExpectation()
		let expectedSections: [Section<UpgradeSection>] = [
			Section(id: .emptySection, elements: []),
			Section(id: .paidUpgradeSection, elements: [viewModel.paidUpgradeButtonCellViewModel]),
			Section(id: .freeUpgradeSection, elements: [viewModel.freeUpgradeButtonCellViewModel]),
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

	func testPaidUpgradePriceFromStoreKit() {
		let expectation = XCTestExpectation()
		let expectedTitle = String(format: LocalizedString.getValue("upgrade.paidUpgrade.button"), "$1.99")
		viewModel.fetchProducts().then {
			XCTAssertEqual(expectedTitle, self.viewModel.paidUpgradeButtonCellViewModel.title.value)
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 2.0)
	}

	// MARK: Paid Upgrade

	func testPaidUpgrade() {
		let expectation = XCTestExpectation()
		viewModel.fetchProducts().then {
			self.viewModel.purchaseUpgrade()
		}.then {
			self.assertCalledBuyProduct(with: .paidUpgrade)
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 2.0)
	}

	func testPaidUpgradeCancelled() {
		let expectation = XCTestExpectation()
		iapManagerMock.buyReturnValue = Promise(SKError(.paymentCancelled))
		viewModel.fetchProducts().then {
			self.viewModel.purchaseUpgrade()
		}.then {
			XCTFail("Promise fulfilled")
		}.catch { error in
			XCTAssertEqual(.paymentCancelled, error as? PurchaseError)
			self.assertCalledBuyProduct(with: .paidUpgrade)
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 2.0)
	}

	// MARK: Free Upgrade

	func testFreeUpgrade() {
		let expectation = XCTestExpectation()
		viewModel.fetchProducts().then {
			self.viewModel.getFreeUpgrade()
		}.then {
			self.assertCalledBuyProduct(with: .freeUpgrade)
		}.catch { error in
			XCTFail("Promise failed with error: \(error)")
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 2.0)
	}

	func testFreeUpgradeCancelled() {
		let expectation = XCTestExpectation()
		iapManagerMock.buyReturnValue = Promise(SKError(.paymentCancelled))
		viewModel.fetchProducts().then {
			self.viewModel.getFreeUpgrade()
		}.then {
			XCTFail("Promise fulfilled")
		}.catch { error in
			XCTAssertEqual(.paymentCancelled, error as? PurchaseError)
			self.assertCalledBuyProduct(with: .freeUpgrade)
		}.always {
			expectation.fulfill()
		}
		wait(for: [expectation], timeout: 2.0)
	}

	private func assertCalledBuyProduct(with identifier: ProductIdentifier) {
		XCTAssertEqual(1, iapManagerMock.buyCallsCount)
		let buyReceivedProduct = iapManagerMock.buyReceivedProduct
		XCTAssertEqual(identifier.rawValue, buyReceivedProduct?.productIdentifier)
	}
}
