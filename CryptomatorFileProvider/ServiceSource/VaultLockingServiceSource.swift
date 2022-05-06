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

public class VaultLockingServiceSource: ServiceSource, VaultLocking {
	public init() {
		super.init(serviceName: .vaultLocking, exportedInterface: NSXPCInterface(with: VaultLocking.self))
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
