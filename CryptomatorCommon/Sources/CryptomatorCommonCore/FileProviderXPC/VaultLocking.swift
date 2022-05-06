//
//  VaultLocking.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 23.07.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import FileProvider
import Foundation
import Promises

@objc public protocol VaultLocking: NSFileProviderServiceSource {
	func lockVault(domainIdentifier: NSFileProviderDomainIdentifier)
	func gracefulLockVault(domainIdentifier: NSFileProviderDomainIdentifier, reply: @escaping (Error?) -> Void)
	func getIsUnlockedVault(domainIdentifier: NSFileProviderDomainIdentifier, reply: @escaping (Bool) -> Void)
	func getUnlockedVaultDomainIdentifiers(reply: @escaping ([NSFileProviderDomainIdentifier]) -> Void)
}

public extension NSFileProviderServiceName {
	static let vaultLocking = NSFileProviderServiceName("org.cryptomator.ios.vault-locking")
}

// MARK: Convenience

public extension VaultLocking {
	func gracefulLockVault(domainIdentifier: NSFileProviderDomainIdentifier) -> Promise<Void> {
		return wrap { replyHandler in
			self.gracefulLockVault(domainIdentifier: domainIdentifier, reply: replyHandler)
		}.then { maybeError in
			if let error = maybeError {
				return Promise(error)
			} else {
				return Promise(())
			}
		}
	}

	func getIsUnlockedVault(domainIdentifier: NSFileProviderDomainIdentifier) -> Promise<Bool> {
		return wrap { replyHandler in
			self.getIsUnlockedVault(domainIdentifier: domainIdentifier, reply: replyHandler)
		}
	}

	func getUnlockedVaultDomainIdentifiers() -> Promise<[NSFileProviderDomainIdentifier]> {
		return wrap { replyHandler in
			self.getUnlockedVaultDomainIdentifiers(reply: replyHandler)
		}
	}
}
