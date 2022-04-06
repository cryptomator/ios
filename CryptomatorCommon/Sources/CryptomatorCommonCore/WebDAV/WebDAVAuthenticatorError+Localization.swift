//
//  WebDAVAuthenticatorError+Localization.swift
//	CryptomatorCommonCore
//
//  Created by Tobias Hagemann on 31.03.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation

extension WebDAVAuthenticatorError: LocalizedError {
	public var errorDescription: String? {
		switch self {
		case .unsupportedProtocol:
			return LocalizedString.getValue("webDAVAuthenticator.error.unsupportedProtocol")
		case .untrustedCertificate:
			return LocalizedString.getValue("webDAVAuthenticator.error.untrustedCertificate")
		}
	}
}
