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

public protocol FileProviderConnector: Sendable {
	func getXPC<T>(serviceName: NSFileProviderServiceName, domain: NSFileProviderDomain?) async throws -> XPC<T>
	func getXPC<T>(serviceName: NSFileProviderServiceName, domainIdentifier: NSFileProviderDomainIdentifier) async throws -> XPC<T>
}

public extension FileProviderConnector {
	func invalidateXPC<T>(_ xpc: XPC<T>) {
		xpc.doneHandler()
	}
}

private enum FileProviderConnectorKey: DependencyKey {
	static var liveValue: FileProviderConnector {
		FileProviderXPCConnector()
	}

	#if DEBUG
	static let testValue: FileProviderConnector = UnimplementedFileProviderConnector()
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
	case rawProxyCastingFailed
	case typeMismatch
	case domainNotFound
}

public final class FileProviderXPCConnector: FileProviderConnector {
	public func getXPC<T>(serviceName: NSFileProviderServiceName, domainIdentifier: NSFileProviderDomainIdentifier) async throws -> XPC<T> {
		let domains = try await NSFileProviderManager.domains()
		guard let domain = domains.first(where: { $0.identifier == domainIdentifier }) else {
			throw FileProviderXPCConnectorError.domainNotFound
		}
		return try await getXPC(serviceName: serviceName, domain: domain)
	}

	public func getXPC<T>(serviceName: NSFileProviderServiceName, domain: NSFileProviderDomain?) async throws -> XPC<T> {
		var url = NSFileProviderManager.default.documentStorageURL
		if let domain = domain {
			url.appendPathComponent(domain.pathRelativeToDocumentStorage)
		}
		let services = try await FileManager.default.fileProviderServicesForItem(at: url)
		guard let desiredService = services[serviceName] else {
			throw FileProviderXPCConnectorError.serviceNotSupported
		}
		let connection = try await desiredService.fileProviderConnection()
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

public extension XPC {
	init(proxy: T) {
		self.init(proxy: proxy, doneHandler: {})
	}
}

#if DEBUG
private struct UnimplementedFileProviderConnector: FileProviderConnector {
	func getXPC<T>(serviceName: NSFileProviderServiceName, domain: NSFileProviderDomain?) async throws -> XPC<T> {
		reportIssue("\(Self.self).getXPC(serviceName:domain:) not implemented")
		throw UnimplementedError()
	}

	func getXPC<T>(serviceName: NSFileProviderServiceName, domainIdentifier: NSFileProviderDomainIdentifier) async throws -> XPC<T> {
		reportIssue("\(Self.self).getXPC(serviceName:domainIdentifier:) not implemented")
		throw UnimplementedError()
	}

	private struct UnimplementedError: Error {}
}
#endif
