//
//  VaultLockingServiceSource.swift
//  FileProviderExtension
//
//  Created by Philipp Schmid on 26.07.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CryptomatorCommonCore
import CryptomatorFileProvider
import Foundation
import OSLog
class VaultLockingServiceSource: NSObject, NSFileProviderServiceSource, NSXPCListenerDelegate, VaultLocking {
	var serviceName: NSFileProviderServiceName {
		VaultLockingService.name
	}

	private lazy var listener: NSXPCListener = {
		let listener = NSXPCListener.anonymous()
		listener.delegate = self
		listener.resume()
		return listener
	}()

	func makeListenerEndpoint() throws -> NSXPCListenerEndpoint {
		return listener.endpoint
	}

	// MARK: - NSXPCListenerDelegate

	func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
		newConnection.exportedInterface = NSXPCInterface(with: VaultLocking.self)
		newConnection.exportedObject = self
		newConnection.resume()
		weak var weakConnection = newConnection
		newConnection.interruptionHandler = {
			weakConnection?.invalidate()
		}
		return true
	}

	// MARK: - VaultLocking

	func lockVault(domainIdentifier: NSFileProviderDomainIdentifier) {
		os_log("lockVault called")
		FileProviderAdapterManager.lockVault(with: domainIdentifier)
	}

	func getIsUnlockedVault(domainIdentifier: NSFileProviderDomainIdentifier, reply: @escaping (Bool) -> Void) {
		reply(FileProviderAdapterManager.vaultIsUnLocked(domainIdentifier: domainIdentifier))
	}

	func getUnlockedVaultDomainIdentifiers(reply: @escaping ([NSFileProviderDomainIdentifier]) -> Void) {
		reply(FileProviderAdapterManager.getDomainIdentifiersOfUnlockedVaults())
	}
}
