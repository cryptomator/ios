//
//  ItemNameValidator.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 24.01.22.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation

public enum ItemNameValidatorError: Error, Equatable {
	case nameEndsWithPeriod
	case nameEndsWithSpace
	case nameContainsIllegalCharacter(String)
}

extension ItemNameValidatorError: LocalizedError {
	public var errorDescription: String? {
		switch self {
		case .nameEndsWithPeriod:
			return LocalizedString.getValue("nameValidation.error.endsWithPeriod")
		case .nameEndsWithSpace:
			return LocalizedString.getValue("nameValidation.error.endsWithSpace")
		case let .nameContainsIllegalCharacter(illegalCharacter):
			return String(format: LocalizedString.getValue("nameValidation.error.containsIllegalCharacter"), illegalCharacter)
		}
	}
}

public enum ItemNameValidator {
	/**
	 Validates the item name.

	 Disallowed characters are: `\ / : * ? " < > |`
	 Furthermore, the item name cannot end with a period or space.
	 */
	public static func validateName(_ name: String) throws {
		if name.hasSuffix(".") {
			throw ItemNameValidatorError.nameEndsWithPeriod
		}
		if name.hasSuffix(" ") {
			throw ItemNameValidatorError.nameEndsWithSpace
		}

		let regex = try NSRegularExpression(pattern: "[\\\\/:\\*\\?\"<>\\|]")
		let range = NSRange(location: 0, length: name.utf16.count)
		if let match = regex.firstMatch(in: name, options: [], range: range) {
			let illegalCharacter = String(name[Range(match.range, in: name)!])
			throw ItemNameValidatorError.nameContainsIllegalCharacter(illegalCharacter)
		}
	}
}
