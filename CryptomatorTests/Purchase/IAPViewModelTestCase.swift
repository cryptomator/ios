//
//  IAPViewModelTestCase.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 08.12.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import StoreKitTest
import XCTest
@testable import Cryptomator
@testable import Promises

@available(iOS 14.0, *)
class IAPViewModelTestCase: XCTestCase {
	typealias Item = BaseIAPViewModel.Item
	var iapManagerMock: IAPManagerMock!
	var session: SKTestSession!
	var retryCell: Item {
		return .retryButton
	}

	override func setUpWithError() throws {
		session = try SKTestSession(configurationFileNamed: "Configuration")
		session.resetToDefaultState()
		session.disableDialogs = true
		session.clearTransactions()
		iapManagerMock = IAPManagerMock()
	}

	override func tearDown() {
		session.resetToDefaultState()
		session.clearTransactions()
	}

	func assertCalledBuyProduct(with identifier: ProductIdentifier) {
		XCTAssertEqual(1, iapManagerMock.buyCallsCount)
		let buyReceivedProduct = iapManagerMock.buyReceivedProduct
		XCTAssertEqual(identifier.rawValue, buyReceivedProduct?.productIdentifier)
	}

	func assertBuyProductWorks(viewModel: BaseIAPViewModel & ProductFetching, productIdentifier: ProductIdentifier, expectedPurchaseTransaction: PurchaseTransaction) throws {
		let hasRunningTransactionRecorder = viewModel.hasRunningTransaction.recordNext(2)
		let buttonCellVMsEnabledRecorders = recordEnabledStatusForAllButtonCellViewModels(next: 3, viewModel: viewModel)

		wait(for: viewModel.fetchProducts())
		let isLoadingRecorder = try XCTUnwrap(getIsLoadingRecorder(for: viewModel, productIdentifier: productIdentifier))
		let buyProductPromise = viewModel.buyProduct(productIdentifier)
		wait(for: buyProductPromise)
		let purchaseResult = try XCTUnwrap(buyProductPromise.value)

		XCTAssertEqual(expectedPurchaseTransaction, purchaseResult)
		assertCalledBuyProduct(with: productIdentifier)
		assertCorrectRunningTransactionBehavior(hasRunningTransactionRecorder: hasRunningTransactionRecorder, buttonCellVMRecorders: buttonCellVMsEnabledRecorders)
		assertCorrectIsLoadingBehavior(isLoadingRecorder.getElements())
	}

	func assertCancelledBuyProduct(viewModel: BaseIAPViewModel & ProductFetching, productIdentifier: ProductIdentifier) throws {
		let hasRunningTransactionRecorder = viewModel.hasRunningTransaction.recordNext(2)
		let buttonCellVMsEnabledRecorders = recordEnabledStatusForAllButtonCellViewModels(next: 3, viewModel: viewModel)

		wait(for: viewModel.fetchProducts())
		let isLoadingRecorder = try XCTUnwrap(getIsLoadingRecorder(for: viewModel, productIdentifier: productIdentifier))
		XCTAssertRejects(viewModel.buyProduct(productIdentifier), with: PurchaseError.paymentCancelled)
		assertCalledBuyProduct(with: productIdentifier)

		assertCorrectRunningTransactionBehavior(hasRunningTransactionRecorder: hasRunningTransactionRecorder, buttonCellVMRecorders: buttonCellVMsEnabledRecorders)
		assertCorrectIsLoadingBehavior(isLoadingRecorder.getElements())
	}

	func assertRestoredPurchase(viewModel: BaseIAPViewModel & ProductFetching, expectedResult: RestoreTransactionsResult) throws {
		let hasRunningTransactionRecorder = viewModel.hasRunningTransaction.recordNext(2)
		let buttonCellVMsEnabledRecorders = recordEnabledStatusForAllButtonCellViewModels(next: 3, viewModel: viewModel)

		wait(for: viewModel.fetchProducts())
		let restorePurchasePromise = viewModel.restorePurchase()
		wait(for: restorePurchasePromise)
		let purchaseResult = try XCTUnwrap(restorePurchasePromise.value)

		XCTAssertEqual(expectedResult, purchaseResult)
		XCTAssertEqual(1, iapManagerMock.restoreCallsCount)
		assertCorrectRunningTransactionBehavior(hasRunningTransactionRecorder: hasRunningTransactionRecorder, buttonCellVMRecorders: buttonCellVMsEnabledRecorders)
	}

	func recordEnabledStatusForAllButtonCellViewModels(next: Int, viewModel: BaseIAPViewModel) -> [Recorder<Bool, Never>] {
		var recorders = [Recorder<Bool, Never>]()
		for cell in viewModel.cells {
			if case let BaseIAPViewModel.Item.purchaseCell(cellViewModel) = cell {
				let buttonCellViewModel = cellViewModel.purchaseButtonViewModel
				recorders.append(buttonCellViewModel.isEnabled.$value.recordNext(next))
			}
		}
		return recorders
	}

	func assertCorrectRunningTransactionBehavior(hasRunningTransactionRecorder: Recorder<Bool, Never>, buttonCellVMRecorders: [Recorder<Bool, Never>]) {
		XCTAssertEqual([true, false], hasRunningTransactionRecorder.getElements())
		assertCorrectEnabledStatusHistoryForAllButtonCellViewModels(recorders: buttonCellVMRecorders)
	}

	func assertCorrectIsLoadingBehavior(_ actualIsLoadingHistory: [Bool]) {
		XCTAssertEqual([false, true, false], actualIsLoadingHistory)
	}

	func assertShowsLoadingCell(viewModel: BaseIAPViewModel) {
		XCTAssertEqual([.loadingCell], viewModel.cells)
	}

	func getIsLoadingRecorder(for viewModel: BaseIAPViewModel, productIdentifier: ProductIdentifier) -> Recorder<Bool, Never>? {
		let purchaseCellViewModels = viewModel.cells.compactMap { cell -> PurchaseCellViewModel? in
			switch cell {
			case let .purchaseCell(purchaseCellViewModel):
				return purchaseCellViewModel
			default:
				return nil
			}
		}

		guard let purchaseCellViewModel = purchaseCellViewModels.first(where: { $0.productIdentifier == productIdentifier }) else {
			XCTFail("Can't find a purchaseCell with productIdentifier: \(productIdentifier)")
			return nil
		}
		let purchaseButtonViewModel = purchaseCellViewModel.purchaseButtonViewModel
		return purchaseButtonViewModel.isLoading.$value.recordNext(3)
	}

	private func assertCorrectEnabledStatusHistoryForAllButtonCellViewModels(recorders: [Recorder<Bool, Never>]) {
		for recorder in recorders {
			XCTAssertEqual([true, false, true], recorder.getElements())
		}
	}
}
