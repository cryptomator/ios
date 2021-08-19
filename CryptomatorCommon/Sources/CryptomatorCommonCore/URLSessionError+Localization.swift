//
//  URLSessionError+Localization.swift
//  CryptomatorCommonCore
//
//  Created by Tobias Hagemann on 19.08.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import Foundation

extension URLSessionError: LocalizedError {
	public var errorDescription: String? {
		switch self {
		case let .httpError(_, statusCode: statusCode):
			return String(format: LocalizedString.getValue("urlSession.error.httpError"), statusCode)
		case .unexpectedResponse:
			return LocalizedString.getValue("urlSession.error.unexpectedResponse")
		}
	}
}
