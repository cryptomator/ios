//
//  ErrorExtensions.swift
//  CryptomatorCommonCore
//
//  Created by Tobias Hagemann on 21.04.26.
//  Copyright © 2026 Skymatic GmbH. All rights reserved.
//

import CryptomatorCloudAccessCore
import FileProvider
import Foundation

public extension Error {
	var isNoInternetConnectionError: Bool {
		if let cloudProviderError = self as? CloudProviderError, cloudProviderError == .noInternetConnection {
			return true
		}
		if let localizedError = self as? LocalizedCloudProviderError, case .noInternetConnection = localizedError {
			return true
		}
		if let fileProviderError = self as? NSFileProviderError, fileProviderError.code == .serverUnreachable {
			return true
		}
		return false
	}

	var isTransientConnectivityError: Bool {
		if isNoInternetConnectionError {
			return true
		}
		let nsError = self as NSError
		guard nsError.domain == NSURLErrorDomain else {
			return false
		}
		return [NSURLErrorTimedOut,
		        NSURLErrorCannotFindHost,
		        NSURLErrorCannotConnectToHost,
		        NSURLErrorNetworkConnectionLost,
		        NSURLErrorDNSLookupFailed,
		        NSURLErrorNotConnectedToInternet].contains(nsError.code)
	}
}
