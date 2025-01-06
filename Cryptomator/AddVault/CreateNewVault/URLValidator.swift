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
		guard let url = URL(string: urlString) else {
			throw URLValidatorError.invalidURLFormat
		}

		guard url.scheme == "https",
			  let host = url.host,
			  host.contains(".sharepoint.com") else {
			throw URLValidatorError.invalidURLFormat
		}

		let path = url.path
		guard path.contains("/sites/") else {
			throw URLValidatorError.invalidURLFormat
		}
	}
}
