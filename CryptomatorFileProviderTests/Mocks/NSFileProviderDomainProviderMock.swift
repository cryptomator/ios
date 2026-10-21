//
//  NSFileProviderDomainProviderMock.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 10.05.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import FileProvider
import Foundation
@testable import CryptomatorFileProvider

// swiftlint:disable all

final class NSFileProviderDomainProviderMock: NSFileProviderDomainProvider {
	// MARK: - getDomains

	var getDomainsThrowableError: Error?
	var getDomainsCallsCount = 0
	var getDomainsCalled: Bool {
		getDomainsCallsCount > 0
	}

	var getDomainsReturnValue: [NSFileProviderDomain]!
	var getDomainsClosure: (() async throws -> [NSFileProviderDomain])?

	func getDomains() async throws -> [NSFileProviderDomain] {
		if let error = getDomainsThrowableError {
			throw error
		}
		getDomainsCallsCount += 1
		if let getDomainsClosure {
			return try await getDomainsClosure()
		}
		return getDomainsReturnValue
	}
}

// swiftlint:enable all
