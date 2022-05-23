//
//  NSFileProviderDomainProviderMock.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 10.05.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import FileProvider
import Foundation
import Promises
@testable import CryptomatorFileProvider

// swiftlint:disable all

final class NSFileProviderDomainProviderMock: NSFileProviderDomainProvider {
	// MARK: - getDomains

	var getDomainsThrowableError: Error?
	var getDomainsCallsCount = 0
	var getDomainsCalled: Bool {
		getDomainsCallsCount > 0
	}

	var getDomainsReturnValue: Promise<[NSFileProviderDomain]>!
	var getDomainsClosure: (() -> Promise<[NSFileProviderDomain]>)?

	func getDomains() -> Promise<[NSFileProviderDomain]> {
		if let error = getDomainsThrowableError {
			return Promise(error)
		}
		getDomainsCallsCount += 1
		return getDomainsClosure.map({ $0() }) ?? getDomainsReturnValue
	}
}

// swiftlint:enable all
