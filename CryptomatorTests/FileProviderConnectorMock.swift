//
//  FileProviderConnectorMock.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 11.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import FileProvider
import Foundation
import Promises
@testable import CryptomatorCommonCore

class FileProviderConnectorMock: FileProviderConnector {
	var proxy: Any?
	var passedServiceName: NSFileProviderServiceName?
	var passedDomainIdentifier: NSFileProviderDomainIdentifier?
	var passedDomain: NSFileProviderDomain?
	var doneHandler: (() -> Void)?
	var xpcInvalidationCallCount = 0

	func getXPC<T>(serviceName: NSFileProviderServiceName, domainIdentifier: NSFileProviderDomainIdentifier) -> Promise<XPC<T>> {
		passedServiceName = serviceName
		passedDomainIdentifier = domainIdentifier
		return getCastedProxy()
	}

	func getXPC<T>(serviceName: NSFileProviderServiceName, domain: NSFileProviderDomain?) -> Promise<XPC<T>> {
		passedServiceName = serviceName
		passedDomain = domain
		return getCastedProxy()
	}

	private func getCastedProxy<T>() -> Promise<XPC<T>> {
		guard let castedProxy = proxy as? T else {
			return Promise(FileProviderXPCConnectorError.typeMismatch)
		}
		return Promise(XPC(proxy: castedProxy, doneHandler: {
			self.doneHandler?()
			self.xpcInvalidationCallCount += 1
		}))
	}
}
