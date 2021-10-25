//
//  FileProviderConnectorMock.swift
//  CryptomatorTests
//
//  Created by Philipp Schmid on 11.10.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import FileProvider
import Foundation
import Promises

class FileProviderConnectorMock: FileProviderConnector {
	var proxy: Any?
	var passedServiceName: NSFileProviderServiceName?
	var passedDomainIdentifier: NSFileProviderDomainIdentifier?
	var passedDomain: NSFileProviderDomain?

	func getProxy<T>(serviceName: NSFileProviderServiceName, domainIdentifier: NSFileProviderDomainIdentifier) -> Promise<T> {
		passedServiceName = serviceName
		passedDomainIdentifier = domainIdentifier
		return getCastedProxy()
	}

	func getProxy<T>(serviceName: NSFileProviderServiceName, domain: NSFileProviderDomain?) -> Promise<T> {
		passedServiceName = serviceName
		passedDomain = domain
		return getCastedProxy()
	}

	private func getCastedProxy<T>() -> Promise<T> {
		guard let castedProxy = proxy as? T else {
			return Promise(FileProviderXPCConnectorError.typeMismatch)
		}
		return Promise(castedProxy)
	}
}
