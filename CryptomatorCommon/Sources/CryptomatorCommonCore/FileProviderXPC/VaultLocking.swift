//
//  VaultLocking.swift
//  CryptomatorCommonCore
//
//  Created by Philipp Schmid on 23.07.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import FileProvider
import Foundation

@objc public protocol VaultLocking: NSFileProviderServiceSource {
	func lockVault(domainIdentifier: NSFileProviderDomainIdentifier)
	func gracefulLockVault(domainIdentifier: NSFileProviderDomainIdentifier, reply: @escaping (Error?) -> Void)
	func getIsUnlockedVault(domainIdentifier: NSFileProviderDomainIdentifier, reply: @escaping (Bool) -> Void)
}

public extension NSFileProviderServiceName {
	static let vaultLocking = NSFileProviderServiceName("org.cryptomator.ios.vault-locking")
}

// MARK: Convenience

public extension VaultLocking {
	func gracefulLockVault(domainIdentifier: NSFileProviderDomainIdentifier) async throws {
		try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
			self.gracefulLockVault(domainIdentifier: domainIdentifier, reply: { error in
				if let error = error {
					continuation.resume(throwing: error)
				} else {
					continuation.resume()
				}
			})
		}
	}

	func getIsUnlockedVault(domainIdentifier: NSFileProviderDomainIdentifier) async -> Bool {
		await withCheckedContinuation { continuation in
			self.getIsUnlockedVault(domainIdentifier: domainIdentifier, reply: { isUnlocked in
				continuation.resume(returning: isUnlocked)
			})
		}
	}
}
