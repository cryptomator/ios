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
			switch statusCode {
			case 401:
				return String(format: LocalizedString.getValue("urlSession.error.httpError.401"), statusCode)
			case 403:
				return String(format: LocalizedString.getValue("urlSession.error.httpError.403"), statusCode)
			case 404:
				return String(format: LocalizedString.getValue("urlSession.error.httpError.404"), statusCode)
			case 405:
				return String(format: LocalizedString.getValue("urlSession.error.httpError.405"), statusCode)
			case 409:
				return String(format: LocalizedString.getValue("urlSession.error.httpError.409"), statusCode)
			case 412:
				return String(format: LocalizedString.getValue("urlSession.error.httpError.412"), statusCode)
			default:
				return String(format: LocalizedString.getValue("urlSession.error.httpError.default"), statusCode)
			}
		case .unexpectedResponse:
			return LocalizedString.getValue("urlSession.error.unexpectedResponse")
		}
	}
}
