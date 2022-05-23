//
//  CachedFileManagerFactoryMock.swift
//  CryptomatorFileProviderTests
//
//  Created by Philipp Schmid on 10.05.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import FileProvider
import Foundation
@testable import CryptomatorFileProvider

final class CachedFileManagerFactoryMock: CachedFileManagerFactory {
	// MARK: - createCachedFileManager

	var createCachedFileManagerForThrowableError: Error?
	var createCachedFileManagerForCallsCount = 0
	var createCachedFileManagerForCalled: Bool {
		createCachedFileManagerForCallsCount > 0
	}

	var createCachedFileManagerForReceivedDomain: NSFileProviderDomain?
	var createCachedFileManagerForReceivedInvocations: [NSFileProviderDomain] = []
	var createCachedFileManagerForReturnValue: CachedFileManager!
	var createCachedFileManagerForClosure: ((NSFileProviderDomain) throws -> CachedFileManager)?

	func createCachedFileManager(for domain: NSFileProviderDomain) throws -> CachedFileManager {
		if let error = createCachedFileManagerForThrowableError {
			throw error
		}
		createCachedFileManagerForCallsCount += 1
		createCachedFileManagerForReceivedDomain = domain
		createCachedFileManagerForReceivedInvocations.append(domain)
		return try createCachedFileManagerForClosure.map({ try $0(domain) }) ?? createCachedFileManagerForReturnValue
	}
}
