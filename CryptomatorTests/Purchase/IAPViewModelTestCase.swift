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

@available(iOS 14.0, *)
class IAPViewModelTestCase<SectionType: Hashable, ButtonAction: Hashable>: XCTestCase {
	var iapManagerMock: IAPManagerMock!
	var session: SKTestSession!

	override func setUpWithError() throws {
		session = try SKTestSession(configurationFileNamed: "Configuration")
		iapManagerMock = IAPManagerMock()
	}

	override func tearDown() {
		session.resetToDefaultState()
	}

	func assertCalledBuyProduct(with identifier: ProductIdentifier) {
		XCTAssertEqual(1, iapManagerMock.buyCallsCount)
		let buyReceivedProduct = iapManagerMock.buyReceivedProduct
		XCTAssertEqual(identifier.rawValue, buyReceivedProduct?.productIdentifier)
	}

	func recordEnabledStatusForAllButtonCellViewModels(next: Int, viewModel: TableViewModel<SectionType>) -> [Recorder<Bool, Never>] {
		var recorders = [Recorder<Bool, Never>]()
		viewModel.sections.forEach({ section in
			section.elements.forEach({
				if let buttonCellVM = $0 as? ButtonCellViewModel<ButtonAction> {
					recorders.append(buttonCellVM.isEnabled.$value.recordNext(next))
				}
			})
		})
		return recorders
	}

	func assertCorrectRunningTransactionBehavior(hasRunningTransactionRecorder: Recorder<Bool, Never>, buttonCellVMRecorders: [Recorder<Bool, Never>]) {
		XCTAssertEqual([true, false], hasRunningTransactionRecorder.getElements())
		assertCorrectEnabledStatusHistoryForAllButtonCellViewModels(recoders: buttonCellVMRecorders)
	}

	func assertCorrectIsLoadingBehavior(_ actualIsLoadingHistory: [Bool]) {
		XCTAssertEqual([false, true, false], actualIsLoadingHistory)
	}

	private func assertCorrectEnabledStatusHistoryForAllButtonCellViewModels(recoders: [Recorder<Bool, Never>]) {
		recoders.forEach({
			XCTAssertEqual([true, false, true], $0.getElements())
		})
	}
}
