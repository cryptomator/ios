//
//  FileProviderConnectorMock.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 11.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import FileProvider
import Foundation
import os
@testable import CryptomatorCommonCore

/// @unchecked Sendable: test double, never touched concurrently
final class FileProviderConnectorMock: FileProviderConnector, @unchecked Sendable {
	var proxy: Any?
	var passedServiceName: NSFileProviderServiceName?
	var passedDomainIdentifier: NSFileProviderDomainIdentifier?
	var passedDomainIdentifiers: [NSFileProviderDomainIdentifier] {
		passedDomainIdentifiersLock.withLock { $0 }
	}

	var passedDomain: NSFileProviderDomain?
	var doneHandler: (() -> Void)?
	var xpcInvalidationCallCount = 0
	private let passedDomainIdentifiersLock = OSAllocatedUnfairLock(initialState: [NSFileProviderDomainIdentifier]())

	func getXPC<T>(serviceName: NSFileProviderServiceName, domainIdentifier: NSFileProviderDomainIdentifier) async throws -> XPC<T> {
		passedServiceName = serviceName
		passedDomainIdentifier = domainIdentifier
		passedDomainIdentifiersLock.withLock { $0.append(domainIdentifier) }
		return try getCastedProxy()
	}

	func getXPC<T>(serviceName: NSFileProviderServiceName, domain: NSFileProviderDomain?) async throws -> XPC<T> {
		passedServiceName = serviceName
		passedDomain = domain
		return try getCastedProxy()
	}

	private func getCastedProxy<T>() throws -> XPC<T> {
		guard let castedProxy = proxy as? T else {
			throw FileProviderXPCConnectorError.typeMismatch
		}
		return XPC(proxy: castedProxy, doneHandler: {
			self.doneHandler?()
			self.xpcInvalidationCallCount += 1
		})
	}
}
