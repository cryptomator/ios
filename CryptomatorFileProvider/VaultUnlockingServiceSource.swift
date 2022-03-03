//
//  VaultUnlockingServiceSource.swift
//  FileProviderExtension
//
//  Created by Philipp Schmid on 02.07.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import CocoaLumberjackSwift
import CryptomatorCommonCore
import FileProvider
import Foundation

public class VaultUnlockingServiceSource: NSObject, NSFileProviderServiceSource, VaultUnlocking, NSXPCListenerDelegate {
	public var serviceName: NSFileProviderServiceName {
		VaultUnlockingService.name
	}

	private let domain: NSFileProviderDomain
	private let notificator: FileProviderNotificatorType?
	private let dbPath: URL?
	private let localURLProvider: LocalURLProviderType
	private lazy var listener: NSXPCListener = {
		let listener = NSXPCListener.anonymous()
		listener.delegate = self
		listener.resume()
		return listener
	}()

	private var vaultUID: String {
		return domain.identifier.rawValue
	}

	public init(domain: NSFileProviderDomain, notificator: FileProviderNotificatorType?, dbPath: URL?, delegate: LocalURLProviderType) {
		self.domain = domain
		self.notificator = notificator
		self.dbPath = dbPath
		self.localURLProvider = delegate
	}

	public func makeListenerEndpoint() throws -> NSXPCListenerEndpoint {
		listener.endpoint
	}

	// MARK: - NSXPCListenerDelegate

	public func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
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

	public func unlockVault(kek: [UInt8], reply: @escaping (NSError?) -> Void) {
		let domain = self.domain
		let vaultUID = vaultUID
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
			guard let notificator = self.notificator else {
				DDLogError("Unlocking vault failed, unable to find FileProviderDomain")
				reply(VaultManagerError.fileProviderDomainNotFound as NSError)
				return
			}
			do {
				try FileProviderAdapterManager.shared.unlockVault(with: domain.identifier, kek: kek, dbPath: self.dbPath, delegate: self.localURLProvider, notificator: notificator)
				FileProviderAdapterManager.shared.unlockMonitor.unlockSucceeded(forVaultUID: vaultUID)
				DDLogInfo("Unlocked vault \"\(domain.displayName)\" (\(domain.identifier.rawValue))")
				reply(nil)
			} catch {
				FileProviderAdapterManager.shared.unlockMonitor.unlockFailed(forVaultUID: vaultUID)
				DDLogError("Unlocking vault \"\(domain.displayName)\" (\(domain.identifier.rawValue)) failed with error: \(error)")
				reply(XPCErrorHelper.bridgeError(error))
			}
		}
	}

	public func startBiometricalUnlock() {
		DDLogInfo("startBiometricalUnlock called for \(vaultUID)")
		FileProviderAdapterManager.shared.unlockMonitor.startBiometricalUnlock(forVaultUID: vaultUID)
	}

	public func endBiometricalUnlock() {
		DDLogInfo("endBiometricalUnlock called for \(vaultUID)")
		FileProviderAdapterManager.shared.unlockMonitor.endBiometricalUnlock(forVaultUID: vaultUID)
	}
}
