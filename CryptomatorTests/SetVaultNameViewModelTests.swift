//
//  SetVaultNameViewModelTests.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 17.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import XCTest
@testable import Cryptomator

class SetVaultNameViewModelTests: XCTestCase {
	var viewModel: SetVaultNameViewModel!
	override func setUpWithError() throws {
		viewModel = SetVaultNameViewModel()
	}

	func testAutoTrimWhitespaces() throws {
		setVaultName(" foo")
		XCTAssertEqual("foo", viewModel.trimmedVaultName)
		setVaultName("foo ")
		XCTAssertEqual("foo", viewModel.trimmedVaultName)
		setVaultName(" foo ")
		XCTAssertEqual("foo", viewModel.trimmedVaultName)

		// Check preserves inner whitespace
		setVaultName("fo o")
		XCTAssertEqual("fo o", viewModel.trimmedVaultName)
	}

	func testValidateInputForValidName() throws {
		setVaultName("foo")
		let validatedVaultName = try viewModel.getValidatedVaultName()
		XCTAssertEqual("foo", validatedVaultName)
	}

	func testValidateInputForEmptyVaultName() throws {
		XCTAssert(viewModel.vaultNameCellViewModel.input.value.isEmpty)
		getValidatedVaultNameThrowsEmptyVaultNameError()
	}

	func testValidateInputForDisallowedCharacters() throws {
		// \ inside name
		setVaultName("fo\\o")
		getValidatedVaultNameThrowsError(ItemNameValidatorError.nameContainsIllegalCharacter("\\"))

		// / inside name
		setVaultName("fo/o")
		getValidatedVaultNameThrowsError(ItemNameValidatorError.nameContainsIllegalCharacter("/"))

		// : inside name
		setVaultName("fo:o")
		getValidatedVaultNameThrowsError(ItemNameValidatorError.nameContainsIllegalCharacter(":"))

		// * inside name
		setVaultName("fo*o")
		getValidatedVaultNameThrowsError(ItemNameValidatorError.nameContainsIllegalCharacter("*"))

		// ? inside name
		setVaultName("fo?o")
		getValidatedVaultNameThrowsError(ItemNameValidatorError.nameContainsIllegalCharacter("?"))

		// " inside name
		setVaultName("fo\"o")
		getValidatedVaultNameThrowsError(ItemNameValidatorError.nameContainsIllegalCharacter("\""))

		// < inside name
		setVaultName("fo<o")
		getValidatedVaultNameThrowsError(ItemNameValidatorError.nameContainsIllegalCharacter("<"))

		// > inside name
		setVaultName("fo>o")
		getValidatedVaultNameThrowsError(ItemNameValidatorError.nameContainsIllegalCharacter(">"))

		// | inside name
		setVaultName("fo|o")
		getValidatedVaultNameThrowsError(ItemNameValidatorError.nameContainsIllegalCharacter("|"))

		// Point at the end
		setVaultName("foo.")
		getValidatedVaultNameThrowsError(ItemNameValidatorError.nameEndsWithPeriod)
	}

	func testReturnButtonSupport() {
		let vaultNameCellViewModel = viewModel.vaultNameCellViewModel
		XCTAssert(vaultNameCellViewModel.isInitialFirstResponder)
		let lastReturnButtonPressedRecorder = viewModel.lastReturnButtonPressed.recordNext(1)
		vaultNameCellViewModel.returnButtonPressed()
		wait(for: lastReturnButtonPressedRecorder)
	}

	func setVaultName(_ name: String, viewModel: SetVaultNameViewModel) {
		viewModel.vaultNameCellViewModel.input.value = name
	}

	func setVaultName(_ name: String) {
		setVaultName(name, viewModel: viewModel)
	}

	private func getValidatedVaultNameThrowsError(_ expectedError: ItemNameValidatorError) {
		XCTAssertThrowsError(try viewModel.getValidatedVaultName()) { error in
			XCTAssertEqual(expectedError, error as? ItemNameValidatorError)
		}
	}

	private func getValidatedVaultNameThrowsEmptyVaultNameError() {
		XCTAssertThrowsError(try viewModel.getValidatedVaultName()) { error in
			guard case SetVaultNameViewModelError.emptyVaultName = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}
	}
}
