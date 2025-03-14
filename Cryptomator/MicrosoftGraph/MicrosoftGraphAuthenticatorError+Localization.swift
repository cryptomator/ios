//
//  MicrosoftGraphAuthenticatorError+Localization.swift
//  CryptomatorCommon
//
//  Created by Tobias Hagemann on 11.03.25.
//  Copyright © 2025 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccess
import CryptomatorCommonCore
import Foundation

extension MicrosoftGraphAuthenticatorError: LocalizedError {
	public var errorDescription: String? {
		switch self {
		case .missingAccountIdentifier:
			return nil
		case .serverDeclinedScopes:
			return LocalizedString.getValue("microsoftGraphAuthenticator.error.serverDeclinedScopes")
		}
	}
}
