//
//  URLValidator.swift
//  Cryptomator
//
//  Created by Majid Achhoud on 03.12.24.
//  Copyright © 2024 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Foundation

public enum URLValidatorError: Error, Equatable {
	case invalidURLFormat
}

extension URLValidatorError: LocalizedError {
	public var errorDescription: String? {
		switch self {
		case .invalidURLFormat:
			return LocalizedString.getValue("addVault.enterSharePointURL.error.invalidURL")
		}
	}
}

public enum URLValidator {
	public static func validateSharePointURL(urlString: String) throws {
		let pattern = #"^https:\/\/[a-zA-Z0-9\-]+\.sharepoint\.com\/sites\/[a-zA-Z0-9\-]+$"#
		let regex = try NSRegularExpression(pattern: pattern)
		let range = NSRange(location: 0, length: urlString.utf16.count)
		if regex.firstMatch(in: urlString, options: [], range: range) == nil {
			throw URLValidatorError.invalidURLFormat
		}
	}
}
