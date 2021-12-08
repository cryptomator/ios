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
class UpgradeViewModelTests: IAPViewModelTestCase<UpgradeSection, UpgradeButtonAction> {
	var viewModel: UpgradeViewModel!

	override func setUpWithError() throws {
		try super.setUpWithError()
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

	func testShowRefreshSectionIfFetchProductsFailed() {
		let expectation = XCTestExpectation()
		let iapStoreMock = IAPStoreMock()
		iapStoreMock.fetchProductsWithReturnValue = Promise(SKError(.unknown))
		let viewModel = UpgradeViewModel(storeManager: iapStoreMock, iapManager: iapManagerMock)
		viewModel.fetchProducts().then {
			self.assertShowReloadSectionAfterFetchProductFailed(viewModel: viewModel)
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
		let hasRunningTransactionRecorder = viewModel.hasRunningTransaction.recordNext(2)
		let buttonCellVMsEnabledRecorders = recordEnabledStatusForAllButtonCellViewModels(next: 3, viewModel: viewModel)
		let isLoadingRecorder = viewModel.paidUpgradeButtonCellViewModel.isLoading.$value.recordNext(3)
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
		assertCorrectRunningTransactionBehavior(hasRunningTransactionRecorder: hasRunningTransactionRecorder, buttonCellVMRecorders: buttonCellVMsEnabledRecorders)
		assertCorrectIsLoadingBehavior(isLoadingRecorder.getElements())
	}

	func testPaidUpgradeCancelled() {
		let expectation = XCTestExpectation()
		let hasRunningTransactionRecorder = viewModel.hasRunningTransaction.recordNext(2)
		let buttonCellVMsEnabledRecorders = recordEnabledStatusForAllButtonCellViewModels(next: 3, viewModel: viewModel)
		let isLoadingRecorder = viewModel.paidUpgradeButtonCellViewModel.isLoading.$value.recordNext(3)
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
		assertCorrectRunningTransactionBehavior(hasRunningTransactionRecorder: hasRunningTransactionRecorder, buttonCellVMRecorders: buttonCellVMsEnabledRecorders)
		assertCorrectIsLoadingBehavior(isLoadingRecorder.getElements())
	}

	// MARK: Free Upgrade

	func testFreeUpgrade() {
		let expectation = XCTestExpectation()
		let hasRunningTransactionRecorder = viewModel.hasRunningTransaction.recordNext(2)
		let buttonCellVMsEnabledRecorders = recordEnabledStatusForAllButtonCellViewModels(next: 3, viewModel: viewModel)
		let isLoadingRecorder = viewModel.freeUpgradeButtonCellViewModel.isLoading.$value.recordNext(3)
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
		assertCorrectRunningTransactionBehavior(hasRunningTransactionRecorder: hasRunningTransactionRecorder, buttonCellVMRecorders: buttonCellVMsEnabledRecorders)
		assertCorrectIsLoadingBehavior(isLoadingRecorder.getElements())
	}

	func testFreeUpgradeCancelled() {
		let expectation = XCTestExpectation()
		let hasRunningTransactionRecorder = viewModel.hasRunningTransaction.recordNext(2)
		let buttonCellVMsEnabledRecorders = recordEnabledStatusForAllButtonCellViewModels(next: 3, viewModel: viewModel)
		let isLoadingRecorder = viewModel.freeUpgradeButtonCellViewModel.isLoading.$value.recordNext(3)
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
		assertCorrectRunningTransactionBehavior(hasRunningTransactionRecorder: hasRunningTransactionRecorder, buttonCellVMRecorders: buttonCellVMsEnabledRecorders)
		assertCorrectIsLoadingBehavior(isLoadingRecorder.getElements())
	}

	private func assertShowReloadSectionAfterFetchProductFailed(viewModel: UpgradeViewModel) {
		let expectedSections: [Section<UpgradeSection>] = [
			Section(id: .emptySection, elements: []),
			Section(id: .retrySection, elements: [viewModel.retryButtonCellViewModel]),
			Section(id: .decideLaterSection, elements: [viewModel.decideLaterButtonCellViewModel])
		]
		XCTAssertEqual(expectedSections, viewModel.sections)
		XCTAssertEqual(LocalizedString.getValue("purchase.retry.button"), viewModel.retryButtonCellViewModel.title.value)
		XCTAssertEqual(LocalizedString.getValue("purchase.retry.footer"), viewModel.getFooterTitle(for: 1))
	}
}
