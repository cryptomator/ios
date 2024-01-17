//
//  FileProviderConnector.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 26.07.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import Dependencies
import FileProvider
import Foundation
import Promises

public protocol FileProviderConnector {
	func getXPC<T>(serviceName: NSFileProviderServiceName, domain: NSFileProviderDomain?) -> Promise<XPC<T>>
	func getXPC<T>(serviceName: NSFileProviderServiceName, domainIdentifier: NSFileProviderDomainIdentifier) -> Promise<XPC<T>>
}

public extension FileProviderConnector {
	func invalidateXPC<T>(_ xpc: XPC<T>) {
		xpc.doneHandler()
	}

	func invalidateXPC<T>(_ xpcPromise: Promise<XPC<T>>) {
		xpcPromise.then(invalidateXPC)
	}

	func getXPC<T>(serviceName: NSFileProviderServiceName, domain: NSFileProviderDomain?) async throws -> XPC<T> {
		try await withCheckedThrowingContinuation({ continuation in
			getXPC(serviceName: serviceName, domain: domain).then {
				continuation.resume(returning: $0)
			}.catch {
				continuation.resume(throwing: $0)
			}
		})
	}

	func getXPC<T>(serviceName: NSFileProviderServiceName, domainIdentifier: NSFileProviderDomainIdentifier) async throws -> XPC<T> {
		try await withCheckedThrowingContinuation({ continuation in
			getXPC(serviceName: serviceName, domainIdentifier: domainIdentifier).then {
				continuation.resume(returning: $0)
			}.catch {
				continuation.resume(throwing: $0)
			}
		})
	}
}

private enum FileProviderConnectorKey: DependencyKey {
	static var liveValue: FileProviderConnector { FileProviderXPCConnector() }
	#if DEBUG
	static var testValue: FileProviderConnector = UnimplementedFileProviderConnector()
	#endif
}

public extension DependencyValues {
	var fileProviderConnector: FileProviderConnector {
		get { self[FileProviderConnectorKey.self] }
		set { self[FileProviderConnectorKey.self] = newValue }
	}
}

public struct XPC<T> {
	public let proxy: T
	let doneHandler: () -> Void
}

public enum FileProviderXPCConnectorError: Error {
	case serviceNotSupported
	case connectionIsNil
	case rawProxyCastingFailed
	case typeMismatch
	case domainNotFound
}

public class FileProviderXPCConnector: FileProviderConnector {
	public func getXPC<T>(serviceName: NSFileProviderServiceName, domainIdentifier: NSFileProviderDomainIdentifier) -> Promise<XPC<T>> {
		return NSFileProviderManager.getDomains().then { domains in
			guard let domain = domains.first(where: { $0.identifier == domainIdentifier }) else {
				throw FileProviderXPCConnectorError.domainNotFound
			}
			return self.getXPC(serviceName: serviceName, domain: domain)
		}
	}

	public func getXPC<T>(serviceName: NSFileProviderServiceName, domain: NSFileProviderDomain?) -> Promise<XPC<T>> {
		var url = NSFileProviderManager.default.documentStorageURL
		if let domain = domain {
			url.appendPathComponent(domain.pathRelativeToDocumentStorage)
		}
		return wrap { handler in
			FileManager.default.getFileProviderServicesForItem(at: url, completionHandler: handler)
		}.then { services -> Promise<NSXPCConnection?> in
			if let desiredService = services?[serviceName] {
				return desiredService.getFileProviderConnection()
			} else {
				return Promise(FileProviderXPCConnectorError.serviceNotSupported)
			}
		}.then { connection -> XPC<T> in
			guard let connection = connection else {
				throw FileProviderXPCConnectorError.connectionIsNil
			}
			guard let type = T.self as AnyObject as? Protocol else {
				throw FileProviderXPCConnectorError.typeMismatch
			}
			connection.remoteObjectInterface = NSXPCInterface(with: type)
			connection.resume()
			let rawProxy = connection.remoteObjectProxyWithErrorHandler { errorAccessingRemoteObject in
				DDLogError("remoteObjectProxy failed with error: \(errorAccessingRemoteObject)")
			}
			guard let proxy = rawProxy as? T else {
				throw FileProviderXPCConnectorError.rawProxyCastingFailed
			}
			return XPC(proxy: proxy, doneHandler: {
				connection.invalidate()
			})
		}
	}
}

extension NSFileProviderService {
	func getFileProviderConnection() -> Promise<NSXPCConnection?> {
		return wrap { handler in
			self.getFileProviderConnection(completionHandler: handler)
		}
	}
}

public extension XPC {
	init(proxy: T) {
		self.init(proxy: proxy, doneHandler: {})
	}
}

#if DEBUG
private struct UnimplementedFileProviderConnector: FileProviderConnector {
	func getXPC<T>(serviceName: NSFileProviderServiceName, domain: NSFileProviderDomain?) -> Promise<XPC<T>> {
		unimplemented("\(Self.self).getXPC(serviceName:domain:) not implemented", placeholder: Promise(UnimplementedError()))
	}

	func getXPC<T>(serviceName: NSFileProviderServiceName, domainIdentifier: NSFileProviderDomainIdentifier) -> Promise<XPC<T>> {
		unimplemented("\(Self.self).getXPC(serviceName:domainIdentifier:) not implemented", placeholder: Promise(UnimplementedError()))
	}

	private struct UnimplementedError: Error {}
}
#endif
