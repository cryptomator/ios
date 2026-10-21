//
//  FileProviderConnectorMock.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 26.10.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

#if DEBUG
import FileProvider
import Foundation

// swiftlint:disable all

/// @unchecked Sendable: test double, never touched concurrently
final class FileProviderConnectorMock: FileProviderConnector, @unchecked Sendable {
	// MARK: - getXPC<T>

	var getXPCServiceNameDomainCallsCount = 0
	var getXPCServiceNameDomainCalled: Bool {
		getXPCServiceNameDomainCallsCount > 0
	}

	var getXPCServiceNameDomainReceivedArguments: (serviceName: NSFileProviderServiceName, domain: NSFileProviderDomain?)?
	var getXPCServiceNameDomainReceivedInvocations: [(serviceName: NSFileProviderServiceName, domain: NSFileProviderDomain?)] = []
	var getXPCServiceNameDomainReturnValue: Any!
	var getXPCServiceNameDomainClosure: ((NSFileProviderServiceName, NSFileProviderDomain?) -> Any)?
	var getXPCServiceNameDomainXPCDoneHandlerCalledFor: [Any] = []

	func getXPC<T>(serviceName: NSFileProviderServiceName, domain: NSFileProviderDomain?) async throws -> XPC<T> {
		getXPCServiceNameDomainCallsCount += 1
		getXPCServiceNameDomainReceivedArguments = (serviceName: serviceName, domain: domain)
		getXPCServiceNameDomainReceivedInvocations.append((serviceName: serviceName, domain: domain))
		let xpc = getXPCServiceNameDomainClosure.map({ returnValue in
			let proxy = returnValue(serviceName, domain) as! T
			return XPC(proxy: proxy, doneHandler: { self.getXPCServiceNameDomainXPCDoneHandlerCalledFor.append(proxy) })

		})
		return xpc ?? getXPCServiceNameDomainReturnValue as! XPC<T>
	}

	// MARK: - getXPC<T>

	var getXPCServiceNameDomainIdentifierCallsCount = 0
	var getXPCServiceNameDomainIdentifierCalled: Bool {
		getXPCServiceNameDomainIdentifierCallsCount > 0
	}

	var getXPCServiceNameDomainIdentifierReceivedArguments: (serviceName: NSFileProviderServiceName, domainIdentifier: NSFileProviderDomainIdentifier)?
	var getXPCServiceNameDomainIdentifierReceivedInvocations: [(serviceName: NSFileProviderServiceName, domainIdentifier: NSFileProviderDomainIdentifier)] = []
	var getXPCServiceNameDomainIdentifierReturnValue: Any!
	var getXPCServiceNameDomainIdentifierClosure: ((NSFileProviderServiceName, NSFileProviderDomainIdentifier) -> Any)?
	var getXPCServiceNameDomainIdentifierXPCDoneHandlerCalledFor: [Any] = []

	func getXPC<T>(serviceName: NSFileProviderServiceName, domainIdentifier: NSFileProviderDomainIdentifier) async throws -> XPC<T> {
		getXPCServiceNameDomainIdentifierCallsCount += 1
		getXPCServiceNameDomainIdentifierReceivedArguments = (serviceName: serviceName, domainIdentifier: domainIdentifier)
		getXPCServiceNameDomainIdentifierReceivedInvocations.append((serviceName: serviceName, domainIdentifier: domainIdentifier))
		let xpc = getXPCServiceNameDomainIdentifierClosure.map({ returnValue in
			let proxy = returnValue(serviceName, domainIdentifier) as! T
			return XPC(proxy: proxy, doneHandler: { self.getXPCServiceNameDomainIdentifierXPCDoneHandlerCalledFor.append(proxy) })

		})
		return xpc ?? getXPCServiceNameDomainIdentifierReturnValue as! XPC<T>
	}
}

// swiftlint:enable all

#endif
