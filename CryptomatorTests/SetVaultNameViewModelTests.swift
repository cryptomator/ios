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
		viewModel.vaultName = " foo"
		XCTAssertEqual("foo", viewModel.vaultName)
		viewModel.vaultName = "foo "
		XCTAssertEqual("foo", viewModel.vaultName)
		viewModel.vaultName = " foo "
		XCTAssertEqual("foo", viewModel.vaultName)

		// Check preserves inner whitespace
		viewModel.vaultName = "fo o"
		XCTAssertEqual("fo o", viewModel.vaultName)
	}

	func testValidateInputForValidName() throws {
		viewModel.vaultName = "foo"
		let validatedVaultName = try viewModel.getValidatedVaultName()
		XCTAssertEqual("foo", validatedVaultName)
	}

	func testValidateInputForEmptyString() throws {
		viewModel.vaultName = ""
		getValidatetVaultNameThrowsEmptyVaultNameError()
	}

	func testValidateInputForNotSetVaultName() throws {
		XCTAssertNil(viewModel.vaultName)
		getValidatetVaultNameThrowsEmptyVaultNameError()
	}

	func testValidateInputForDisallowedCharacters() throws {
		// \ inside name
		viewModel.vaultName = "fo\\o"
		getValidatedVaultNameThrowsInvalidInputError()

		// / inside name
		viewModel.vaultName = "fo/o"
		getValidatedVaultNameThrowsInvalidInputError()

		// : inside name
		viewModel.vaultName = "fo:o"
		getValidatedVaultNameThrowsInvalidInputError()

		// * inside name
		viewModel.vaultName = "fo*o"
		getValidatedVaultNameThrowsInvalidInputError()

		// ? inside name
		viewModel.vaultName = "fo?o"
		getValidatedVaultNameThrowsInvalidInputError()

		// " inside name
		viewModel.vaultName = "fo\"o"
		getValidatedVaultNameThrowsInvalidInputError()

		// < inside name
		viewModel.vaultName = "fo<o"
		getValidatedVaultNameThrowsInvalidInputError()

		// > inside name
		viewModel.vaultName = "fo>o"
		getValidatedVaultNameThrowsInvalidInputError()

		// | inside name
		viewModel.vaultName = "fo|o"
		getValidatedVaultNameThrowsInvalidInputError()

		// Point at the end
		viewModel.vaultName = "foo."
		getValidatedVaultNameThrowsInvalidInputError()
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
