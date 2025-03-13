//
//  SharePointURLValidationError+Localization.swift
//  Cryptomator
//
//  Created by Tobias Hagemann on 13.03.25.
//  Copyright © 2025 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import CryptomatorCommonCore
import Foundation

extension SharePointURLValidationError: LocalizedError {
	public var errorDescription: String? {
		switch self {
		case .emptyURL:
			return LocalizedString.getValue("sharePoint.urlValidation.error.emptyURL")
		case .invalidURL:
			return LocalizedString.getValue("sharePoint.urlValidation.error.invalidURL")
		}
	}
}
