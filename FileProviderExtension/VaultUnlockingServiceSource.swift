//
//  VaultUnlockingServiceSource.swift
//  FileProviderExtension
//
//  Created by Philipp Schmid on 02.07.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCommonCore
import CryptomatorFileProvider
import FileProvider
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

	func unlockVault(kek: [UInt8], reply: @escaping (Error?) -> Void) {
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
			guard let domain = self.fileprovider.domain, let notificator = self.fileprovider.notificator else {
				DDLogError("Unlocking vault failed, unable to find FileProviderDomain")
				reply(VaultManagerError.fileProviderDomainNotFound)
				return
			}
			do {
				try FileProviderAdapterManager.shared.unlockVault(with: domain.identifier, kek: kek, dbPath: self.fileprovider.dbPath, delegate: self.fileprovider, notificator: notificator)
				DDLogInfo("Unlocked vault \"\(domain.displayName)\" (\(domain.identifier.rawValue))")
				reply(nil)
			} catch {
				DDLogError("Unlocking vault \"\(domain.displayName)\" (\(domain.identifier.rawValue)) failed with error: \(error)")
				reply(error)
			}
		}
	}

	func startBiometricalUnlock() {
		FileProviderAdapterManager.shared.semaphore.runningBiometricalUnlock = true
	}

	func endBiometricalUnlock() {
		FileProviderAdapterManager.shared.semaphore.signal()
	}
}
