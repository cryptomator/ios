//
//  File.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 26.07.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import FileProvider
import Foundation
import Promises

public protocol FileProviderConnector {
	func getProxy<T>(serviceName: NSFileProviderServiceName, domainIdentifier: NSFileProviderDomainIdentifier) -> Promise<T>
	func getProxy<T>(serviceName: NSFileProviderServiceName, domain: NSFileProviderDomain?) -> Promise<T>
}

public enum FileProviderXPCConnectorError: Error {
	case serviceNotSupported
	case connectionIsNil
	case rawProxyCastingFailed
	case typeMismatch
	case domainNotFound
}

public class FileProviderXPCConnector: FileProviderConnector {
	public static let shared = FileProviderXPCConnector()

	public func getProxy<T>(serviceName: NSFileProviderServiceName, domainIdentifier: NSFileProviderDomainIdentifier) -> Promise<T> {
		return NSFileProviderManager.getDomains().then { domains in
			guard let domain = domains.first(where: { $0.identifier == domainIdentifier }) else {
				throw FileProviderXPCConnectorError.domainNotFound
			}
			return self.getProxy(serviceName: serviceName, domain: domain)
		}
	}

	public func getProxy<T>(serviceName: NSFileProviderServiceName, domain: NSFileProviderDomain?) -> Promise<T> {
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
		}.then { connection -> T in
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
			return proxy
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
