//
//  ServiceSource.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 03.05.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import FileProvider
import Foundation

public class ServiceSource: NSObject, NSFileProviderServiceSource, NSXPCListenerDelegate {
	public var serviceName: NSFileProviderServiceName
	private let exportedInterface: NSXPCInterface

	private lazy var listener: NSXPCListener = {
		let listener = NSXPCListener.anonymous()
		listener.delegate = self
		listener.resume()
		return listener
	}()

	init(serviceName: NSFileProviderServiceName, exportedInterface: NSXPCInterface) {
		self.serviceName = serviceName
		self.exportedInterface = exportedInterface
	}

	public func makeListenerEndpoint() throws -> NSXPCListenerEndpoint {
		return listener.endpoint
	}

	// MARK: - NSXPCListenerDelegate

	public func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
		newConnection.exportedInterface = exportedInterface
		newConnection.exportedObject = self
		newConnection.resume()
		weak var weakConnection = newConnection
		newConnection.interruptionHandler = {
			#warning("TODO: investigate if we should set the invalidationHandler for the newConnection")
			weakConnection?.invalidate()
		}
		return true
	}
}
