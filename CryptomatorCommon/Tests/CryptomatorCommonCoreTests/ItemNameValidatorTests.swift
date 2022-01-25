//
//  ItemNameValidatorTests.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 24.01.22.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import XCTest

class ItemNameValidatorTests: XCTestCase {
	func testValidateItemName() throws {
		try ItemNameValidator.validateName("foo..pages")
		assertThrowsItemNameValidatorError(try ItemNameValidator.validateName("foo."), expectedError: .nameEndsWithPeriod)
		assertThrowsItemNameValidatorError(try ItemNameValidator.validateName("foo "), expectedError: .nameEndsWithSpace)
	}

	func testValidateItemNameIllegalCharacter() throws {
		// \ inside name
		assertThrowsIllegalCharacterErrorWhenValidating("fo\\o", illegalCharacter: "\\")

		// / inside name
		assertThrowsIllegalCharacterErrorWhenValidating("fo/o", illegalCharacter: "/")

		// : inside name
		assertThrowsIllegalCharacterErrorWhenValidating("fo:o", illegalCharacter: ":")

		// * inside name
		assertThrowsIllegalCharacterErrorWhenValidating("fo*o", illegalCharacter: "*")

		// ? inside name
		assertThrowsIllegalCharacterErrorWhenValidating("fo?o", illegalCharacter: "?")

		// " inside name
		assertThrowsIllegalCharacterErrorWhenValidating("fo\"o", illegalCharacter: "\"")

		// < inside name
		assertThrowsIllegalCharacterErrorWhenValidating("fo<o", illegalCharacter: "<")

		// > inside name
		assertThrowsIllegalCharacterErrorWhenValidating("fo>o", illegalCharacter: ">")

		// | inside name
		assertThrowsIllegalCharacterErrorWhenValidating("fo|o", illegalCharacter: "|")
	}

	private func assertThrowsIllegalCharacterErrorWhenValidating(_ name: String, illegalCharacter: String) {
		assertThrowsItemNameValidatorError(try ItemNameValidator.validateName(name), expectedError: .nameContainsIllegalCharacter(illegalCharacter))
	}

	private func assertThrowsItemNameValidatorError(_ expression: @autoclosure () throws -> Void, expectedError: ItemNameValidatorError) {
		XCTAssertThrowsError(try expression()) { error in
			XCTAssertEqual(expectedError, error as? ItemNameValidatorError)
		}
	}
}
