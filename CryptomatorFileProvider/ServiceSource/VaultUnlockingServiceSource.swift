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

public class VaultUnlockingServiceSource: ServiceSource, VaultUnlocking {
	private let domain: NSFileProviderDomain
	private let notificator: FileProviderNotificatorType?
	private let dbPath: URL?
	private let localURLProvider: LocalURLProviderType
	private var vaultUID: String {
		return domain.identifier.rawValue
	}

	private let taskRegistrator: SessionTaskRegistrator

	public init(domain: NSFileProviderDomain, notificator: FileProviderNotificatorType?, dbPath: URL?, delegate: LocalURLProviderType, taskRegistrator: SessionTaskRegistrator) {
		self.domain = domain
		self.notificator = notificator
		self.dbPath = dbPath
		self.localURLProvider = delegate
		self.taskRegistrator = taskRegistrator
		super.init(serviceName: .vaultUnlocking, exportedInterface: NSXPCInterface(with: VaultUnlocking.self))
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
				try FileProviderAdapterManager.shared.unlockVault(with: domain.identifier, kek: kek, dbPath: self.dbPath, delegate: self.localURLProvider, notificator: notificator, taskRegistrator: self.taskRegistrator)
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

	public func unlockVault(rawKey: [UInt8], reply: @escaping (NSError?) -> Void) {
		let domain = self.domain
		let vaultUID = vaultUID
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
			guard let notificator = self.notificator else {
				DDLogError("Unlocking vault failed, unable to find FileProviderDomain")
				reply(VaultManagerError.fileProviderDomainNotFound as NSError)
				return
			}
			do {
				try FileProviderAdapterManager.shared.unlockVault(with: domain.identifier, rawKey: rawKey, dbPath: self.dbPath, delegate: self.localURLProvider, notificator: notificator, taskRegistrator: self.taskRegistrator)
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
}
