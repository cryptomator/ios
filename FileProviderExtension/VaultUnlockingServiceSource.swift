//
//  VaultUnlockingServiceSource.swift
//  FileProviderExtension
//
//  Created by Philipp Schmid on 02.07.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorFileProvider
import Foundation

class VaultUnlockingServiceSource: NSObject, NSFileProviderServiceSource, VaultUnlocking, NSXPCListenerDelegate {
	var serviceName: NSFileProviderServiceName {
		VaultUnlockingService.name
	}

	private let fileprovider: FileProviderExtension
	private lazy var listener: NSXPCListener = {
		let listener = NSXPCListener.anonymous()
		listener.delegate = self
		listener.resume()
		return listener
	}()

	init(fileprovider: FileProviderExtension) {
		self.fileprovider = fileprovider
	}

	func makeListenerEndpoint() throws -> NSXPCListenerEndpoint {
		listener.endpoint
	}

	// MARK: - NSXPCListenerDelegate

	func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
		newConnection.exportedInterface = NSXPCInterface(with: VaultUnlocking.self)
		newConnection.exportedObject = self
		newConnection.resume()
		weak var weakConnection = newConnection
		newConnection.interruptionHandler = {
			weakConnection?.invalidate()
		}
		#warning("TODO: investigate if we should set the invalidationHandler for the newConnection")
		return true
	}

	// MARK: - VaultUnlocking

	func unlockVault(password: String, reply: (Error?) -> Void) {
		do {
			try FileProviderAdapterManager.unlockVault(for: fileprovider.domain, password: password, dbPath: fileprovider.dbPath, delegate: fileprovider, notificator: fileprovider.notificator)
			reply(nil)
		} catch {
			reply(error)
		}
	}
}
