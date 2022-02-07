//
//  VaultLockingServiceSource.swift
//  FileProviderExtension
//
//  Created by Philipp Schmid on 26.07.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCommonCore
import FileProvider
import Foundation

public class VaultLockingServiceSource: NSObject, NSFileProviderServiceSource, NSXPCListenerDelegate, VaultLocking {
	public var serviceName: NSFileProviderServiceName {
		VaultLockingService.name
	}

	private lazy var listener: NSXPCListener = {
		let listener = NSXPCListener.anonymous()
		listener.delegate = self
		listener.resume()
		return listener
	}()

	public func makeListenerEndpoint() throws -> NSXPCListenerEndpoint {
		return listener.endpoint
	}

	// MARK: - NSXPCListenerDelegate

	public func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
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

	public func lockVault(domainIdentifier: NSFileProviderDomainIdentifier) {
		FileProviderAdapterManager.shared.forceLockVault(with: domainIdentifier)
		DDLogInfo("Locked vault \(domainIdentifier.rawValue)")
	}

	public func gracefulLockVault(domainIdentifier: NSFileProviderDomainIdentifier, reply: @escaping (Error?) -> Void) {
		do {
			try FileProviderAdapterManager.shared.gracefulLockVault(with: domainIdentifier)
			reply(nil)
		} catch {
			reply(error)
		}
	}

	public func getIsUnlockedVault(domainIdentifier: NSFileProviderDomainIdentifier, reply: @escaping (Bool) -> Void) {
		reply(FileProviderAdapterManager.shared.vaultIsUnlocked(domainIdentifier: domainIdentifier))
	}

	public func getUnlockedVaultDomainIdentifiers(reply: @escaping ([NSFileProviderDomainIdentifier]) -> Void) {
		reply(FileProviderAdapterManager.shared.getDomainIdentifiersOfUnlockedVaults())
	}
}
