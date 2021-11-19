//
//  SetVaultNameViewModelTests.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 17.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

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
		getValidatetVaultNameThrowsEmptyVaultNameError()
	}

	func testValidateInputForDisallowedCharacters() throws {
		// \ inside name
		setVaultName("fo\\o")
		getValidatedVaultNameThrowsInvalidInputError()

		// / inside name
		setVaultName("fo/o")
		getValidatedVaultNameThrowsInvalidInputError()

		// : inside name
		setVaultName("fo:o")
		getValidatedVaultNameThrowsInvalidInputError()

		// * inside name
		setVaultName("fo*o")
		getValidatedVaultNameThrowsInvalidInputError()

		// ? inside name
		setVaultName("fo?o")
		getValidatedVaultNameThrowsInvalidInputError()

		// " inside name
		setVaultName("fo\"o")
		getValidatedVaultNameThrowsInvalidInputError()

		// < inside name
		setVaultName("fo<o")
		getValidatedVaultNameThrowsInvalidInputError()

		// > inside name
		setVaultName("fo>o")
		getValidatedVaultNameThrowsInvalidInputError()

		// | inside name
		setVaultName("fo|o")
		getValidatedVaultNameThrowsInvalidInputError()

		// Point at the end
		setVaultName("foo.")
		getValidatedVaultNameThrowsInvalidInputError()
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

	private func getValidatedVaultNameThrowsInvalidInputError() {
		XCTAssertThrowsError(try viewModel.getValidatedVaultName()) { error in
			guard case SetVaultNameViewModelError.invalidInput = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}
	}

	private func getValidatetVaultNameThrowsEmptyVaultNameError() {
		XCTAssertThrowsError(try viewModel.getValidatedVaultName()) { error in
			guard case SetVaultNameViewModelError.emptyVaultName = error else {
				XCTFail("Throws the wrong error: \(error)")
				return
			}
		}
	}
}
