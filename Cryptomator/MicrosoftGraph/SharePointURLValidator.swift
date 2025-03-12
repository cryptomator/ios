//
//  SharePointURLValidator.swift
//  Cryptomator
//
//  Created by Majid Achhoud on 03.12.24.
//  Copyright © 2024 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import Foundation

public enum SharePointURLValidator {
	public static func validateSharePointURL(urlString: String) throws -> URL {
		guard !urlString.isEmpty else {
			throw SharePointURLValidatorError.emptyURL
		}
		// Regex pattern breakdown:
		// ^https:\/\/                    => URL must start with "https://"
		// [a-zA-Z0-9-]+\.sharepoint\.com => Domain must include the subdomain and ".sharepoint.com"
		// \/(sites|teams)\/              => Path must contain either "/sites/" or "/teams/"
		// [^\/]+                         => Site name must contain one or more characters that are not a slash
		// $                              => End of string
		let pattern = #"^https:\/\/[a-zA-Z0-9-]+\.sharepoint\.com\/(sites|teams)\/[^\/]+$"#
		let regex = try NSRegularExpression(pattern: pattern)
		let range = NSRange(urlString.startIndex..., in: urlString)
		guard regex.firstMatch(in: urlString, range: range) != nil, let url = URL(string: urlString) else {
			throw SharePointURLValidatorError.invalidURL
		}
		return url
	}
}

enum SharePointURLValidatorError: LocalizedError {
	case emptyURL
	case invalidURL

	var errorDescription: String? {
		switch self {
		case .emptyURL:
			return LocalizedString.getValue("sharePoint.urlValidator.error.emptyURL")
		case .invalidURL:
			return LocalizedString.getValue("sharePoint.urlValidator.error.invalidURL")
		}
	}
}
